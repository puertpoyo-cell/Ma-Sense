import SwiftData
import SwiftUI

/// S4 기록. 세그먼트: 투약 / 컨디션 / 체중 / 습관(M2).
struct HistoryView: View {
    private enum Segment: String, CaseIterable, Hashable {
        case dose, condition, weight, habits

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
    @Query(sort: \ProteinEntry.date) private var proteins: [ProteinEntry]
    @Query(sort: \StrengthSession.startedAt) private var sessions: [StrengthSession]
    @Query private var settingsList: [UserSettings]
    @State private var segment: Segment = HistoryView.initialSegment
    /// 습관 캘린더에 보이는 달. nil이면 이번 달
    @State private var habitMonth: Date?
    @State private var sheet: Sheet?
    @State private var showsToast = false

    private var activePrescription: Prescription? { prescriptions.first { $0.isActive } }
    private var allDoses: [Dose] { prescriptions.flatMap(\.doses) }

    private static var initialSegment: Segment {
        #if DEBUG
        switch ScreenshotRoute.current {
        case .historyCondition?: return .condition
        case .historyWeight?: return .weight
        case .historyHabits?: return .habits
        default: break
        }
        #endif
        return .dose
    }

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
                case .habits: habitSections(now: timeline.date)
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
                SectionHeaderText(Text(month.start.formatted(.dateTime.year().month(.wide))))
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
            .frostRow()
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

        case let .prescriptionChange(label):
            // 처방 전환 구분 행 (R13). 라벨은 사용자 메모 그대로 표시만 한다
            HStack(spacing: Spacing.s2) {
                Rectangle().fill(Color.gridHairline).frame(height: 1)
                Group {
                    if let label {
                        Text("history.prescriptionChange \(label)")
                    } else {
                        Text("history.prescriptionChange.noLabel")
                    }
                }
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
                .layoutPriority(1)
                Rectangle().fill(Color.gridHairline).frame(height: 1)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityElement(children: .combine)
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
                SectionHeaderText(Text("history.condition.doseHeader \(group.administeredAt.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))"))
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
        .frostRow()
    }

    // MARK: 체중

    @ViewBuilder
    private func weightSections(now: Date) -> some View {
        let series = WeightRules.weeklyWeightSeries(samples: weights.map(\.snapshot), weeks: Self.weightWeeks, now: now, calendar: calendar)
        if weights.isEmpty {
            emptyRow("weight.empty")
        } else {
            Section {
                WeekChart(points: series, tickDates: WeightRules.doseTicks(doses: allDoses.map(\.snapshot), series: series, now: now))
                    .frame(height: 180)
                    .padding(.vertical, Spacing.s3)
            } header: {
                SectionHeaderText(Text("history.weight.chartTitle \(Self.weightWeeks)"))
            }
            .frostRow()

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
                        DimensionValue(
                            sample.kilograms.formatted(.number.precision(.fractionLength(1))),
                            unit: "unit.kg",
                            valueFont: Typography.body.weight(.semibold),
                            unitFont: Typography.caption
                        )
                    }
                    .foregroundStyle(Color.ink)
                    .frostRow()
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

    // MARK: 습관 (M2)

    @ViewBuilder
    private func habitSections(now: Date) -> some View {
        let anchor = habitMonth ?? now
        let target = settingsList.first?.proteinTargetGrams
        let cells = HistoryModel.habitMonth(
            containing: anchor,
            proteins: proteins.map(\.snapshot),
            sessions: sessions.map(\.snapshot),
            proteinTarget: target,
            calendar: calendar
        )
        let isCurrentMonth = calendar.isDate(anchor, equalTo: now, toGranularity: .month)
        Section {
            HStack {
                Button { shiftMonth(-1, from: anchor) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("history.habits.prevMonth")
                Spacer()
                Text(anchor.formatted(.dateTime.year().month(.wide)))
                    .font(Typography.label)
                Spacer()
                Button { shiftMonth(1, from: anchor) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("history.habits.nextMonth")
                    .disabled(isCurrentMonth)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ink)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            VStack(spacing: 0) {
                LazyVGrid(columns: Self.weekColumns, spacing: 0) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(verbatim: symbol)
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.bottom, Spacing.s2)
                    }
                }
                BlueprintDivider(crosshair: .none)
                // 7칸 도면 격자: 칸 사이 선과 교차점 마커 (DESIGN_SYSTEM.md 1)
                LazyVGrid(columns: Self.weekColumns, spacing: 0) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        if let cell {
                            habitDayCell(cell)
                        } else {
                            Color.clear.frame(height: Self.dayCellHeight)
                        }
                    }
                }
                .overlay {
                    BlueprintGridLines(rows: (cells.count + 6) / 7, columns: 7)
                }
            }
            // 7칸 격자는 접근성 최대 글자에서 숫자가 두 줄로 쪼개진다. 이 격자만 상한을 두고, 날짜는 VoiceOver 레이블로 읽는다
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            HStack(spacing: Spacing.s4) {
                Label {
                    Text("history.habits.legend.protein")
                } icon: {
                    Circle().fill(Color.accent).frame(width: 7, height: 7)
                }
                Label {
                    Text("history.habits.legend.strength")
                } icon: {
                    Rectangle().stroke(Color.ink, lineWidth: 1).frame(width: 7, height: 7)
                }
            }
            .font(Typography.caption)
            .foregroundStyle(Color.inkSecondary)
            .lineLimit(1)
            // 격자와 같은 상한. 그 이상에서는 "단백질"이 두 줄로 쪼개진다
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            if target == nil {
                Text("history.habits.noTargetNote")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frostRow()
    }

    private static let weightWeeks = 12
    private static let weekColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private static let dayCellHeight: CGFloat = 44

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private func shiftMonth(_ months: Int, from anchor: Date) {
        habitMonth = calendar.date(byAdding: .month, value: months, to: anchor)
    }

    /// 모양으로 구분: 단백질은 채운 원, 근력운동은 빈 사각형 (색만으로 구분하지 않는다)
    private func habitDayCell(_ day: HistoryModel.HabitDay) -> some View {
        VStack(spacing: 3) {
            Text(verbatim: String(calendar.component(.day, from: day.date)))
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 3) {
                if day.proteinMarked {
                    Circle().fill(Color.accent).frame(width: 6, height: 6)
                }
                if day.strengthDone {
                    Rectangle().stroke(Color.ink, lineWidth: 1).frame(width: 6, height: 6)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity, minHeight: Self.dayCellHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(habitDayLabel(day))
    }

    private func habitDayLabel(_ day: HistoryModel.HabitDay) -> Text {
        var parts = [day.date.formatted(.dateTime.month(.wide).day())]
        if day.proteinMarked { parts.append(L10n.string("history.habits.legend.protein")) }
        if day.strengthDone { parts.append(L10n.string("history.habits.legend.strength")) }
        return Text(verbatim: parts.joined(separator: ", "))
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
    .modelContainer(ModelContainer.previewWithSampleData)
    .preferredColorScheme(.dark)
}
