import Foundation

/// S1 오늘 화면에 그릴 내용. 규칙(R2·R5·R7·R13)을 조합할 뿐 새로 판단하지 않는다.
struct TodayModel: Equatable {
    enum Countdown: Equatable {
        /// 처방 없음 (빈 상태)
        case noPrescription
        /// 처방 소진. "새 처방을 입력하세요"
        case exhausted
        /// 예정일 전. `canLogEarly`는 이미 그 마디 구간 안이라 미리 맞은 기록을 받을 수 있는지 (R1)
        case upcoming(scheduled: Date, daysLeft: Int, canLogEarly: Bool)
        /// 예정일 당일, 예정 시각 전
        case today(scheduled: Date)
        /// 예정 시각이 지났고 기록 없음. 질책 없이 "예정일이 지났습니다"
        case overdue(scheduled: Date)
        /// 이번 마디 기록 완료
        case done(site: BodySite?, next: Date?)
    }

    struct ConditionPrompt: Equatable {
        let doseID: UUID
        let window: ConditionWindow
    }

    /// 1-4 오늘의 마디 (M2). 사실만, 점수·연속일 없음
    struct DailyCycle: Equatable {
        let filledMeals: Set<MealSlot>
        let protein: ProteinDayStatus
        let week: StrengthWeek
        /// R10·R11 저컨디션 날
        let isLowCondition: Bool
        let habit: HabitCheckSnapshot?
    }

    /// 1-3 체중 카드 스파크라인 주 수
    static let weightWeeks = 8
    /// 1-5 진료 카드는 진료일 7일 이내에만
    static let clinicCardDays = 7

    let countdown: Countdown
    let remainingDoses: Int?
    let totalDoses: Int?
    let conditionPrompt: ConditionPrompt?
    let latestWeight: WeightSampleSnapshot?
    let weightSeries: [WeekPoint]
    /// 스파크라인 투약일 눈금
    let doseDatesInSeries: [Date]
    let clinicDate: Date?
    let daily: DailyCycle
    /// R8. 표시는 출처가 정해졌을 때만 (AppConfig.paceGuideSource)
    let paceNotice: PaceNotice?

    init(
        prescription: PrescriptionSnapshot?,
        doses: [DoseSnapshot],
        checks: [ConditionCheckSnapshot],
        weights: [WeightSampleSnapshot],
        proteins: [ProteinEntrySnapshot] = [],
        sessions: [StrengthSessionSnapshot] = [],
        habits: [HabitCheckSnapshot] = [],
        proteinTarget: Int? = nil,
        now: Date,
        calendar: Calendar
    ) {
        let todayProteins = ProteinRules.entries(on: now, from: proteins, calendar: calendar)
        daily = DailyCycle(
            filledMeals: Set(todayProteins.map(\.meal)),
            protein: ProteinRules.proteinDayStatus(entries: todayProteins, target: proteinTarget),
            week: StrengthRules.strengthWeekSummary(sessions: sessions, weekOf: now, calendar: calendar),
            isLowCondition: ConditionRules.isLowConditionDay(checks: checks, now: now),
            habit: habits.first { calendar.isDate($0.date, inSameDayAs: now) }
        )

        latestWeight = WeightRules.latestSample(weights)
        let series = WeightRules.weeklyWeightSeries(samples: weights, weeks: Self.weightWeeks, now: now, calendar: calendar)
        weightSeries = series
        paceNotice = PaceRules.paceNotice(series: series)
        if let start = series.first?.weekStart {
            doseDatesInSeries = doses
                .filter { !$0.isCancelled && $0.administeredAt >= start && $0.administeredAt <= now }
                .map(\.administeredAt)
                .sorted()
        } else {
            doseDatesInSeries = []
        }

        guard let p = prescription else {
            countdown = .noPrescription
            remainingDoses = nil
            totalDoses = nil
            conditionPrompt = nil
            clinicDate = nil
            return
        }

        remainingDoses = PrescriptionRules.remainingDoses(p: p, doses: doses)
        totalDoses = p.totalDoses
        conditionPrompt = ConditionRules.openConditionWindows(doses: doses, checks: checks, now: now)
            .first
            .map { ConditionPrompt(doseID: $0.dose.id, window: $0.window) }
        clinicDate = Self.clinicDateToShow(p.nextClinicDate, now: now, calendar: calendar)

        let cycles = CycleRules.cycles(for: p, doses: doses, now: now, until: .distantFuture, calendar: calendar)
        switch CycleRules.nextDose(cycles: cycles, doses: doses, now: now) {
        case nil:
            countdown = .exhausted
        case let .due(cycle, _)?:
            let days = Self.daysBetween(now, cycle.scheduledDate, calendar: calendar)
            if days <= 0 {
                countdown = .today(scheduled: cycle.scheduledDate)
            } else {
                countdown = .upcoming(scheduled: cycle.scheduledDate, daysLeft: days, canLogEarly: cycle.contains(now))
            }
        case let .overdue(cycle, _)?:
            countdown = .overdue(scheduled: cycle.scheduledDate)
        case let .done(cycle, next)?:
            let site = CycleRules.doses(in: cycle, from: doses).last?.site
            countdown = .done(site: site, next: next?.scheduledDate)
        }
    }

    static func clinicDateToShow(_ clinic: Date?, now: Date, calendar: Calendar) -> Date? {
        guard let clinic else { return nil }
        let days = daysBetween(now, clinic, calendar: calendar)
        return (0...clinicCardDays).contains(days) ? clinic : nil
    }

    /// 달력 날짜 기준 일수 차이 (시각 무시)
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}
