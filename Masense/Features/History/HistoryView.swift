import SwiftData
import SwiftUI

/// S4 기록 탭 (D20, 날짜 중심). 위 주 달력에서 날을 고르면 그날의 투약·진료·컨디션·체중·단백질·운동·습관이 한 카드에 모인다.
/// 아래 "모아 보기"에서 종류별 목록·정리·증상 흐름·체중 추이·펜 현황으로 간다.
/// 날마다 무엇을 기록했는지만 표시하고 많고 적음을 판단하지 않는다 (COMPLIANCE.md 2.1-4)
struct HistoryView: View {
    private enum Destination: Hashable {
        case list, summaries, symptomFlow, pens
    }

    private enum Sheet: Identifiable {
        case dose(Date)
        case weightTrend
        /// N-E2 부위 고치기
        case site(Dose)
        /// N-E3 그날 메모
        case memo(Date)

        var id: String {
            switch self {
            case let .dose(date): return "dose.\(date.timeIntervalSinceReferenceDate)"
            case .weightTrend: return "weightTrend"
            case let .site(dose): return "site.\(dose.id.uuidString)"
            case let .memo(date): return "memo.\(date.timeIntervalSinceReferenceDate)"
            }
        }
    }

    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var context
    @Query(sort: \Prescription.startDate) private var prescriptions: [Prescription]
    @Query(sort: \ConditionCheck.checkedAt) private var checks: [ConditionCheck]
    @Query(sort: \WeightSample.measuredAt) private var weights: [WeightSample]
    @Query(sort: \ProteinEntry.date) private var proteins: [ProteinEntry]
    @Query(sort: \StrengthSession.startedAt) private var sessions: [StrengthSession]
    @Query(sort: \HabitCheck.date) private var habits: [HabitCheck]
    @Query(sort: \ClinicVisit.visitedAt) private var visits: [ClinicVisit]
    /// 고른 날 (00:00). nil이면 오늘
    @State private var selectedDay: Date?
    @State private var path: [Destination] = HistoryView.initialPath
    @State private var sheet: Sheet?
    @State private var showsToast = false
    /// N-E1 월 보기
    @State private var showsMonth = false
    /// N-E4 범례는 처음에만 펼쳐 두고, 날을 고르면 접는다. (i)로 다시 볼 수 있다
    @AppStorage("history.legendShown") private var legendShown = true

    private var activePrescription: Prescription? { prescriptions.first { $0.isActive } }
    private var allDoses: [Dose] { prescriptions.flatMap(\.doses) }

    /// DEBUG 스크린샷 `history.*`는 종류별 보기로 바로 간다 (예전 기록 탭 화면)
    private static var initialPath: [Destination] {
        #if DEBUG
        switch ScreenshotRoute.current {
        case .historyDose?, .historyCondition?, .historyWeight?, .historyHabits?: return [.list]
        default: break
        }
        #endif
        return []
    }

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { timeline in
                let today = calendar.startOfDay(for: timeline.date)
                let day = selectedDay ?? today
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.cardGap) {
                        weekStrip(day: day, today: today)
                        dayCard(day: day, today: today)
                        collections
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.s4)
                    .padding(.bottom, Spacing.s6)
                }
            }
            .midnightBackground()
            .navigationTitle("tab.history")
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .list: HistoryListView()
                case .summaries: WeeklySummaryListView()
                case .symptomFlow: SymptomFlowView()
                case .pens: PenStatusPage()
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case let .dose(date):
                    if let activePrescription {
                        DoseLogSheet(prescription: activePrescription, initialDate: date) { showsToast = true }
                    }
                case .weightTrend:
                    WeightTrendSheet()
                case let .site(dose):
                    SiteEditSheet(dose: dose) { showsToast = true }
                case let .memo(date):
                    DayMemoSheet(day: date) { showsToast = true }
                }
            }
            .recordedToast(isPresented: $showsToast)
        }
    }

    // MARK: 주 달력

    private func weekStrip(day: Date, today: Date) -> some View {
        let week = HistoryDayRules.week(containing: day, calendar: calendar)
        let isThisWeek = week.contains(today)
        return FrostCard {
            VStack(spacing: Spacing.s3) {
                HStack {
                    Button {
                        selectedDay = showsMonth
                            ? HistoryDayRules.shiftMonth(day, by: -1, calendar: calendar)
                            : HistoryDayRules.shiftWeek(day, by: -1, calendar: calendar)
                    } label: {
                        Image(systemName: "chevron.left").frame(minWidth: 36, minHeight: 32)
                    }
                    .accessibilityLabel(Text(showsMonth ? "history.month.previous" : "history.week.previous"))
                    Spacer()
                    // N-E1: 기간을 누르면 월 보기로
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showsMonth.toggle() }
                    } label: {
                        HStack(spacing: Spacing.s1) {
                            if showsMonth {
                                Text(day.formatted(.dateTime.year().month(.wide)))
                            } else if let first = week.first, let last = week.last {
                                Text(verbatim: first.formatted(.dateTime.month(.defaultDigits).day()) + " – " + last.formatted(.dateTime.month(.defaultDigits).day()))
                            }
                            Image(systemName: showsMonth ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(Typography.label)
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                    }
                    .accessibilityLabel(Text(showsMonth ? "history.month.close" : "history.month.open"))
                    Spacer()
                    Button {
                        let next = showsMonth
                            ? HistoryDayRules.shiftMonth(day, by: 1, calendar: calendar)
                            : HistoryDayRules.shiftWeek(day, by: 1, calendar: calendar)
                        selectedDay = min(next, today)
                    } label: {
                        Image(systemName: "chevron.right").frame(minWidth: 36, minHeight: 32)
                    }
                    .disabled(showsMonth ? calendar.isDate(day, equalTo: today, toGranularity: .month) : isThisWeek)
                    .accessibilityLabel(Text(showsMonth ? "history.month.next" : "history.week.next"))
                }
                .foregroundStyle(Color.accent)

                if showsMonth {
                    monthGrid(day: day, today: today)
                } else {
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { date in
                            dayButton(date, isSelected: calendar.isDate(date, inSameDayAs: day), isToday: date == today, isFuture: date > today)
                        }
                    }
                }

                HStack(alignment: .top) {
                    if legendShown { legend }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { legendShown.toggle() }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Color.inkTertiary)
                            .frame(minWidth: 28, minHeight: 20)
                    }
                    .accessibilityLabel(Text("history.legend.toggle"))
                }
            }
        }
    }

    /// N-E1 한 달 달력. 투약일만 ● (많고 적음 없음). 날을 누르면 고르고 주 보기로 돌아간다
    private func monthGrid(day: Date, today: Date) -> some View {
        let rows = HistoryDayRules.monthGrid(containing: day, calendar: calendar)
        let doseDays = Set(allDoses.filter { !$0.isCancelled }.map { calendar.startOfDay(for: $0.administeredAt) })
        return VStack(spacing: Spacing.s1) {
            HStack(spacing: 0) {
                ForEach(HistoryDayRules.week(containing: day, calendar: calendar), id: \.self) { date in
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(Color.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, date in
                        if let date {
                            monthCell(date, isSelected: calendar.isDate(date, inSameDayAs: day), isToday: date == today, isFuture: date > today, hasDose: doseDays.contains(date))
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 36)
                        }
                    }
                }
            }
        }
    }

    private func monthCell(_ date: Date, isSelected: Bool, isToday: Bool, isFuture: Bool, hasDose: Bool) -> some View {
        Button {
            selectedDay = date
            legendShown = false
            withAnimation(.easeOut(duration: 0.2)) { showsMonth = false }
        } label: {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.day()))
                    .font(Typography.caption.weight(isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isFuture ? Color.inkTertiary : Color.ink)
                    .frame(width: 28, height: 28)
                    .background(isSelected ? Color.accentSoft : Color.clear, in: Circle())
                    .overlay(Circle().strokeBorder(isToday ? Color.accent : Color.clear, lineWidth: 1))
                Circle()
                    .fill(hasDose ? Color.accent : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Text(date.formatted(.dateTime.month().day().weekday())))
        .accessibilityValue(hasDose ? Text("history.mark.dose") : Text(verbatim: ""))
    }

    private func dayButton(_ date: Date, isSelected: Bool, isToday: Bool, isFuture: Bool) -> some View {
        let marks = isFuture ? DayMarks() : marks(on: date)
        return Button {
            selectedDay = date
            legendShown = false
        } label: {
            VStack(spacing: Spacing.s1) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                Text(date.formatted(.dateTime.day()))
                    .font(Typography.label.weight(isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(isFuture ? Color.inkTertiary : Color.ink)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.accentSoft : Color.clear, in: Circle())
                    .overlay(Circle().strokeBorder(isToday ? Color.accent : Color.clear, lineWidth: 1))
                MarkDots(marks: marks)
                    .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Text(date.formatted(.dateTime.month().day().weekday())))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 점 모양 범례. 색은 종류 구분일 뿐, 모양으로도 구분한다
    private var legend: some View {
        HStack(spacing: Spacing.s3) {
            ForEach(MarkKind.allCases, id: \.self) { kind in
                HStack(spacing: 3) {
                    kind.shape.frame(width: 6, height: 6)
                    Text(LocalizedStringKey("history.mark." + kind.rawValue))
                        .font(.caption2)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func marks(on day: Date) -> DayMarks {
        HistoryDayRules.marks(
            on: day,
            doses: allDoses.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            weights: weights.map(\.snapshot),
            proteins: proteins.map(\.snapshot),
            sessions: sessions.map(\.snapshot),
            visits: visits.map(\.visitedAt),
            calendar: calendar
        )
    }

    // MARK: 하루 카드

    /// 고른 날의 기록 묶음
    private struct DayEntries {
        var doses: [Dose] = []
        var visits: [ClinicVisit] = []
        var checks: [ConditionCheck] = []
        var weights: [WeightSample] = []
        var proteins: [ProteinEntry] = []
        var sessions: [StrengthSession] = []
        var habitKeys: [String] = []

        var isEmpty: Bool {
            doses.isEmpty && visits.isEmpty && checks.isEmpty && weights.isEmpty
                && proteins.isEmpty && sessions.isEmpty && habitKeys.isEmpty
        }
    }

    private func entries(on day: Date) -> DayEntries {
        let same = { (date: Date) in calendar.isDate(date, inSameDayAs: day) }
        var entries = DayEntries()
        entries.doses = allDoses.filter { !$0.isCancelled && same($0.administeredAt) }.sorted { $0.administeredAt < $1.administeredAt }
        entries.visits = visits.filter { same($0.visitedAt) }
        entries.checks = checks.filter { same($0.checkedAt) }
        entries.weights = weights.filter { same($0.measuredAt) }
        entries.proteins = proteins.filter { same($0.date) }
        entries.sessions = sessions.filter { same($0.startedAt) }
        if let habit = habits.first(where: { same($0.date) }) {
            if habit.water { entries.habitKeys.append("habit.water") }
            if habit.fiber { entries.habitKeys.append("habit.fiber") }
            if habit.sleep { entries.habitKeys.append("habit.sleep") }
        }
        return entries
    }

    private func dayCard(day: Date, today: Date) -> some View {
        let entries = entries(on: day)
        return FrostCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(day.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                    .padding(Spacing.cellPadding)
                if entries.isEmpty {
                    BlueprintDivider()
                    Text("history.day.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(Spacing.cellPadding)
                }
                doseAndVisitRows(entries)
                bodyRows(entries)
                habitRows(entries)
                memoRow(day: day)
                addDoseRow(day: day, today: today, hasDose: !entries.doses.isEmpty)
            }
        }
    }

    /// N-E3 그날 메모. 있으면 보여 주고, 누르면 고친다
    @ViewBuilder
    private func memoRow(day: Date) -> some View {
        let note = habits.first { calendar.isDate($0.date, inSameDayAs: day) }?.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        BlueprintDivider()
        Button {
            sheet = .memo(day)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
                Image(systemName: "square.and.pencil")
                    .font(.caption)
                    .foregroundStyle(Color.accent)
                    .frame(width: 8)
                    .accessibilityHidden(true)
                if let note, !note.isEmpty {
                    Text(verbatim: note)
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("history.day.memo.add")
                        .font(Typography.label)
                        .foregroundStyle(Color.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.cellPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func doseAndVisitRows(_ entries: DayEntries) -> some View {
        ForEach(entries.doses) { dose in
            let detail = dose.administeredAt.formatted(.dateTime.hour().minute()) + " · " + BodySite.localizedName(dose.site)
            dayRow(.dose, title: Text("history.day.dose \(dose.sequence)"), detail: Text(verbatim: detail))
                // N-E2: 길게 눌러 부위 고치기·취소 (취소는 기록을 지우지 않고 표시만, 종류별 보기에서 되돌릴 수 있다)
                .contextMenu {
                    Button { sheet = .site(dose) } label: { Label("history.day.editSite", systemImage: "figure.stand") }
                    Button { cancel(dose) } label: { Label("history.cancelDose", systemImage: "xmark.circle") }
                }
        }
        ForEach(entries.visits) { visit in
            let count = visit.labResults?.count ?? 0
            dayRow(.clinic, title: Text("history.day.clinic \(count)"), detail: visit.note.map { Text(verbatim: $0) })
        }
    }

    @ViewBuilder
    private func bodyRows(_ entries: DayEntries) -> some View {
        ForEach(entries.checks) { check in
            dayRow(.condition, title: Text(LocalizedStringKey(check.window.titleKey)), detail: symptomText(check))
                .contextMenu {
                    Button { delete(check) } label: { Label("history.day.delete", systemImage: "trash") }
                }
        }
        ForEach(entries.weights) { sample in
            dayRow(.weight, title: Text(verbatim: weightText(sample)), detail: sample.source == .healthKit ? Text("history.day.fromHealth") : nil)
                .contextMenu {
                    // 건강 앱에서 온 기록은 건강 앱에서 지운다
                    if sample.source == .manual {
                        Button { delete(sample) } label: { Label("history.day.delete", systemImage: "trash") }
                    }
                }
        }
    }

    @ViewBuilder
    private func habitRows(_ entries: DayEntries) -> some View {
        ForEach(entries.proteins) { entry in
            dayRow(.protein, title: Text("protein.total.approx \(entry.estimatedGrams)"), detail: Text(LocalizedStringKey(entry.meal.titleKey)))
                .contextMenu {
                    Button { delete(entry) } label: { Label("history.day.delete", systemImage: "trash") }
                }
        }
        ForEach(entries.sessions) { session in
            dayRow(.exercise, title: Text(LocalizedStringKey(session.kind.titleKey)), detail: Text("history.day.minutes \(session.durationMinutes)"))
                .contextMenu {
                    if session.source == .manual {
                        Button { delete(session) } label: { Label("history.day.delete", systemImage: "trash") }
                    }
                }
        }
        if !entries.habitKeys.isEmpty {
            dayRow(nil, title: Text(verbatim: entries.habitKeys.map(L10n.string).joined(separator: " · ")), detail: nil)
        }
    }

    /// 지난 날의 투약을 바로 채울 수 있게 (오늘은 오늘 화면에서)
    @ViewBuilder
    private func addDoseRow(day: Date, today: Date, hasDose: Bool) -> some View {
        if !hasDose, activePrescription != nil, day < today {
            BlueprintDivider()
            Button {
                sheet = .dose(calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day) ?? day)
            } label: {
                Label("history.day.addDose", systemImage: "plus")
                    .font(Typography.label)
                    .foregroundStyle(Color.accent)
            }
            .padding(Spacing.cellPadding)
        }
    }

    // MARK: 고치기·지우기 (N-E2). 투약은 지우지 않고 취소 표시만 (리포트 무결성)

    private func cancel(_ dose: Dose) {
        dose.isCancelled = true
        try? context.save()
    }

    private func delete(_ model: any PersistentModel) {
        context.delete(model)
        try? context.save()
    }

    private func symptomText(_ check: ConditionCheck) -> Text {
        let names = check.symptoms.filter { $0.severity > 0 }.map(\.symptom.localizedName)
        return names.isEmpty ? Text("history.day.noSymptoms") : Text(verbatim: names.joined(separator: ", "))
    }

    private func weightText(_ sample: WeightSample) -> String {
        var text = sample.kilograms.formatted(.number.precision(.fractionLength(1))) + " kg"
        if let fat = sample.bodyFatPercent {
            text += " · " + L10n.string("history.day.fat") + " " + fat.formatted(.number.precision(.fractionLength(1))) + "%"
        }
        return text
    }

    private func dayRow(_ kind: MarkKind?, title: Text, detail: Text?) -> some View {
        VStack(spacing: 0) {
            BlueprintDivider()
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
                Group {
                    if let kind {
                        kind.shape
                    } else {
                        Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Color.inkSecondary)
                    }
                }
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    if let kind {
                        Text(LocalizedStringKey("history.mark." + kind.rawValue))
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    title
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                    if let detail {
                        detail
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.cellPadding)
        }
    }

    // MARK: 모아 보기

    private var collections: some View {
        FrostCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("history.collections")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                    .padding(Spacing.cellPadding)
                collectionRow("history.byType", systemImage: "list.bullet") { path.append(.list) }
                if activePrescription != nil {
                    collectionRow("history.weekly", systemImage: "list.bullet.rectangle") { path.append(.summaries) }
                    collectionRow("history.pens", systemImage: "rectangle.split.3x1") { path.append(.pens) }
                }
                collectionRow("symptom.flow.title", systemImage: "chart.bar.xaxis") { path.append(.symptomFlow) }
                if !weights.isEmpty {
                    collectionRow("weight.trend.title", systemImage: "chart.xyaxis.line") { sheet = .weightTrend }
                }
            }
        }
    }

    private func collectionRow(_ key: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            BlueprintDivider()
            Button(action: action) {
                HStack(spacing: Spacing.s3) {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.accent)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                    Text(key)
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkTertiary)
                        .accessibilityHidden(true)
                }
                .padding(Spacing.cellPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// 날마다 기록한 종류. 색은 종류 구분일 뿐이고 모양으로도 구분한다
enum MarkKind: String, CaseIterable {
    case dose, clinic, condition, weight, protein, exercise

    @ViewBuilder
    var shape: some View {
        switch self {
        case .dose: Circle().fill(Color.accent)
        case .clinic: RoundedRectangle(cornerRadius: 1).fill(Color.accent)
        case .condition: Circle().strokeBorder(Color.ink.opacity(0.8), lineWidth: 1.2)
        case .weight: Capsule().fill(Color.ink.opacity(0.7))
        case .protein: RoundedRectangle(cornerRadius: 1.5).strokeBorder(Color.ink.opacity(0.8), lineWidth: 1.2)
        case .exercise: Image(systemName: "triangle.fill").resizable().foregroundStyle(Color.ink.opacity(0.7))
        }
    }

    func isOn(_ marks: DayMarks) -> Bool {
        switch self {
        case .dose: return marks.dose
        case .clinic: return marks.clinic
        case .condition: return marks.condition
        case .weight: return marks.weight
        case .protein: return marks.protein
        case .exercise: return marks.exercise
        }
    }
}

/// 날짜 아래 작은 표시들 (두 줄까지)
private struct MarkDots: View {
    let marks: DayMarks

    var body: some View {
        let kinds = MarkKind.allCases.filter { $0.isOn(marks) }
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(5), spacing: 2), count: 3), spacing: 2) {
            ForEach(kinds, id: \.self) { kind in
                kind.shape.frame(width: 5, height: 5)
            }
        }
        .frame(width: 19)
        .accessibilityHidden(true)
    }
}

/// 그날 메모 (N-E3). `HabitCheck.note`에 둔다. 앱은 해석하지 않는다
struct DayMemoSheet: View {
    let day: Date
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @Query(sort: \HabitCheck.date) private var habits: [HabitCheck]
    @State private var text = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("history.day.memo.placeholder", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($isEditing)
                } footer: {
                    Text("history.day.memo.footer")
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle(day.formatted(.dateTime.month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("action.save", action: save) }
            }
            .onAppear {
                text = habits.first { calendar.isDate($0.date, inSameDayAs: day) }?.note ?? ""
                isEditing = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        let start = calendar.startOfDay(for: day)
        let habit = habits.first { calendar.isDate($0.date, inSameDayAs: start) } ?? {
            let created = HabitCheck(date: start)
            context.insert(created)
            return created
        }()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.note = trimmed.isEmpty ? nil : trimmed
        try? context.save()
        onSaved()
        dismiss()
    }
}

/// 오늘 화면 한눈에 "남은 펜"을 눌렀을 때 (N-D4). 펜 현황 페이지를 시트로
struct PenStatusSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PenStatusPage()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("action.done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }
}

/// 모아 보기 > 펜 현황 (D20에서 오늘 화면에서 옮김)
struct PenStatusPage: View {
    @Environment(\.calendar) private var calendar
    @Query(sort: \Prescription.startDate) private var prescriptions: [Prescription]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.cardGap) {
                if let prescription = prescriptions.first(where: \.isActive) {
                    PenStatusCard(
                        status: PrescriptionRules.penStatus(p: prescription.snapshot, doses: prescription.doseSnapshots),
                        exhaustionDate: PrescriptionRules.exhaustionEstimate(p: prescription.snapshot, doses: prescription.doseSnapshots, now: .now, calendar: calendar),
                        memo: prescription.doseLabel,
                        tint: Color.prescription(slot: prescriptions.colorSlots[prescription.id] ?? 0)
                    )
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("history.pens")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
        .modelContainer(ModelContainer.previewWithSampleData)
        .preferredColorScheme(.dark)
}
