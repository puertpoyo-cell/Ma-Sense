import Charts
import SwiftData
import SwiftUI

/// S14 진료 탭 (D20). 진료 전에는 다음 진료·물어볼 것, 진료 직후에는 진료 기록(메모·검사지 사진·검사 결과).
/// 검사 결과는 숫자와 날짜만. 기준 범위·정상/높음·색 없음 (COMPLIANCE.md 2.2)
struct ClinicView: View {
    var openReport: () -> Void = {}

    private enum Sheet: Identifiable {
        case newVisit
        case editVisit(ClinicVisit)
        case questions
        case prescription

        var id: String {
            switch self {
            case .newVisit: return "newVisit"
            case let .editVisit(visit): return "edit." + visit.id.uuidString
            case .questions: return "questions"
            case .prescription: return "prescription"
            }
        }
    }

    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Prescription> { $0.isActive }) private var activePrescriptions: [Prescription]
    @Query(sort: \ClinicVisit.visitedAt, order: .reverse) private var visits: [ClinicVisit]
    @Query(sort: \LabResult.measuredAt) private var labResults: [LabResult]
    @Query(filter: #Predicate<ClinicQuestion> { $0.askedAt == nil }, sort: \ClinicQuestion.createdAt) private var pendingQuestions: [ClinicQuestion]
    @Query private var settingsList: [UserSettings]
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var sheet: Sheet?
    @State private var showsToast = false

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    nextClinicCard(now: timeline.date)
                    questionsCard
                    PrimaryButton("clinic.visit.new") { sheet = .newVisit }
                    labsCard
                    visitsCard
                    NoticeLine("lab.notice")
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
                .padding(.bottom, Spacing.s6)
            }
        }
        .midnightBackground()
        .navigationTitle("tab.clinic")
        .navigationDestination(for: String.self) { itemKey in
            LabItemHistoryView(itemKey: itemKey)
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            // N-F1: 지난 진료의 검사 항목·단위를 빈 값으로 미리 채운다
            case .newVisit: ClinicVisitSheet(template: visits.first) { showsToast = true }
            case let .editVisit(visit): ClinicVisitSheet(editing: visit) { showsToast = true }
            case .questions: ClinicQuestionsSheet()
            case .prescription:
                if let prescription = activePrescriptions.first {
                    PrescriptionSheet(editing: prescription)
                } else {
                    PrescriptionSheet()
                }
            }
        }
        .recordedToast(isPresented: $showsToast)
        #if DEBUG
        .task {
            if ScreenshotRoute.current == .clinicVisit { sheet = .newVisit }
        }
        #endif
    }

    // MARK: 다음 진료

    private func nextClinicCard(now: Date) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("clinic.next.title")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                if let date = activePrescriptions.first?.nextClinicDate {
                    let days = TodayModel.daysBetween(now, date, calendar: calendar)
                    HStack(alignment: .firstTextBaseline) {
                        Text(date.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))
                            .font(Typography.metricLarge)
                            .foregroundStyle(Color.ink)
                        Spacer()
                        if days >= 0 {
                            Text(days == 0 ? "clinic.next.today" : "clinic.next.days \(days)")
                                .font(Typography.label)
                                .monospacedDigit()
                                .foregroundStyle(Color.accent)
                        }
                    }
                } else {
                    Text("clinic.next.none")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                }
                if !activePrescriptions.isEmpty {
                    Button("clinic.next.edit") { sheet = .prescription }
                        .font(Typography.label)
                        .foregroundStyle(Color.accent)
                }
                // N-F3: 진료 알림(며칠 전)을 여기서 바로. 설정 > 알림과 같은 값
                if let settings = settingsList.first, activePrescriptions.first?.nextClinicDate != nil {
                    BlueprintDivider(crosshair: .none)
                    reminderStepper(settings)
                }
            }
        }
    }

    private func reminderStepper(_ settings: UserSettings) -> some View {
        Stepper(value: Binding(get: { settings.clinicReminderDaysBefore }, set: { newValue in
            settings.clinicReminderDaysBefore = newValue
            try? context.save()
            Task { await services.refreshReminders(context: context) }
        }), in: 0...7) {
            HStack {
                Text("settings.notifications.clinic")
                    .font(Typography.label)
                    .foregroundStyle(Color.ink)
                Spacer()
                Group {
                    if settings.clinicReminderDaysBefore == 0 {
                        Text("settings.sameDay")
                    } else {
                        Text("settings.daysBefore \(settings.clinicReminderDaysBefore)").monospacedDigit()
                    }
                }
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    // MARK: 물어볼 것

    private var questionsCard: some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("clinic.questions.title")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    if !pendingQuestions.isEmpty {
                        Text("clinic.card.questions \(pendingQuestions.count)")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                ForEach(pendingQuestions.prefix(3)) { question in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                            .accessibilityHidden(true)
                        Text(verbatim: question.text)
                            .font(Typography.body)
                            .foregroundStyle(Color.ink)
                            .lineLimit(2)
                    }
                }
                AdaptiveStack(spacing: Spacing.s2) {
                    GhostButton("clinic.questions.title") { sheet = .questions }
                    GhostButton("clinic.prepareReport", action: openReport)
                }
            }
        }
    }

    // MARK: 최근 검사

    private var labsCard: some View {
        let latest = LabRules.latestByItem(labResults.map(\.snapshot))
        return FrostCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("clinic.labs.title")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                    .padding(Spacing.cellPadding)
                if latest.isEmpty {
                    BlueprintDivider()
                    Text("clinic.labs.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(Spacing.cellPadding)
                } else {
                    ForEach(latest, id: \.itemKey) { result in
                        BlueprintDivider()
                        NavigationLink(value: result.itemKey) {
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                                Text(verbatim: result.displayName)
                                    .font(Typography.body)
                                    .foregroundStyle(Color.ink)
                                Spacer(minLength: Spacing.s2)
                                Text(verbatim: ClinicVisitSheet.format(result.value))
                                    .font(Typography.body.weight(.semibold))
                                    .foregroundStyle(Color.ink)
                                Text(verbatim: result.unit)
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.inkSecondary)
                                Text(result.measuredAt.formatted(.dateTime.year(.twoDigits).month(.defaultDigits).day()))
                                    .font(Typography.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.inkTertiary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
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
        }
    }

    // MARK: 진료 기록

    @ViewBuilder
    private var visitsCard: some View {
        if !visits.isEmpty {
            FrostCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("clinic.visits.title")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                        .padding(Spacing.cellPadding)
                    ForEach(visits) { visit in
                        BlueprintDivider()
                        Button {
                            sheet = .editVisit(visit)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.s1) {
                                HStack {
                                    Text(visit.visitedAt.formatted(.dateTime.year().month(.defaultDigits).day()))
                                        .font(Typography.label)
                                        .foregroundStyle(Color.ink)
                                    Spacer()
                                    Text("clinic.visits.counts \(visit.labResults?.count ?? 0) \(visit.photos?.count ?? 0)")
                                        .font(Typography.caption)
                                        .foregroundStyle(Color.inkSecondary)
                                }
                                if let note = visit.note {
                                    Text(verbatim: note)
                                        .font(Typography.caption)
                                        .foregroundStyle(Color.inkSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(Spacing.cellPadding)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

extension LabResultSnapshot {
    /// 목록 이름: 직접 입력이면 적은 이름 그대로
    var displayName: String {
        item == .custom ? (customName ?? "") : L10n.string("lab.item." + item.rawValue)
    }
}

/// 검사 항목 하나의 기록 (D20). 날짜별 숫자와 같은 색 한 가지의 선 그래프. 기준선·범위 띠·판단 색 없음
struct LabItemHistoryView: View {
    let itemKey: String

    @Query(sort: \LabResult.measuredAt) private var labResults: [LabResult]
    /// N-F5: 점을 눌러 그날 숫자 보기
    @State private var selectedDate: Date?

    var body: some View {
        let history = LabRules.history(of: itemKey, in: labResults.map(\.snapshot))
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                if history.count >= 2 {
                    FrostCard {
                        chart(history)
                            .frame(height: 180)
                    }
                }
                FrostCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(history.reversed().enumerated()), id: \.element.id) { index, result in
                            if index > 0 { BlueprintDivider() }
                            HStack(alignment: .firstTextBaseline) {
                                Text(result.measuredAt.formatted(.dateTime.year().month(.defaultDigits).day()))
                                    .font(Typography.body)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.inkSecondary)
                                Spacer()
                                Text(verbatim: ClinicVisitSheet.format(result.value))
                                    .font(Typography.body.weight(.semibold))
                                    .foregroundStyle(Color.ink)
                                Text(verbatim: result.unit)
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            .padding(Spacing.cellPadding)
                        }
                    }
                }
                NoticeLine("lab.notice")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle(history.first?.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chart(_ history: [LabResultSnapshot]) -> some View {
        Chart {
            ForEach(history, id: \.id) { result in
                LineMark(x: .value("date", result.measuredAt), y: .value("value", result.value))
                    .foregroundStyle(Color.accent)
                PointMark(x: .value("date", result.measuredAt), y: .value("value", result.value))
                    .foregroundStyle(Color.accent)
            }
            if let selected = selected(in: history) {
                RuleMark(x: .value("date", selected.measuredAt))
                    .foregroundStyle(Color.inkTertiary)
                    .annotation(position: .top, alignment: .center) {
                        selectionLabel(selected)
                    }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXSelection(value: $selectedDate)
    }

    private func selectionLabel(_ selected: LabResultSnapshot) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: ClinicVisitSheet.format(selected.value) + " " + selected.unit)
                .font(Typography.label)
                .foregroundStyle(Color.ink)
            Text(selected.measuredAt.formatted(.dateTime.year(.twoDigits).month(.defaultDigits).day()))
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, Spacing.s2)
        .padding(.vertical, Spacing.s1)
        .background(Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    /// 누른 자리에 가장 가까운 기록
    private func selected(in history: [LabResultSnapshot]) -> LabResultSnapshot? {
        guard let selectedDate else { return nil }
        return history.min { abs($0.measuredAt.timeIntervalSince(selectedDate)) < abs($1.measuredAt.timeIntervalSince(selectedDate)) }
    }
}
