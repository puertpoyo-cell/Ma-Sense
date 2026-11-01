import Charts
import SwiftData
import SwiftUI

/// S14 진료 탭 (D20). 진료 전에는 다음 진료·물어볼 것, 진료 직후에는 진료 기록(메모·검사지 사진·검사 결과).
/// 검사 결과는 숫자와 날짜만. 기준 범위·정상/높음·색 없음 (COMPLIANCE.md 2.2)
struct ClinicView: View {
    var openReport: () -> Void = {}

    private enum Sheet: Identifiable {
        /// 새 진료 기록. 날짜가 있으면 그 진료일로 시작 (D28 결과 적기)
        case newVisit(Date?)
        case editVisit(ClinicVisit)
        case questions
        case prescription
        /// D28 다음 진료 예약
        case appointment
        /// D28 캘린더에 넣기
        case calendar(Date)
        /// D29 처방 카드
        case newPrescription
        case refill(Prescription)

        var id: String {
            switch self {
            case .newVisit: return "newVisit"
            case let .editVisit(visit): return "edit." + visit.id.uuidString
            case .questions: return "questions"
            case .prescription: return "prescription"
            case .newPrescription:
                PrescriptionSheet()
            case let .refill(prescription):
                RefillSheet(prescription: prescription) { showsToast = true }
            case .appointment: return "appointment"
            case .calendar: return "calendar"
            case .newPrescription: return "newPrescription"
            case .refill: return "refill"
            }
        }
    }

    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Prescription> { $0.isActive }) private var activePrescriptions: [Prescription]
    @Query(sort: \Prescription.startDate) private var allPrescriptions: [Prescription]
    @Query(sort: \ClinicVisit.visitedAt, order: .reverse) private var visits: [ClinicVisit]
    @Query(sort: \LabResult.measuredAt) private var labResults: [LabResult]
    @Query(filter: #Predicate<ClinicQuestion> { $0.askedAt == nil }, sort: \ClinicQuestion.createdAt) private var pendingQuestions: [ClinicQuestion]
    @Query private var settingsList: [UserSettings]
    /// D28 받은 펜 (진료 기록·새 펜 받음)
    @Query(sort: \PenSupply.receivedAt, order: .reverse) private var supplies: [PenSupply]
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var sheet: Sheet?
    @State private var showsToast = false
    /// 펼침 배치용 스크롤 화면 크기 (D23)
    @State private var viewport: CGSize = .zero

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            ScrollView {
                // D23: 펼친 가로 화면은 왼쪽 다음 진료·물어볼 것·새 진료, 오른쪽 검사 결과·진료 기록 2단
                UnfoldColumns(container: viewport) {
                    nextClinicCard(now: timeline.date)
                    // D29: 설정에만 있던 처방 정보를 진료 탭에
                    PrescriptionCard(
                        prescription: activePrescriptions.first,
                        tint: Color.prescription(slot: activePrescriptions.first.flatMap { allPrescriptions.colorSlots[$0.id] } ?? 0),
                        onRefill: { if let p = activePrescriptions.first { sheet = .refill(p) } },
                        onEdit: { sheet = .prescription },
                        onNew: { sheet = .newPrescription }
                    )
                    questionsCard
                } trailing: {
                    archiveCard
                    labsCard
                } footer: {
                    NoticeLine("lab.notice")
                }
            }
            .readsViewportSize(into: $viewport)
        }
        .midnightBackground()
        .navigationTitle("tab.clinic")
        .navigationDestination(for: String.self) { itemKey in
            LabItemHistoryView(itemKey: itemKey)
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            // N-F1: 지난 진료의 검사 항목·단위를 빈 값으로 미리 채운다
            case let .newVisit(date): ClinicVisitSheet(template: visits.first, visitDate: date) { showsToast = true }
            case let .editVisit(visit): ClinicVisitSheet(editing: visit, supply: supplies.first { $0.visitID == visit.id }) { showsToast = true }
            case .questions: ClinicQuestionsSheet()
            case .prescription:
                if let prescription = activePrescriptions.first {
                    PrescriptionSheet(editing: prescription)
                } else {
                    PrescriptionSheet()
                }
            case .appointment:
                if let prescription = activePrescriptions.first {
                    AppointmentSheet(prescription: prescription) { _ in showsToast = true }
                }
            case let .calendar(date):
                CalendarEventSheet(date: date, title: L10n.string("appointment.calendar.title")) { self.sheet = nil }
                    .ignoresSafeArea()
            }
        }
        .recordedToast(isPresented: $showsToast)
        #if DEBUG
        .task {
            if ScreenshotRoute.current == .clinicVisit { sheet = .newVisit(nil) }
        }
        #endif
    }

    // MARK: 다음 진료 (D28: 예약 → 진료 → 결과 적기 → 다음 예약)

    private func nextClinicCard(now: Date) -> some View {
        let state = ClinicRules.appointment(
            next: activePrescriptions.first?.nextClinicDate,
            visitDates: visits.map(\.visitedAt),
            now: now,
            calendar: calendar
        )
        return FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                switch state {
                case .none:
                    Text("clinic.next.title")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Text("clinic.next.none")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                    if !activePrescriptions.isEmpty {
                        PrimaryButton("appointment.add") { sheet = .appointment }
                    }
                    GhostButton("clinic.visit.new") { sheet = .newVisit(nil) }
                case let .upcoming(date, days):
                    appointmentHeader(date, trailing: Text("clinic.next.days \(days)"))
                    AdaptiveStack(spacing: Spacing.s2) {
                        GhostButton("appointment.change") { sheet = .appointment }
                        GhostButton("appointment.calendar") { sheet = .calendar(date) }
                    }
                case let .today(date):
                    appointmentHeader(date, trailing: Text("clinic.next.today"))
                    PrimaryButton("clinic.result.add") { sheet = .newVisit(date) }
                    AdaptiveStack(spacing: Spacing.s2) {
                        GhostButton("appointment.change") { sheet = .appointment }
                        GhostButton("appointment.calendar") { sheet = .calendar(date) }
                    }
                case let .needsResult(date):
                    // 진료 날이 지났다: 결과부터. 화면의 "10.29"처럼 지난 날짜가 다음 진료로 남지 않게
                    Text("clinic.result.pending.title")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Text("clinic.result.pending \(date.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))")
                        .font(Typography.title)
                        .foregroundStyle(Color.ink)
                    PrimaryButton("clinic.result.add") { sheet = .newVisit(date) }
                    GhostButton("appointment.add") { sheet = .appointment }
                case .recorded:
                    Text("clinic.next.title")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                    Text("clinic.next.afterVisit")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                    PrimaryButton("appointment.add") { sheet = .appointment }
                }
                // N-F3: 진료 알림(며칠 전)을 여기서 바로. 설정 > 알림과 같은 값
                if let settings = settingsList.first, case .upcoming = state {
                    BlueprintDivider(crosshair: .none)
                    reminderStepper(settings)
                }
            }
        }
    }

    /// 다음 진료 날짜·시각 크게, 오른쪽 D-n
    private func appointmentHeader(_ date: Date, trailing: Text) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Text("clinic.next.title")
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            HStack(alignment: .firstTextBaseline) {
                Text(date.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))
                    .font(Typography.metricLarge)
                    .foregroundStyle(Color.ink)
                Spacer()
                trailing
                    .font(Typography.label)
                    .monospacedDigit()
                    .foregroundStyle(Color.accent)
            }
            if ClinicRules.hasTime(date, calendar: calendar) {
                Text(date.formatted(.dateTime.hour().minute()))
                    .font(Typography.label)
                    .monospacedDigit()
                    .foregroundStyle(Color.inkSecondary)
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
                    GhostButton("clinic.questions.manage") { sheet = .questions }
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

    // MARK: 진료·받은 펜 기록 (D28 아카이브)

    private enum ArchiveEntry: Identifiable {
        case visit(ClinicVisit, PenSupply?)
        /// 진료 기록 없이 받은 펜 (오늘 화면 "새 펜 받음")
        case supply(PenSupply)

        var id: String {
            switch self {
            case let .visit(visit, _): return "v." + visit.id.uuidString
            case let .supply(supply): return "s." + supply.id.uuidString
            }
        }

        var date: Date {
            switch self {
            case let .visit(visit, _): return visit.visitedAt
            case let .supply(supply): return supply.receivedAt
            }
        }
    }

    private var archive: [ArchiveEntry] {
        let visitIDs = Set(visits.map(\.id))
        let byVisit = Dictionary(supplies.compactMap { s in s.visitID.map { ($0, s) } }, uniquingKeysWith: { first, _ in first })
        let entries = visits.map { ArchiveEntry.visit($0, byVisit[$0.id]) }
            + supplies.filter { $0.visitID.map { !visitIDs.contains($0) } ?? true }.map(ArchiveEntry.supply)
        return entries.sorted { $0.date > $1.date }
    }

    private var archiveCard: some View {
        let entries = archive
        let total = ClinicRules.totalPackages(supplies.map(\.packages))
        return FrostCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("clinic.visits.title")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    if total > 0 {
                        Text("clinic.archive.totalPackages \(total)")
                            .font(Typography.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .padding(Spacing.cellPadding)
                if entries.isEmpty {
                    BlueprintDivider()
                    Text("clinic.archive.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(Spacing.cellPadding)
                }
                ForEach(entries) { entry in
                    BlueprintDivider()
                    switch entry {
                    case let .visit(visit, supply):
                        Button { sheet = .editVisit(visit) } label: {
                            archiveRow(date: visit.visitedAt, title: Text("clinic.archive.visit"), supply: supply, comment: visit.note,
                                       labs: visit.labResults?.count ?? 0, photos: visit.photos?.count ?? 0)
                        }
                        .buttonStyle(.plain)
                    case let .supply(supply):
                        archiveRow(date: supply.receivedAt, title: Text("clinic.archive.refill"), supply: supply, comment: nil, labs: 0, photos: 0)
                            .contextMenu {
                                Button("clinic.archive.deleteRefill") {
                                    context.delete(supply)
                                    try? context.save()
                                }
                            }
                    }
                }
                if !entries.isEmpty {
                    BlueprintDivider()
                    Button { sheet = .newVisit(nil) } label: {
                        Label("clinic.visit.new", systemImage: "plus")
                            .font(Typography.label)
                            .foregroundStyle(Color.accent)
                            .padding(Spacing.cellPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 날짜 · 종류 / 받은 펜 알약 + 처방 메모(적은 그대로) / 의사 코멘트 2줄 / 검사·사진 수(있을 때만)
    private func archiveRow(date: Date, title: Text, supply: PenSupply?, comment: String?, labs: Int, photos: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.formatted(.dateTime.year().month(.defaultDigits).day()))
                    .font(Typography.label.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                title
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                if labs + photos > 0 {
                    Text("clinic.visits.counts \(labs) \(photos)")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            if let supply, supply.packages > 0 {
                HStack(spacing: Spacing.s2) {
                    Label {
                        Text("clinic.archive.packages \(supply.packages)")
                    } icon: {
                        Image(systemName: "shippingbox")
                    }
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, Spacing.s2)
                    .padding(.vertical, Spacing.s1)
                    .background(Color.accentSoft, in: Capsule())
                    if let memo = supply.prescriptionMemo {
                        Text(verbatim: memo)
                            .font(Typography.label)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                    }
                }
            }
            if let comment {
                Text(verbatim: comment)
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)
            }
        }
        .padding(Spacing.cellPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
