import SwiftData
import SwiftUI

/// S1 오늘 (홈). 위에서 아래로 Frost 카드 스택: 1-1 카운트다운, 1-2 컨디션, 1-3 체중, 1-4 오늘의 마디, 1-5 진료.
struct TodayView: View {
    var openReport: () -> Void = {}

    private enum Sheet: Identifiable {
        case prescription
        case dose
        case condition(doseID: UUID, window: ConditionWindow)
        case weight
        case protein(preselected: ProteinFood?)
        case strength

        var id: String {
            switch self {
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
    @Query(filter: #Predicate<Prescription> { $0.isActive })
    private var activePrescriptions: [Prescription]
    @Query(sort: \ConditionCheck.checkedAt)
    private var checks: [ConditionCheck]
    @Query(sort: \WeightSample.measuredAt)
    private var weights: [WeightSample]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \ProteinEntry.date) private var proteins: [ProteinEntry]
    @Query(sort: \StrengthSession.startedAt) private var sessions: [StrengthSession]
    @Query(sort: \HabitCheck.date) private var habits: [HabitCheck]
    @State private var sheet: Sheet?
    @State private var showsToast = false
    @ScaledMetric(relativeTo: .largeTitle) private var displaySize: CGFloat = 56

    private var prescription: Prescription? { activePrescriptions.first }

    var body: some View {
        // 카운트다운이 분 단위로 바뀌도록 1분마다 다시 그린다. `now` 주입 지점
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let model = makeModel(now: timeline.date)
            ScrollView {
                VStack(spacing: Spacing.cardGap) {
                    countdownCard(model)
                    // 처방이 없으면 1-1만 보인다 (SCREENS.md 빈 상태)
                    if prescription != nil {
                        if let prompt = model.conditionPrompt {
                            conditionCard(prompt)
                        }
                        weightCard(model)
                        dailyCycleCard(model.daily, now: timeline.date)
                        if let clinic = model.clinicDate {
                            clinicCard(clinic)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
            }
        }
        .midnightBackground()
        .navigationTitle("tab.today")
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
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
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
            now: now,
            calendar: calendar
        )
    }

    // MARK: 1-1 카운트다운

    private func countdownCard(_ model: TodayModel) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                if let remaining = model.remainingDoses, let total = model.totalDoses {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Color.inkSecondary)
                            .accessibilityHidden(true)
                        Spacer()
                        Text("today.remaining \(remaining) \(total)")
                            .font(Typography.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                            .accessibilityLabel(Text("today.remaining.a11y \(remaining) \(total)"))
                    }
                }
                countdownBody(model.countdown)
            }
        }
    }

    @ViewBuilder
    private func countdownBody(_ countdown: TodayModel.Countdown) -> some View {
        switch countdown {
        case .noPrescription:
            Text("today.empty.noPrescription")
                .font(Typography.body)
                .lineSpacing(Typography.bodyLineSpacing)
                .foregroundStyle(Color.ink)
            PrimaryButton("today.enterPrescription") { sheet = .prescription }

        case .exhausted:
            Text("today.countdown.exhausted")
                .font(Typography.title)
                .foregroundStyle(Color.ink)
            PrimaryButton("today.enterPrescription") { sheet = .prescription }

        case let .upcoming(scheduled, daysLeft, canLogEarly):
            Text("today.countdown.dDay \(daysLeft)")
                .font(.system(size: displaySize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Color.ink)
                .accessibilityLabel(Text("today.countdown.dDay.a11y \(daysLeft)"))
            Text("today.countdown.scheduled \(scheduleText(scheduled))")
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            if canLogEarly {
                // 예정일 이틀 전부터는 그 마디로 본다 (R1). 미리 맞은 경우를 기록할 수 있게 한다
                GhostButton("action.logDose") { sheet = .dose }
            }

        case let .today(scheduled):
            Text("today.countdown.today \(scheduled.formatted(date: .omitted, time: .shortened))")
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.ink)
            PrimaryButton("action.logDose") { sheet = .dose }

        case let .overdue(scheduled):
            Text("today.countdown.overdue")
                .font(Typography.title)
                .foregroundStyle(Color.ink)
            Text("today.countdown.scheduled \(scheduleText(scheduled))")
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            PrimaryButton("action.logDose") { sheet = .dose }

        case let .done(site, next):
            Text("today.countdown.done")
                .font(Typography.title)
                .foregroundStyle(Color.ink)
            if let next {
                Text("today.countdown.next \(next.formatted(.dateTime.month(.defaultDigits).day().weekday(.wide)))")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
            if let site {
                Text(site.localizedName)
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private func scheduleText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).hour().minute())
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

    // MARK: 1-3 체중

    private func weightCard(_ model: TodayModel) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack {
                    Text("weight.title")
                        .font(Typography.label)
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    if model.latestWeight != nil {
                        Button("weight.manualEntry") { sheet = .weight }
                            .font(Typography.caption)
                            .foregroundStyle(Color.accent)
                    }
                }
                if let latest = model.latestWeight {
                    AdaptiveStack(verticalAlignment: .lastTextBaseline) {
                        Text("weight.kg \(latest.kilograms.formatted(.number.precision(.fractionLength(1))))")
                            .font(.title.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Text("weight.measuredOn \(latest.measuredAt.formatted(.dateTime.month(.defaultDigits).day()))")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    WeekSparkline(points: model.weightSeries, tickDates: model.doseDatesInSeries)
                        .frame(height: 48)
                    // R8: 빠른 경우에만, 색 강조 없이 한 줄. 출처가 정해진 뒤에만 보인다 (COMPLIANCE.md 2.2)
                    if model.paceNotice != nil, let source = AppConfig.paceGuideSource {
                        NoticeLine("pace.notice")
                        Text(verbatim: source)
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkTertiary)
                    }
                } else {
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

    private func clinicCard(_ date: Date) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("clinic.card \(date.formatted(.dateTime.month(.defaultDigits).day()))")
                    .font(Typography.title)
                    .foregroundStyle(Color.ink)
                GhostButton("clinic.prepareReport", action: openReport)
            }
        }
    }

    // MARK: 시트

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
                    isLowCondition: model.daily.isLowCondition,
                    preselected: food
                )
            ) { showsToast = true }
        case .strength:
            StrengthSheet(isLowCondition: makeModel(now: .now).daily.isLowCondition) { showsToast = true }
        }
    }

    private var recordedProteinToday: Int {
        ProteinRules.entries(on: .now, from: proteins.map(\.snapshot), calendar: calendar).reduce(0) { $0 + $1.estimatedGrams }
    }

    // MARK: 1-4 오늘의 마디 (M2)

    private func dailyCycleCard(_ daily: TodayModel.DailyCycle, now: Date) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("daily.title")
                    .font(Typography.label)
                    .foregroundStyle(Color.inkSecondary)

                if daily.isLowCondition {
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
                }

                MealSlotRow(filled: daily.filledMeals)
                proteinStatus(daily.protein)
                GhostButton("daily.logProtein") { sheet = .protein(preselected: nil) }

                BlueprintDivider()

                Text("daily.week \(daily.week.strengthCount) \(daily.week.lightCount)")
                    .font(Typography.body)
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                GhostButton("daily.logExercise") { sheet = .strength }

                BlueprintDivider()

                HStack(spacing: Spacing.s2) {
                    habitToggle("habit.water", isOn: daily.habit?.water ?? false, now: now) { $0.water.toggle() }
                    habitToggle("habit.fiber", isOn: daily.habit?.fiber ?? false, now: now) { $0.fiber.toggle() }
                    habitToggle("habit.sleep", isOn: daily.habit?.sleep ?? false, now: now) { $0.sleep.toggle() }
                }
            }
        }
    }

    @ViewBuilder
    private func proteinStatus(_ status: ProteinDayStatus) -> some View {
        Group {
            switch status {
            case let .noTarget(estimated):
                Text("daily.protein.approx \(estimated)")
            case let .below(estimated, target):
                Text("daily.protein.progress \(estimated) \(target)")
            case .met:
                // R9: 달성은 "채웠습니다" 한 줄
                Text("daily.protein.met")
            }
        }
        .font(Typography.body)
        .monospacedDigit()
        .foregroundStyle(Color.ink)
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
                Text(key)
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
