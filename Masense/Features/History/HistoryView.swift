import SwiftData
import SwiftUI

/// S4 기록. 세그먼트: 투약 / 컨디션 / 체중. 습관은 M2.
struct HistoryView: View {
    private enum Segment: String, CaseIterable, Hashable {
        case dose, condition, weight

        var titleKey: LocalizedStringKey { LocalizedStringKey("history.segment." + rawValue) }
    }

    private enum Sheet: Identifiable {
        case dose(initialDate: Date)
        case condition(doseID: UUID, window: ConditionWindow)
        case weight

        var id: String {
            switch self {
            case let .dose(date): return "dose.\(date.timeIntervalSinceReferenceDate)"
            case let .condition(doseID, window): return "condition.\(doseID.uuidString).\(window.rawValue)"
            case .weight: return "weight"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @Environment(\.calendar) private var calendar
    @Query(sort: \Prescription.startDate) private var prescriptions: [Prescription]
    @Query(sort: \ConditionCheck.checkedAt) private var checks: [ConditionCheck]
    @Query(sort: \WeightSample.measuredAt, order: .reverse) private var weights: [WeightSample]
    @State private var segment: Segment = .dose
    @State private var sheet: Sheet?
    @State private var showsToast = false

    private var activePrescription: Prescription? { prescriptions.first { $0.isActive } }
    private var allDoses: [Dose] { prescriptions.flatMap(\.doses) }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            List {
                Picker("history.segment", selection: $segment) {
                    ForEach(Segment.allCases, id: \.self) { item in
                        Text(item.titleKey).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                switch segment {
                case .dose: doseSections(now: timeline.date)
                case .condition: conditionSections(now: timeline.date)
                case .weight: weightSections(now: timeline.date)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .midnightBackground()
        .navigationTitle("tab.history")
        .toolbar {
            if segment == .weight {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .weight } label: { Image(systemName: "plus") }
                        .accessibilityLabel("weight.entry.title")
                }
            }
        }
        .sheet(item: $sheet) { sheet in sheetContent(sheet) }
        .recordedToast(isPresented: $showsToast)
    }

    // MARK: 투약

    @ViewBuilder
    private func doseSections(now: Date) -> some View {
        let histories = prescriptions.map {
            HistoryModel.PrescriptionHistory(prescription: $0.snapshot, doses: $0.doseSnapshots, isActive: $0.isActive)
        }
        let months = HistoryModel.doseMonths(histories, now: now, calendar: calendar)
        if months.isEmpty {
            emptyRow("history.empty")
        }
        ForEach(months) { month in
            Section {
                ForEach(month.rows) { row in
                    doseRow(row)
                }
            } header: {
                Text(month.start.formatted(.dateTime.year().month(.wide)))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private func doseRow(_ row: HistoryModel.DoseRow) -> some View {
        switch row.kind {
        case let .dose(id, site, sequence, hasNote, isCancelled):
            AdaptiveStack(spacing: Spacing.s3) {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(row.date.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated).hour().minute()))
                        .font(Typography.body)
                        .strikethrough(isCancelled)
                    Text(site.localizedName)
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                if hasNote {
                    Image(systemName: "note.text")
                        .foregroundStyle(Color.inkSecondary)
                        .accessibilityLabel("history.hasNote")
                }
                VStack(alignment: .trailing, spacing: Spacing.s1) {
                    Text("history.sequence \(sequence)")
                        .font(Typography.mono)
                    if isCancelled {
                        Text("history.cancelled")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .foregroundStyle(isCancelled ? Color.inkTertiary : Color.ink)
            .listRowBackground(Color.frost)
            .swipeActions(edge: .trailing) {
                // 빨강 금지: destructive 역할 대신 중립색
                Button(LocalizedStringKey(isCancelled ? "history.restoreDose" : "history.cancelDose")) {
                    setCancelled(!isCancelled, doseID: id)
                }
                .tint(isCancelled ? Color.accent : Color.inkTertiary)
            }

        case let .missed(scheduled, canAddDose):
            Button {
                if canAddDose { sheet = .dose(initialDate: scheduled) }
            } label: {
                HStack {
                    Text(scheduled.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))
                    Spacer()
                    Text("history.missed")
                    if canAddDose {
                        Image(systemName: "plus.circle")
                            .accessibilityHidden(true)
                    }
                }
                .font(Typography.body)
                .foregroundStyle(Color.inkTertiary)
            }
            .disabled(!canAddDose)
            .listRowBackground(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(Color.inkTertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .accessibilityHint(canAddDose ? Text("history.missed.hint") : Text(verbatim: ""))
        }
    }

    private func setCancelled(_ cancelled: Bool, doseID: UUID) {
        guard let dose = allDoses.first(where: { $0.id == doseID }) else { return }
        dose.isCancelled = cancelled
        try? context.save()
        Task { await services.refreshNotifications(context: context) }
    }

    // MARK: 컨디션

    @ViewBuilder
    private func conditionSections(now: Date) -> some View {
        let groups = HistoryModel.conditionGroups(
            doses: allDoses.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            now: now
        )
        if groups.isEmpty {
            emptyRow("history.empty")
        }
        ForEach(groups) { group in
            Section {
                ForEach(group.slots, id: \.window) { slot in
                    conditionRow(slot, doseID: group.doseID)
                }
            } header: {
                Text("history.condition.doseHeader \(group.administeredAt.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))")
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private func conditionRow(_ slot: HistoryModel.ConditionSlot, doseID: UUID) -> some View {
        AdaptiveStack(verticalAlignment: .firstTextBaseline) {
            Text(LocalizedStringKey(slot.window.titleKey))
                .font(Typography.body)
                .foregroundStyle(Color.ink)
            Spacer()
            switch slot.state {
            case let .recorded(count, maxSeverity, appetite):
                VStack(alignment: .trailing, spacing: Spacing.s1) {
                    if count == 0 {
                        Text("history.condition.noSymptoms")
                    } else {
                        Text("history.condition.summary \(count) \(SymptomChip.severityLabel(maxSeverity))")
                            .fontWeight(maxSeverity >= 3 ? .bold : .regular)
                    }
                    if appetite != .normal {
                        Text("history.condition.appetite \(L10n.string(appetite.titleKey))")
                    }
                }
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            case .missing:
                Button("action.record") {
                    sheet = .condition(doseID: doseID, window: slot.window)
                }
                .font(Typography.label)
                .foregroundStyle(Color.accent)
            }
        }
        .listRowBackground(Color.frost)
    }

    // MARK: 체중

    @ViewBuilder
    private func weightSections(now: Date) -> some View {
        let series = WeightRules.weeklyWeightSeries(samples: weights.map(\.snapshot), weeks: 12, now: now, calendar: calendar)
        if weights.isEmpty {
            emptyRow("weight.empty")
        } else {
            Section {
                WeekChart(points: series)
                    .frame(height: 180)
                    .padding(.vertical, Spacing.s3)
            }
            .listRowBackground(Color.frost)

            Section {
                ForEach(weights) { sample in
                    AdaptiveStack {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text(sample.measuredAt.formatted(.dateTime.month(.defaultDigits).day().hour().minute()))
                                .font(Typography.body)
                            Text(LocalizedStringKey(sample.source == .healthKit ? "history.weight.sourceHealth" : "history.weight.sourceManual"))
                                .font(Typography.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Spacer()
                        Text("weight.kg \(sample.kilograms.formatted(.number.precision(.fractionLength(1))))")
                            .font(Typography.mono)
                    }
                    .foregroundStyle(Color.ink)
                    .listRowBackground(Color.frost)
                    .swipeActions(edge: .trailing) {
                        // HealthKit 샘플은 Apple Health에서 관리한다. 다음 동기화에 다시 들어오므로 수동 입력만 지운다
                        if sample.source == .manual {
                            Button("history.weight.delete") {
                                context.delete(sample)
                                try? context.save()
                            }
                            .tint(Color.inkTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: 공용

    private func emptyRow(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typography.body)
            .foregroundStyle(Color.inkSecondary)
            .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case let .dose(initialDate):
            if let activePrescription {
                DoseLogSheet(prescription: activePrescription, initialDate: initialDate) { showsToast = true }
            }
        case let .condition(doseID, window):
            if let dose = allDoses.first(where: { $0.id == doseID }) {
                ConditionCheckSheet(dose: dose, window: window) { showsToast = true }
            }
        case .weight:
            WeightEntrySheet { showsToast = true }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(ModelContainer.preview)
    .preferredColorScheme(.dark)
}
