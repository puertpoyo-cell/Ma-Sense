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

        var id: String {
            switch self {
            case let .dose(date): return "dose.\(date.timeIntervalSinceReferenceDate)"
            case .weightTrend: return "weightTrend"
            }
        }
    }

    @Environment(\.calendar) private var calendar
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
                        selectedDay = HistoryDayRules.shiftWeek(day, by: -1, calendar: calendar)
                    } label: {
                        Image(systemName: "chevron.left").frame(minWidth: 36, minHeight: 32)
                    }
                    .accessibilityLabel(Text("history.week.previous"))
                    Spacer()
                    if let first = week.first, let last = week.last {
                        Text(verbatim: first.formatted(.dateTime.month(.defaultDigits).day()) + " – " + last.formatted(.dateTime.month(.defaultDigits).day()))
                            .font(Typography.label)
                            .monospacedDigit()
                            .foregroundStyle(Color.ink)
                    }
                    Spacer()
                    Button {
                        let next = HistoryDayRules.shiftWeek(day, by: 1, calendar: calendar)
                        selectedDay = min(next, today)
                    } label: {
                        Image(systemName: "chevron.right").frame(minWidth: 36, minHeight: 32)
                    }
                    .disabled(isThisWeek)
                    .accessibilityLabel(Text("history.week.next"))
                }
                .foregroundStyle(Color.accent)

                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { date in
                        dayButton(date, isSelected: calendar.isDate(date, inSameDayAs: day), isToday: date == today, isFuture: date > today)
                    }
                }

                legend
            }
        }
    }

    private func dayButton(_ date: Date, isSelected: Bool, isToday: Bool, isFuture: Bool) -> some View {
        let marks = isFuture ? DayMarks() : marks(on: date)
        return Button {
            selectedDay = date
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

    private func dayCard(day: Date, today: Date) -> some View {
        let same = { (date: Date) in calendar.isDate(date, inSameDayAs: day) }
        let dayDoses = allDoses.filter { !$0.isCancelled && same($0.administeredAt) }.sorted { $0.administeredAt < $1.administeredAt }
        let dayVisits = visits.filter { same($0.visitedAt) }
        let dayChecks = checks.filter { same($0.checkedAt) }
        let dayWeights = weights.filter { same($0.measuredAt) }
        let dayProteins = proteins.filter { same($0.date) }
        let daySessions = sessions.filter { same($0.startedAt) }
        let dayHabit = habits.first { same($0.date) }
        let habitKeys = [
            dayHabit?.water == true ? "habit.water" : nil,
            dayHabit?.fiber == true ? "habit.fiber" : nil,
            dayHabit?.sleep == true ? "habit.sleep" : nil,
        ].compactMap { $0 }
        let isEmpty = dayDoses.isEmpty && dayVisits.isEmpty && dayChecks.isEmpty && dayWeights.isEmpty
            && dayProteins.isEmpty && daySessions.isEmpty && habitKeys.isEmpty

        return FrostCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(day.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                    .padding(Spacing.cellPadding)

                if isEmpty {
                    BlueprintDivider()
                    Text("history.day.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(Spacing.cellPadding)
                }

                ForEach(dayDoses) { dose in
                    dayRow(.dose, title: Text("history.day.dose \(dose.sequence)"), detail: Text(verbatim: dose.administeredAt.formatted(.dateTime.hour().minute()) + " · " + BodySite.localizedName(dose.site)))
                }
                ForEach(dayVisits) { visit in
                    dayRow(.clinic, title: Text("history.day.clinic \(visit.labResults?.count ?? 0)"), detail: visit.note.map { Text(verbatim: $0) })
                }
                ForEach(dayChecks) { check in
                    let symptoms = check.symptoms.filter { $0.severity > 0 }.map(\.symptom.localizedName).joined(separator: ", ")
                    dayRow(.condition, title: Text(LocalizedStringKey(check.window.titleKey)), detail: symptoms.isEmpty ? Text("history.day.noSymptoms") : Text(verbatim: symptoms))
                }
                ForEach(dayWeights) { sample in
                    let fat = sample.bodyFatPercent.map { " · " + L10n.string("history.day.fat") + " " + $0.formatted(.number.precision(.fractionLength(1))) + "%" } ?? ""
                    dayRow(.weight, title: Text(verbatim: sample.kilograms.formatted(.number.precision(.fractionLength(1))) + " kg" + fat), detail: nil)
                }
                if !dayProteins.isEmpty {
                    let grams = dayProteins.reduce(0) { $0 + $1.estimatedGrams }
                    let meals = dayProteins.map { L10n.string($0.meal.titleKey) }.joined(separator: ", ")
                    dayRow(.protein, title: Text("protein.total.approx \(grams)"), detail: Text(verbatim: meals))
                }
                ForEach(daySessions) { session in
                    dayRow(.exercise, title: Text(LocalizedStringKey(session.kind.titleKey)), detail: Text("history.day.minutes \(session.durationMinutes)"))
                }
                if !habitKeys.isEmpty {
                    dayRow(nil, title: Text(verbatim: habitKeys.map(L10n.string).joined(separator: " · ")), detail: nil)
                }

                // 지난 날의 투약을 바로 채울 수 있게 (오늘은 오늘 화면에서)
                if dayDoses.isEmpty, activePrescription != nil, day < today {
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
        }
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
