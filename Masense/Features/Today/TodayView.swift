import SwiftData
import SwiftUI

/// S1 오늘 (홈, D20 재구성). 위에서 아래로: 1-1 카운트다운 + 한눈에, 1-1a 지난 투약 안내, 1-2 컨디션, 1-8 빠른 기록 줄,
/// 1-4 오늘의 마디, 1-1c 정리 한 줄, 1-5 진료 한 줄, 1-6 알아 두기. 펜 그림·체중 추이·정리 목록은 기록 탭 "모아 보기", 맨몸 근력 예시는 운동 기록 시트로 옮겼다
struct TodayView: View {
    var openReport: () -> Void = {}
    /// D20 진료 탭으로
    var openClinic: () -> Void = {}

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
        case foodPhoto

        var id: String {
            switch self {
            case .foodPhoto: return "foodPhoto"
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
    @Environment(\.coach) private var coach
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
    /// 닫은 주간 정리 구간 시작 (D8). 기기 화면 상태
    @AppStorage("weeklySummary.dismissedStart") private var dismissedWeeklyStart: Double = 0
    /// 닫은 패키지 정리 구간 시작 (D9)
    @AppStorage("packageSummary.dismissedStart") private var dismissedPackageStart: Double = 0
    @State private var weeklyListDestination: WeeklySummaryListView.Segment?
    /// 건강 앱의 성별 (D13). 바디맵 그림을 고르는 데만 쓴다
    @AppStorage("health.bodyFigure") private var healthFigureRaw = ""
    /// 설정의 바디맵 그림 (D13). 한눈에 카드 그림도 같은 것을 쓴다
    @AppStorage("bodyMap.figure") private var bodyFigureRaw = BodyFigurePreference.automatic.rawValue
    /// 진료 카드의 "진료 준비" (D9)
    @State private var infoDestination: InfoTopic?
    /// 마선생 팝업 자리 판단용 스크롤 화면 영역 (D18)
    @State private var viewport: CGRect = .zero

    private var prescription: Prescription? { activePrescriptions.first }

    var body: some View {
        // 카운트다운이 분 단위로 바뀌도록 1분마다 다시 그린다. `now` 주입 지점
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let model = makeModel(now: timeline.date)
            ScrollView {
                VStack(spacing: Spacing.cardGap) {
                    // D18: 마선생 한마디는 카드 자리에 닿을 때 팝업으로
                    countdownCard(model)
                        .coachSpot(.todayTop, viewport: viewport, context: model.coachContext)
                    // 처방이 없으면 1-1만 보인다 (SCREENS.md 빈 상태)
                    if let prescription {
                        if model.backfillCount > 0, dismissedBackfill != prescription.id.uuidString {
                            backfillCard(count: model.backfillCount, prescriptionID: prescription.id)
                        }
                        if let prompt = model.conditionPrompt {
                            conditionCard(prompt)
                        }
                        // D20: 기록 버튼을 한 줄로 위에 모은다
                        quickRecordRow(model, now: timeline.date)
                            .coachSpot(.weight, viewport: viewport, context: model.coachContext)
                        dailyCycleCard(model.daily, now: timeline.date)
                            .coachSpot(.daily, viewport: viewport, context: model.coachContext)
                        // D20: 정리·진료는 한 줄 안내로 줄이고 자세한 것은 기록·진료 탭에서
                        summaryRow(model, prescription: prescription)
                        if let clinic = model.clinicDate {
                            clinicRow(clinic, now: timeline.date)
                                .coachSpot(.pens, viewport: viewport, context: model.coachContext)
                        }
                    }
                    infoRow
                        .coachSpot(.info, viewport: viewport, context: model.coachContext)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
                // 팝업이 마지막 카드를 가리지 않게 아래 여유
                .padding(.bottom, Spacing.s6)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { viewport = $0 }
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
            // D18 마선생에게 말 걸기
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    coach.talk(context: makeModel(now: .now).coachContext)
                } label: {
                    CoachFace(size: 30)
                }
                .accessibilityLabel(Text("coach.talk.button"))
            }
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

    // MARK: 1-1 카운트다운 (CountdownHero, DESIGN_SYSTEM.md 5.2)

    private func countdownCard(_ model: TodayModel) -> some View {
        CountdownHero(
            countdown: model.countdown,
            scheduleDate: model.scheduleDate,
            usedDoses: model.usedDoses,
            totalDoses: model.totalDoses,
            onLogDose: { sheet = .dose },
            onEnterPrescription: { sheet = .prescription },
            // D15: 체중·남은 펜·지난 부위를 카운트다운 카드 안에서 한눈에
            glance: prescription == nil ? nil : AnyView(
                GlanceStrip(
                    figure: BodyFigureRules.figure(
                        preference: BodyFigurePreference(rawValue: bodyFigureRaw) ?? .automatic,
                        healthFigure: BodyFigure(rawValue: healthFigureRaw)
                    ),
                    latestWeight: model.latestWeight,
                    latestBodyFat: model.latestBodyFat,
                    pens: model.pens,
                    usedDoses: model.usedDoses,
                    totalDoses: model.totalDoses,
                    exhaustionDate: model.exhaustionDate,
                    lastSite: model.lastSite,
                    onOpenWeight: { sheet = .weightTrend }
                )
            )
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

    // MARK: 빠른 기록 (D20)

    /// 단백질·사진·운동·체중·물을 한 줄로. 물은 누르면 오늘 습관 체크가 바뀐다
    private func quickRecordRow(_ model: TodayModel, now: Date) -> some View {
        let water = model.daily.habit?.water ?? false
        return HStack(spacing: Spacing.s2) {
            quickButton("today.quick.protein", systemImage: "fork.knife") { sheet = .protein(preselected: nil) }
            quickButton("today.quick.photo", systemImage: "camera") { sheet = .foodPhoto }
            quickButton("today.quick.exercise", systemImage: "figure.walk") { sheet = .strength }
            quickButton("today.quick.weight", systemImage: "chart.xyaxis.line") { sheet = .weight }
            quickButton("habit.water", systemImage: water ? "drop.fill" : "drop", isOn: water) {
                toggleHabit(now: now) { $0.water.toggle() }
            }
        }
    }

    private func quickButton(_ key: LocalizedStringKey, systemImage: String, isOn: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.s1) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .frame(height: 22)
                Text(key)
                    .font(Typography.caption)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isOn ? Color.accentSoft : Color.frost, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(isOn ? Color.accent : Color.frostBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: 정리·진료 한 줄 (D20)

    /// 끝난 주·패키지 정리가 있으면 한 줄. 누르면 정리 목록, ×는 그 구간을 닫는다
    @ViewBuilder
    private func summaryRow(_ model: TodayModel, prescription: Prescription) -> some View {
        if let package = model.packageSummary, package.package.period.start.timeIntervalSinceReferenceDate != dismissedPackageStart {
            noticeRow("today.summary.package", systemImage: "shippingbox", open: { weeklyListDestination = .packages }) {
                dismissedPackageStart = package.package.period.start.timeIntervalSinceReferenceDate
                if let weekly = model.weeklySummary {
                    dismissedWeeklyStart = weekly.period.start.timeIntervalSinceReferenceDate
                }
            }
        } else if let summary = model.weeklySummary, summary.period.start.timeIntervalSinceReferenceDate != dismissedWeeklyStart {
            noticeRow("today.summary.weekly", systemImage: "list.bullet.rectangle", open: { weeklyListDestination = .weeks }) {
                dismissedWeeklyStart = summary.period.start.timeIntervalSinceReferenceDate
            }
        }
    }

    /// 진료 7일 이내. 진료 탭에서 물어볼 것·리포트를 준비한다
    private func clinicRow(_ date: Date, now: Date) -> some View {
        let days = TodayModel.daysBetween(now, date, calendar: calendar)
        let dateText = date.formatted(.dateTime.month(.defaultDigits).day())
        return noticeRow(
            days == 0 ? LocalizedStringKey("today.clinic.today \(pendingQuestions.count)") : LocalizedStringKey("today.clinic.days \(dateText) \(days) \(pendingQuestions.count)"),
            systemImage: "list.clipboard",
            open: openClinic,
            dismiss: nil
        )
    }

    private func noticeRow(_ key: LocalizedStringKey, systemImage: String, open: @escaping () -> Void, dismiss: (() -> Void)?) -> some View {
        HStack(spacing: Spacing.s3) {
            Button(action: open) {
                HStack(spacing: Spacing.s3) {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.accent)
                        .accessibilityHidden(true)
                    Text(key)
                        .font(Typography.label)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkTertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let dismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(minWidth: 28, minHeight: 28)
                }
                .accessibilityLabel(Text("today.routine.dismiss"))
            }
        }
        .padding(Spacing.cellPadding)
        .background(Color.frost, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
        case .doseSheet?, .doseSheetFemale?: sheet = .dose
        case .proteinSheet?: sheet = .protein(preselected: nil)
        case .strengthSheet?: sheet = .strength
        case .backfillSheet?: sheet = .backfill
        case .questionsSheet?: sheet = .questions
        case .weightTrendSheet?: sheet = .weightTrend
        case .summaryPackages?: weeklyListDestination = .packages
        case .infoProtein?: infoDestination = .proteinFoods
        case .infoClinicPrep?: infoDestination = .clinicPrep
        case .coachTalk?: coach.talk(context: makeModel(now: .now).coachContext)
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
                DoseLogSheet(prescription: prescription) { recorded(.dose) }
            }
        case let .condition(doseID, window):
            if let dose = prescription?.doses.first(where: { $0.id == doseID }) {
                ConditionCheckSheet(dose: dose, window: window) { recorded(.condition) }
            }
        case .weight:
            WeightEntrySheet { recorded(.weight) }
        case let .protein(food):
            let model = makeModel(now: .now)
            ProteinSheet(
                model: ProteinLogModel(
                    target: settingsList.first?.proteinTargetGrams,
                    recordedToday: recordedProteinToday,
                    isLowAppetite: model.daily.isLowAppetite,
                    preselected: food
                )
            , onSaved: { recorded(.protein) }, onPhotoSaved: { grams in
                showsToast = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.6))
                    coach.react(with: .proteinEstimate(grams))
                }
            })
        case .strength:
            StrengthSheet(isLowCondition: makeModel(now: .now).daily.isLowCondition) { recorded(.exercise) }
        case .backfill:
            if let prescription {
                BackfillSheet(prescription: prescription) { recorded(.dose) }
            }
        case .questions:
            ClinicQuestionsSheet()
        case .weightTrend:
            WeightTrendSheet()
        case .foodPhoto:
            FoodPhotoSheet(meal: ProteinLogModel.defaultMeal(at: .now, calendar: calendar)) { grams in
                showsToast = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.6))
                    coach.react(with: .proteinEstimate(grams))
                }
            }
        }
    }

    /// 기록을 마치면 "기록했습니다" 알림과 함께, 시트가 내려간 뒤 마선생이 한마디 (D19)
    private func recorded(_ kind: CoachRecordKind) {
        showsToast = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            coach.react(to: kind)
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

    /// 오늘 습관 체크를 찾거나 만들어 바꾼다
    private func toggleHabit(now: Date, change: (HabitCheck) -> Void) {
        let day = calendar.startOfDay(for: now)
        let check = habits.first { calendar.isDate($0.date, inSameDayAs: day) } ?? {
            let created = HabitCheck(date: day)
            context.insert(created)
            return created
        }()
        change(check)
        try? context.save()
    }

    /// 수분·식이섬유·수면 가벼운 체크. 점수화 없음 (F14)
    private func habitToggle(_ key: LocalizedStringKey, isOn: Bool, now: Date, change: @escaping (HabitCheck) -> Void) -> some View {
        Button {
            toggleHabit(now: now, change: change)
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
        // D11: 나중에 더한 읽기 종류(체지방률)는 아직 묻지 않았을 때만 시스템 시트가 한 번 뜬다. 이미 답했으면 바로 끝난다
        _ = try? await services.healthKit.requestReadAuthorization()
        healthFigureRaw = services.healthKit.bodyFigure()?.rawValue ?? ""
        try? await HealthSyncService.syncAll(reader: services.healthKit, context: context)
        try? context.save()
    }

    private func connectHealth() async {
        let granted = (try? await services.healthKit.requestReadAuthorization()) ?? false
        if let settings = try? UserSettings.current(in: context) {
            settings.healthKitAuthorized = granted
        }
        if granted {
            healthFigureRaw = services.healthKit.bodyFigure()?.rawValue ?? ""
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
