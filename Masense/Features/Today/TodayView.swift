import SwiftData
import SwiftUI

/// S1 오늘 (홈). 위에서 아래로 Frost 카드 스택: 1-1 카운트다운, 1-1a 지난 투약 안내, 1-2 컨디션, 1-1c 지난 정리, 1-1b 남은 펜, 1-3 체중, 1-4 오늘의 마디, 1-5 진료, 1-7 맨몸 근력 예시, 1-6 알아 두기.
struct TodayView: View {
    var openReport: () -> Void = {}

    private enum Sheet: Identifiable {
        case prescription
        case dose
        case condition(doseID: UUID, window: ConditionWindow)
        case weight
        case protein(preselected: ProteinFood?)
        case strength
        case backfill
        case questions
        case weightTrend

        var id: String {
            switch self {
            case .weightTrend: return "weightTrend"
            case .backfill: return "backfill"
            case .questions: return "questions"
            case .prescription: return "prescription"
            case .dose: return "dose"
            case let .condition(doseID, window): return "condition.\(doseID.uuidString).\(window.rawValue)"
            case .weight: return "weight"
            case let .protein(food): return "protein.\(food?.rawValue ?? "")"
            case .strength: return "strength"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @Environment(\.calendar) private var calendar
    @Environment(\.router) private var router
    @Query(filter: #Predicate<Prescription> { $0.isActive })
    private var activePrescriptions: [Prescription]
    /// 처방 구간 색 자리 계산용 (R13-2)
    @Query(sort: \Prescription.startDate) private var allPrescriptions: [Prescription]
    @Query(sort: \ConditionCheck.checkedAt)
    private var checks: [ConditionCheck]
    @Query(sort: \WeightSample.measuredAt)
    private var weights: [WeightSample]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \ProteinEntry.date) private var proteins: [ProteinEntry]
    @Query(sort: \StrengthSession.startedAt) private var sessions: [StrengthSession]
    @Query(sort: \HabitCheck.date) private var habits: [HabitCheck]
    @Query(filter: #Predicate<ClinicQuestion> { $0.askedAt == nil }) private var pendingQuestions: [ClinicQuestion]
    @State private var sheet: Sheet?
    #if DEBUG
    @State private var opensSettingsForScreenshot = ScreenshotRoute.current.map { [.settings, .importSheet, .importResult].contains($0) } ?? false
    @State private var screenshotDestination: ScreenshotRoute? = ScreenshotRoute.current.flatMap { [.symptomFlow, .infoList].contains($0) ? $0 : nil }
    #endif
    @State private var showsToast = false
    /// 지난 투약 안내 카드를 닫은 처방 id (D6). 기기 화면 상태라 SwiftData 대신 UserDefaults
    @AppStorage("backfill.dismissedPrescription") private var dismissedBackfill = ""
    /// 닫은 사실 한 줄 "종류|날짜", 닫은 주간 정리 구간 시작 (D8). 기기 화면 상태
    @AppStorage("dailyLine.dismissed") private var dismissedDailyLine = ""
    @AppStorage("weeklySummary.dismissedStart") private var dismissedWeeklyStart: Double = 0
    /// 닫은 패키지 정리 구간 시작 (D9)
    @AppStorage("packageSummary.dismissedStart") private var dismissedPackageStart: Double = 0
    @State private var weeklyListDestination: WeeklySummaryListView.Segment?
    /// 하루 닫은 맨몸 근력 예시 카드의 날짜 "y-m-d" (D10). 기기 화면 상태
    @AppStorage("strengthRoutine.dismissedDay") private var dismissedRoutineDay = ""
    /// 진료 카드의 "진료 준비" (D9)
    @State private var infoDestination: InfoTopic?

    private var prescription: Prescription? { activePrescriptions.first }

    var body: some View {
        // 카운트다운이 분 단위로 바뀌도록 1분마다 다시 그린다. `now` 주입 지점
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let model = makeModel(now: timeline.date)
            ScrollView {
                VStack(spacing: Spacing.cardGap) {
                    if let line = model.dailyLine, dismissedDailyLine != dailyLineKey(line, now: timeline.date) {
                        dailyLineView(line, now: timeline.date)
                    }
                    countdownCard(model)
                    // 처방이 없으면 1-1만 보인다 (SCREENS.md 빈 상태)
                    if let prescription {
                        if model.backfillCount > 0, dismissedBackfill != prescription.id.uuidString {
                            backfillCard(count: model.backfillCount, prescriptionID: prescription.id)
                        }
                        if let prompt = model.conditionPrompt {
                            conditionCard(prompt)
                        }
                        if let package = model.packageSummary, package.package.period.start.timeIntervalSinceReferenceDate != dismissedPackageStart {
                            // 패키지 정리가 보이는 동안은 주간 정리 카드를 함께 띄우지 않는다 (D9)
                            PackageSummaryCard(
                                summary: package,
                                isSingleUsePen: prescription.dosesPerPen == 1,
                                onShowAll: { weeklyListDestination = .packages },
                                onDismiss: {
                                    dismissedPackageStart = package.package.period.start.timeIntervalSinceReferenceDate
                                    if let weekly = model.weeklySummary {
                                        dismissedWeeklyStart = weekly.period.start.timeIntervalSinceReferenceDate
                                    }
                                }
                            )
                        } else if let summary = model.weeklySummary, summary.period.start.timeIntervalSinceReferenceDate != dismissedWeeklyStart {
                            WeeklySummaryCard(
                                summary: summary,
                                onShowAll: { weeklyListDestination = .weeks },
                                onDismiss: { dismissedWeeklyStart = summary.period.start.timeIntervalSinceReferenceDate }
                            )
                        }
                        if let pens = model.pens {
                            PenStatusCard(
                                status: pens,
                                exhaustionDate: model.exhaustionDate,
                                memo: prescription.doseLabel,
                                tint: Color.prescription(slot: allPrescriptions.colorSlots[prescription.id] ?? 0)
                            )
                        }
                        weightCard(model)
                        dailyCycleCard(model.daily, now: timeline.date)
                        if let clinic = model.clinicDate {
                            clinicCard(clinic)
                        }
                        // 저컨디션 날(R11)에는 근력 예시를 띄우지 않는다
                        if !model.daily.isLowCondition, dismissedRoutineDay != dayKey(timeline.date) {
                            routineCard(now: timeline.date)
                        }
                    }
                    infoRow
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
            }
        }
        .midnightBackground()
        .navigationTitle("tab.today")
        .navigationDestination(item: $weeklyListDestination) { segment in
            WeeklySummaryListView(initialSegment: segment)
        }
        .navigationDestination(item: $infoDestination) { topic in
            InfoTopicView(topic: topic, openReport: openReport)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("settings.title")
            }
        }
        #if DEBUG
        .navigationDestination(isPresented: $opensSettingsForScreenshot) { SettingsView() }
        .navigationDestination(item: $screenshotDestination) { route in
            if route == .symptomFlow {
                SymptomFlowView()
            } else {
                InfoListView(openReport: openReport)
            }
        }
        .task { openSheetForScreenshot() }
        #endif
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
        }
        .onChange(of: router.pending, initial: true) { _, route in
            if let route { open(route) }
        }
        .recordedToast(isPresented: $showsToast)
        .task { await syncHealthIfAuthorized() }
    }

    private func makeModel(now: Date) -> TodayModel {
        TodayModel(
            prescription: prescription?.snapshot,
            doses: prescription?.doseSnapshots ?? [],
            checks: checks.compactMap(\.snapshot),
            weights: weights.map(\.snapshot),
            proteins: proteins.map(\.snapshot),
            sessions: sessions.map(\.snapshot),
            habits: habits.map(\.snapshot),
            proteinTarget: settingsList.first?.proteinTargetGrams,
            heightCm: settingsList.first?.heightCm,
            allDoses: allPrescriptions.flatMap(\.doses).map(\.snapshot),
            now: now,
            calendar: calendar
        )
    }

    // MARK: 맨 위 사실 한 줄 (R17, D8)

    /// 하루에 한 번 닫는다: 같은 종류·같은 날이면 숨김
    private func dailyLineKey(_ line: DailyLine, now: Date) -> String {
        "\(line.kind)|\(dayKey(now))"
    }

    /// 하루 단위로 닫는 카드의 키 "y-m-d"
    private func dayKey(_ date: Date) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }

    private func dailyLineView(_ line: DailyLine, now: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
            Group {
                switch line {
                case let .doseDay(site?):
                    Text("daily.line.doseDay \(site.localizedName)")
                case .doseDay(nil):
                    Text("daily.line.doseDay.noSite")
                case let .lowSupply(remaining, true):
                    Text("daily.line.lowPens \(remaining)")
                case let .lowSupply(remaining, false):
                    Text("daily.line.lowDoses \(remaining)")
                case .noRecentWeight:
                    Text("daily.line.noWeight")
                }
            }
            .font(Typography.body)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                dismissedDailyLine = dailyLineKey(line, now: now)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(minWidth: 32, minHeight: 32)
            }
            .accessibilityLabel(Text("daily.line.dismiss"))
        }
        .padding(.leading, Spacing.s4)
        .padding(.trailing, Spacing.s2)
        .padding(.vertical, Spacing.s1)
        .background(Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    // MARK: 1-1 카운트다운 (CountdownHero, DESIGN_SYSTEM.md 5.2)

    private func countdownCard(_ model: TodayModel) -> some View {
        CountdownHero(
            countdown: model.countdown,
            scheduleDate: model.scheduleDate,
            usedDoses: model.usedDoses,
            totalDoses: model.totalDoses,
            onLogDose: { sheet = .dose },
            onEnterPrescription: { sheet = .prescription }
        )
    }

    // MARK: 1-1a 지난 투약 안내 (D6)

    /// 처방 시작일 이후 첫 기록 전에 빈 주가 있을 때. 사실만 알리고 한꺼번에 기록할 수 있게 한다
    private func backfillCard(count: Int, prescriptionID: UUID) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("backfill.title")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                Text("backfill.card.message \(count)")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                AdaptiveStack(spacing: Spacing.s2) {
                    GhostButton("backfill.card.action") { sheet = .backfill }
                    GhostButton("backfill.card.dismiss") { dismissedBackfill = prescriptionID.uuidString }
                }
            }
        }
    }

    // MARK: 1-2 컨디션 체크

    private func conditionCard(_ prompt: TodayModel.ConditionPrompt) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(LocalizedStringKey(prompt.window.titleKey))
                    .font(Typography.title)
                    .foregroundStyle(Color.ink)
                PrimaryButton("action.record") {
                    sheet = .condition(doseID: prompt.doseID, window: prompt.window)
                }
            }
        }
    }

    // MARK: 1-3 체중 (도면 셀: 체중 | 측정일 / 스파크라인 / 직접 입력)

    @ViewBuilder
    private func weightCard(_ model: TodayModel) -> some View {
        if let latest = model.latestWeight {
            FrostCard(padding: 0) {
                VStack(spacing: 0) {
                    BlueprintSplit {
                        BlueprintCell("weight.title") {
                            VStack(alignment: .leading, spacing: Spacing.s1) {
                                DimensionValue(latest.kilograms.formatted(.number.precision(.fractionLength(1))), unit: "unit.kg")
                                // R14: 키를 입력했을 때만 숫자로. 구간 이름 없음
                                if let bmi = model.latestBMI {
                                    Text("weight.bmi \(bmi.formatted(.number.precision(.fractionLength(1))))")
                                        .font(Typography.caption)
                                        .foregroundStyle(Color.inkSecondary)
                                }
                            }
                        }
                    } trailing: {
                        BlueprintCell("weight.measured") {
                            Text(latest.measuredAt.formatted(.dateTime.month(.defaultDigits).day()))
                                .font(Typography.label)
                                .foregroundStyle(Color.ink)
                        }
                    }
                    BlueprintDivider()
                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        WeekSparkline(points: model.weightSeries, tickDates: model.doseDatesInSeries)
                            .frame(height: 48)
                        // R8: 빠른 경우에만, 색 강조 없이 한 줄. 출처가 정해진 뒤에만 보인다 (COMPLIANCE.md 2.2)
                        if model.paceNotice != nil, let source = AppConfig.paceGuideSource {
                            NoticeLine("pace.notice")
                            Text(LocalizedStringKey(source))
                                .font(Typography.caption)
                                .foregroundStyle(Color.inkTertiary)
                        }
                    }
                    .padding(Spacing.cellPadding)
                    BlueprintDivider()
                    HStack {
                        // D7: 큰 그래프와 기간 선택
                        Button("weight.trend.open") { sheet = .weightTrend }
                        Spacer()
                        Button("weight.manualEntry") { sheet = .weight }
                    }
                    .font(Typography.label)
                    .foregroundStyle(Color.accent)
                    .padding(Spacing.cellPadding)
                }
            }
        } else {
            FrostCard {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("weight.title")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    Text("weight.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                    if services.healthKit.isAvailable {
                        GhostButton("onboarding.permissions.health") {
                            Task { await connectHealth() }
                        }
                    }
                    GhostButton("weight.manualEntry") { sheet = .weight }
                }
            }
        }
    }

    // MARK: 1-5 진료

    /// 진료 7일 전부터. 물어볼 것(D6)을 적거나 진료에서 물어봤다고 표시하고, 리포트를 준비한다
    private func clinicCard(_ date: Date) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("clinic.card \(date.formatted(.dateTime.month(.defaultDigits).day()))")
                        .font(Typography.title)
                        .foregroundStyle(Color.ink)
                    if !pendingQuestions.isEmpty {
                        Text("clinic.card.questions \(pendingQuestions.count)")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                AdaptiveStack(spacing: Spacing.s2) {
                    GhostButton("clinic.questions.title") { sheet = .questions }
                    GhostButton("clinic.prepareReport", action: openReport)
                }
                GhostButton("info.clinicPrep.title") { infoDestination = .clinicPrep }
            }
        }
    }

    // MARK: 1-7 맨몸 근력 예시 (D10)

    /// 페이지 아래 예시 루틴 (S8과 같은 문구). 일반 건강관리 정보이며 개인 맞춤이 아니다 (COMPLIANCE.md 2.2).
    /// 횟수·목표·연속일 없이 예시만 두고, 오늘 하루 닫을 수 있다
    private func routineCard(now: Date) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("exercise.routine.title")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Button {
                        dismissedRoutineDay = dayKey(now)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.inkSecondary)
                            .frame(minWidth: 32, minHeight: 32)
                    }
                    .accessibilityLabel(Text("today.routine.dismiss"))
                }
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    ForEach(StrengthSheet.routineKeys, id: \.self) { key in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                            Circle().fill(Color.accent).frame(width: 5, height: 5).accessibilityHidden(true)
                            Text(LocalizedStringKey(key))
                                .font(Typography.body)
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text("exercise.routine.repeat")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                NoticeLine("today.routine.notice")
                GhostButton("daily.logExercise") { sheet = .strength }
            }
        }
    }

    // MARK: 알아 두기 (D9, S13)

    /// 맨 아래 한 줄. 출처 있는 일반 정보와 진료 준비 목록
    private var infoRow: some View {
        NavigationLink {
            InfoListView(openReport: openReport)
        } label: {
            HStack(spacing: Spacing.s3) {
                Image(systemName: "book.closed")
                    .foregroundStyle(Color.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("info.title")
                        .font(Typography.label)
                        .foregroundStyle(Color.ink)
                    Text("info.row.summary")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.cellPadding)
            .background(Color.frost, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 시트

    /// 알림의 "기록하기"·위젯 링크 (D6). 처방이 없거나 열 컨디션 체크가 없으면 오늘 화면만 보여 준다
    private func open(_ route: AppRoute) {
        defer { router.finish(route) }
        switch route {
        case .logDose:
            if prescription != nil { sheet = .dose }
        case .conditionCheck:
            // 알림에서 들어온 순간이 now 주입 지점
            if let prompt = makeModel(now: Date()).conditionPrompt {
                sheet = .condition(doseID: prompt.doseID, window: prompt.window)
            }
        case .logWeight:
            sheet = .weight
        }
    }

    #if DEBUG
    /// 실행 인자 `-route sheet.*`로 시작할 때 해당 시트를 연다 (ScreenshotRoute)
    private func openSheetForScreenshot() {
        switch ScreenshotRoute.current {
        case .doseSheet?: sheet = .dose
        case .proteinSheet?: sheet = .protein(preselected: nil)
        case .strengthSheet?: sheet = .strength
        case .backfillSheet?: sheet = .backfill
        case .questionsSheet?: sheet = .questions
        case .weightTrendSheet?: sheet = .weightTrend
        case .summaryPackages?: weeklyListDestination = .packages
        case .infoProtein?: infoDestination = .proteinFoods
        case .infoClinicPrep?: infoDestination = .clinicPrep
        case .conditionSheet?:
            if let dose = prescription?.doses.filter({ !$0.isCancelled }).max(by: { $0.administeredAt < $1.administeredAt }) {
                sheet = .condition(doseID: dose.id, window: .h24)
            }
        default: break
        }
    }
    #endif

    @ViewBuilder
    private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .prescription:
            PrescriptionSheet()
        case .dose:
            if let prescription {
                DoseLogSheet(prescription: prescription) { showsToast = true }
            }
        case let .condition(doseID, window):
            if let dose = prescription?.doses.first(where: { $0.id == doseID }) {
                ConditionCheckSheet(dose: dose, window: window) { showsToast = true }
            }
        case .weight:
            WeightEntrySheet { showsToast = true }
        case let .protein(food):
            let model = makeModel(now: .now)
            ProteinSheet(
                model: ProteinLogModel(
                    target: settingsList.first?.proteinTargetGrams,
                    recordedToday: recordedProteinToday,
                    isLowAppetite: model.daily.isLowAppetite,
                    preselected: food
                )
            ) { showsToast = true }
        case .strength:
            StrengthSheet(isLowCondition: makeModel(now: .now).daily.isLowCondition) { showsToast = true }
        case .backfill:
            if let prescription {
                BackfillSheet(prescription: prescription) { showsToast = true }
            }
        case .questions:
            ClinicQuestionsSheet()
        case .weightTrend:
            WeightTrendSheet()
        }
    }

    private var recordedProteinToday: Int {
        ProteinRules.entries(on: .now, from: proteins.map(\.snapshot), calendar: calendar).reduce(0) { $0 + $1.estimatedGrams }
    }

    // MARK: 1-4 오늘의 마디 (M2, 도면 셀: 끼니 / 단백질 | 근력운동 / 기록 버튼 / 습관)

    private func dailyCycleCard(_ daily: TodayModel.DailyCycle, now: Date) -> some View {
        FrostCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("daily.title")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                    .padding(Spacing.cellPadding)
                BlueprintDivider()

                if daily.isLowAppetite {
                    // R10 식욕 저하일: "작게 자주" 칩
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("daily.smallFrequent")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.s2) {
                                ForEach(ProteinRules.smallFrequentFoods) { food in
                                    Button(LocalizedStringKey(food.titleKey)) { sheet = .protein(preselected: food) }
                                        .font(Typography.label)
                                        .foregroundStyle(Color.ink)
                                        .padding(.horizontal, Spacing.s3)
                                        .padding(.vertical, Spacing.s2)
                                        .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(Spacing.cellPadding)
                    BlueprintDivider()
                }

                MealSlotRow(filled: daily.filledMeals)
                    .padding(Spacing.cellPadding)
                BlueprintDivider()

                BlueprintSplit {
                    BlueprintCell(proteinLabel(daily.protein)) {
                        proteinValue(daily.protein)
                    }
                } trailing: {
                    BlueprintCell("daily.cell.strength") {
                        VStack(alignment: .trailing, spacing: Spacing.s1) {
                            DimensionValue(String(daily.week.strengthCount), unit: "unit.times")
                            Text("daily.lightActivity \(daily.week.lightCount)")
                                .font(Typography.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                }
                BlueprintDivider()

                AdaptiveStack(spacing: Spacing.s2) {
                    GhostButton("daily.logProtein") { sheet = .protein(preselected: nil) }
                    GhostButton("daily.logExercise") { sheet = .strength }
                }
                .padding(Spacing.cellPadding)
                BlueprintDivider()

                HStack(spacing: Spacing.s2) {
                    habitToggle("habit.water", isOn: daily.habit?.water ?? false, now: now) { $0.water.toggle() }
                    habitToggle("habit.fiber", isOn: daily.habit?.fiber ?? false, now: now) { $0.fiber.toggle() }
                    habitToggle("habit.sleep", isOn: daily.habit?.sleep ?? false, now: now) { $0.sleep.toggle() }
                }
                .padding(Spacing.cellPadding)
            }
        }
    }

    private func proteinLabel(_ status: ProteinDayStatus) -> LocalizedStringKey {
        if case .noTarget = status { return "daily.cell.proteinApprox" }
        return "daily.cell.protein"
    }

    /// 게이지 바 없이 도면 수치로만. 목표를 채운 날은 "채웠습니다" 한 줄 (R9)
    @ViewBuilder
    private func proteinValue(_ status: ProteinDayStatus) -> some View {
        switch status {
        case let .noTarget(estimated):
            DimensionValue(String(estimated), unit: "unit.g")
        case let .below(estimated, target):
            DimensionValue(String(estimated), unit: "unit.ofTotalGrams \(target)")
        case .met:
            Text("daily.protein.met")
                .font(Typography.label)
                .foregroundStyle(Color.ink)
        }
    }

    /// 수분·식이섬유·수면 가벼운 체크. 점수화 없음 (F14)
    private func habitToggle(_ key: LocalizedStringKey, isOn: Bool, now: Date, change: @escaping (HabitCheck) -> Void) -> some View {
        Button {
            let day = calendar.startOfDay(for: now)
            let check = habits.first { calendar.isDate($0.date, inSameDayAs: day) } ?? {
                let created = HabitCheck(date: day)
                context.insert(created)
                return created
            }()
            change(check)
            try? context.save()
        } label: {
            HStack(spacing: Spacing.s1) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
                // 좁은 화면에서 "식이섬유"가 두 줄로 꺾이지 않게
                Text(key)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .font(Typography.label)
            .foregroundStyle(isOn ? Color.ink : Color.inkSecondary)
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, Spacing.s2)
            .frame(maxWidth: .infinity)
            .background(isOn ? Color.accentSoft : Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(LocalizedStringKey(isOn ? "a11y.on" : "a11y.off")))
    }

    // MARK: HealthKit

    private func syncHealthIfAuthorized() async {
        guard settingsList.first?.healthKitAuthorized == true, services.healthKit.isAvailable else { return }
        try? await HealthSyncService.syncAll(reader: services.healthKit, context: context)
        try? context.save()
    }

    private func connectHealth() async {
        let granted = (try? await services.healthKit.requestReadAuthorization()) ?? false
        if let settings = try? UserSettings.current(in: context) {
            settings.healthKitAuthorized = granted
        }
        if granted {
            try? await HealthSyncService.syncAll(reader: services.healthKit, context: context)
        }
        try? context.save()
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .modelContainer(ModelContainer.previewWithSampleData)
    .preferredColorScheme(.dark)
}
