import Foundation

/// S1 오늘 화면에 그릴 내용. 규칙(R2·R5·R7·R13)을 조합할 뿐 새로 판단하지 않는다.
struct TodayModel: Equatable {
    /// 하이브리드 카운트다운 (DESIGN_SYSTEM.md 5.2). 남은 시간 24시간을 기준으로 D-n과 D-Day + 시간·분을 나눈다
    enum Countdown: Equatable {
        /// 처방 없음 (빈 상태)
        case noPrescription
        /// 처방 소진. "새 처방을 입력하세요"
        case exhausted
        /// 24시간 이상 남음. `days`는 달력 날짜 차이 (D-n).
        /// `canLogEarly`는 이미 그 마디 구간 안이라 미리 맞은 기록을 받을 수 있는지 (R1)
        case daysLeft(scheduled: Date, days: Int, canLogEarly: Bool)
        /// 24시간 미만 남음. D-Day + n시간 n분
        case hoursLeft(scheduled: Date, hours: Int, minutes: Int)
        /// 예정 시각이 지났고 기록 없음 (D+n). 예정일 당일이면 `daysPast` 0 (D-Day). 질책 없이 "예정일이 지났습니다"
        case overdue(scheduled: Date, daysPast: Int)
        /// 이번 마디 기록 완료. 다음 마디 예정과 D-n
        case done(next: Date?, nextDays: Int?)
    }

    static let hoursLeftThreshold: TimeInterval = 24 * 3_600

    struct ConditionPrompt: Equatable {
        let doseID: UUID
        let window: ConditionWindow
    }

    /// 1-4 오늘의 마디 (M2). 사실만, 점수·연속일 없음
    struct DailyCycle: Equatable {
        let filledMeals: Set<MealSlot>
        let protein: ProteinDayStatus
        let week: StrengthWeek
        /// R10 식욕 저하일: "작게 자주"
        let isLowAppetite: Bool
        /// R11 저컨디션 날: 운동 기록에서 걷기·스트레칭·쉬기를 위로
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
    /// 우측 셀 "회차": 취소 제외 기록 수
    let usedDoses: Int?
    /// 우측 셀 "예정 시간": 지금 마디의 예정 (완료면 다음 마디)
    let scheduleDate: Date?
    let conditionPrompt: ConditionPrompt?
    let latestWeight: WeightSampleSnapshot?
    /// R14. 최근 체중과 설정의 키로 계산한 BMI 숫자. 키가 없으면 nil
    let latestBMI: Double?
    let weightSeries: [WeekPoint]
    /// 스파크라인 투약일 눈금
    let doseDatesInSeries: [Date]
    let clinicDate: Date?
    let daily: DailyCycle
    /// R8. 표시는 출처가 정해졌을 때만 (AppConfig.paceGuideSource)
    let paceNotice: PaceNotice?
    /// 맨 위 사실 한 줄 (R17, D8)
    let dailyLine: DailyLine?
    /// 1-1c 지난 마디 정리 (R16, D8). 끝난 구간 중 가장 최근, 기록이 하나도 없으면 nil
    let weeklySummary: WeeklySummary?
    /// 1-1c 패키지 정리 (R18, D9). 4회를 다 쓴 패키지 기간이 끝난 뒤 7일 동안. 보이면 주간 정리 대신
    let packageSummary: PackageSummary?
    /// 1-1b 펜 현황 (R13-1, D7)과 소진 예상일 (R13)
    let pens: PenStatus?
    let exhaustionDate: Date?
    /// R3-1 (D6). 처방의 첫 기록보다 앞선 누락 마디 수 = 이 앱을 쓰기 전에 맞았을 수 있는 주. 남은 회차가 없으면 0
    let backfillCount: Int

    init(
        prescription: PrescriptionSnapshot?,
        doses: [DoseSnapshot],
        checks: [ConditionCheckSnapshot],
        weights: [WeightSampleSnapshot],
        proteins: [ProteinEntrySnapshot] = [],
        sessions: [StrengthSessionSnapshot] = [],
        habits: [HabitCheckSnapshot] = [],
        proteinTarget: Int? = nil,
        heightCm: Double? = nil,
        allDoses: [DoseSnapshot]? = nil,
        now: Date,
        calendar: Calendar
    ) {
        // 부위·체중은 처방과 무관하게 본다 (모든 처방의 기록)
        dailyLine = DailyLineRules.line(
            prescription: prescription,
            doses: doses,
            allDoses: allDoses ?? doses,
            weights: weights,
            now: now,
            calendar: calendar
        )
        weeklySummary = prescription
            .flatMap { WeeklySummaryRules.finishedPeriods(prescription: $0, now: now, calendar: calendar, limit: 1).first }
            .map { period in
                WeeklySummaryRules.summary(
                    period: period,
                    doses: allDoses ?? doses,
                    checks: checks,
                    weights: weights,
                    proteins: proteins,
                    sessions: sessions,
                    proteinTarget: proteinTarget,
                    calendar: calendar
                )
            }
            .flatMap { $0.isEmpty ? nil : $0 }
        // 처방의 기록만으로 패키지를 센다
        packageSummary = PackageSummaryRules.recentlyFinished(doses: doses, now: now, calendar: calendar).map { package in
            PackageSummaryRules.summary(
                package: package,
                doses: doses,
                checks: checks,
                weights: weights,
                proteins: proteins,
                sessions: sessions,
                proteinTarget: proteinTarget,
                calendar: calendar
            )
        }

        let todayProteins = ProteinRules.entries(on: now, from: proteins, calendar: calendar)
        daily = DailyCycle(
            filledMeals: Set(todayProteins.map(\.meal)),
            protein: ProteinRules.proteinDayStatus(entries: todayProteins, target: proteinTarget),
            week: StrengthRules.strengthWeekSummary(sessions: sessions, weekOf: now, calendar: calendar),
            isLowAppetite: ConditionRules.isLowAppetiteDay(checks: checks, now: now),
            isLowCondition: ConditionRules.isLowConditionDay(checks: checks, now: now),
            habit: habits.first { calendar.isDate($0.date, inSameDayAs: now) }
        )

        latestWeight = WeightRules.latestSample(weights)
        latestBMI = latestWeight.flatMap { WeightRules.bmi(kilograms: $0.kilograms, heightCm: heightCm) }
        let series = WeightRules.weeklyWeightSeries(samples: weights, weeks: Self.weightWeeks, now: now, calendar: calendar)
        weightSeries = series
        paceNotice = PaceRules.paceNotice(series: series)
        doseDatesInSeries = WeightRules.doseTicks(doses: doses, series: series, now: now)

        guard let p = prescription else {
            countdown = .noPrescription
            remainingDoses = nil
            totalDoses = nil
            usedDoses = nil
            scheduleDate = nil
            conditionPrompt = nil
            clinicDate = nil
            backfillCount = 0
            pens = nil
            exhaustionDate = nil
            return
        }

        let remaining = PrescriptionRules.remainingDoses(p: p, doses: doses)
        remainingDoses = remaining
        totalDoses = p.totalDoses
        pens = PrescriptionRules.penStatus(p: p, doses: doses)
        exhaustionDate = PrescriptionRules.exhaustionEstimate(p: p, doses: doses, now: now, calendar: calendar)
        backfillCount = remaining > 0
            ? BackfillRules.leadingCount(candidates: BackfillRules.candidates(prescription: p, doses: doses, now: now, calendar: calendar), doses: doses)
            : 0
        usedDoses = PrescriptionRules.usedDoses(doses)
        conditionPrompt = ConditionRules.openConditionWindows(doses: doses, checks: checks, now: now)
            .first
            .map { ConditionPrompt(doseID: $0.dose.id, window: $0.window) }
        clinicDate = Self.clinicDateToShow(p.nextClinicDate, now: now, calendar: calendar)

        let cycles = CycleRules.cycles(for: p, doses: doses, now: now, until: .distantFuture, calendar: calendar)
        switch CycleRules.nextDose(cycles: cycles, doses: doses, now: now) {
        case nil:
            countdown = .exhausted
            scheduleDate = nil
        case let .due(cycle, remaining)?:
            scheduleDate = cycle.scheduledDate
            if remaining >= Self.hoursLeftThreshold {
                let days = max(1, Self.daysBetween(now, cycle.scheduledDate, calendar: calendar))
                countdown = .daysLeft(scheduled: cycle.scheduledDate, days: days, canLogEarly: cycle.contains(now))
            } else {
                let totalMinutes = Int(remaining / 60)
                countdown = .hoursLeft(scheduled: cycle.scheduledDate, hours: totalMinutes / 60, minutes: totalMinutes % 60)
            }
        case let .overdue(cycle, _)?:
            scheduleDate = cycle.scheduledDate
            countdown = .overdue(scheduled: cycle.scheduledDate, daysPast: max(0, Self.daysBetween(cycle.scheduledDate, now, calendar: calendar)))
        case let .done(_, next)?:
            scheduleDate = next?.scheduledDate
            countdown = .done(
                next: next?.scheduledDate,
                nextDays: next.map { Self.daysBetween(now, $0.scheduledDate, calendar: calendar) }
            )
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
