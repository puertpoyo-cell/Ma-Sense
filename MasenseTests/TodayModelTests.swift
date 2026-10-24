import Foundation
import Testing

@testable import Masense

// S1 오늘 화면 상태 조합. 목요일 20:00, 7일 간격, 2026-10-16(금) 시작
struct TodayModelTests {
    private let calendar = TestCalendar.seoul

    private func prescription(totalDoses: Int = 12, clinic: Date? = nil) -> PrescriptionSnapshot {
        PrescriptionSnapshot(
            startDate: TestCalendar.date(2026, 10, 16, 9),
            scheduledWeekday: 5,
            scheduledHour: 20,
            totalDoses: totalDoses,
            nextClinicDate: clinic
        )
    }

    private func dose(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, site: BodySite = .thighLeft) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, hour, minute)
        return DoseSnapshot(administeredAt: date, scheduledFor: TestCalendar.date(2026, month, day, 20), site: site, sequence: 1)
    }

    private func model(
        _ p: PrescriptionSnapshot?,
        doses: [DoseSnapshot] = [],
        checks: [ConditionCheckSnapshot] = [],
        weights: [WeightSampleSnapshot] = [],
        now: Date
    ) -> TodayModel {
        TodayModel(prescription: p, doses: doses, checks: checks, weights: weights, now: now, calendar: calendar)
    }

    @Test func noPrescription() {
        let today = model(nil, now: TestCalendar.date(2026, 10, 16, 9))
        #expect(today.countdown == .noPrescription)
        #expect(today.remainingDoses == nil)
        #expect(today.pens == nil)
        #expect(today.conditionPrompt == nil)
        #expect(today.clinicDate == nil)
    }

    @Test func daysLeftWhenAtLeast24HoursRemain() {
        let first = TestCalendar.date(2026, 10, 22, 20)
        let early = model(prescription(), now: TestCalendar.date(2026, 10, 16, 9))
        #expect(early.countdown == .daysLeft(scheduled: first, days: 6, canLogEarly: false))
        #expect(early.scheduleDate == first)
        #expect(early.usedDoses == 0)
        // 10-20 20:00부터 첫 마디 구간. 35시간 남음 → D-1, 미리 기록 가능
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 21, 9)).countdown
            == .daysLeft(scheduled: first, days: 1, canLogEarly: true))
    }

    @Test func dDayWithHoursAndMinutesUnder24Hours() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        // 달력으로는 전날이지만 22시간 30분 남음 → D-Day
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 21, 21, 30)).countdown
            == .hoursLeft(scheduled: scheduled, hours: 22, minutes: 30))
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 22, 9)).countdown
            == .hoursLeft(scheduled: scheduled, hours: 11, minutes: 0))
    }

    @Test func overdueCountsDaysPastScheduledDate() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 22, 21)).countdown == .overdue(scheduled: scheduled, daysPast: 0))
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 24, 9)).countdown == .overdue(scheduled: scheduled, daysPast: 2))
    }

    @Test func doneShowsNextCycleAndOpensConditionWindow() {
        let logged = dose(10, 22, 20, 30, site: .abdomenLowerLeft)
        let today = model(prescription(), doses: [logged], now: TestCalendar.date(2026, 10, 23, 9))
        let next = TestCalendar.date(2026, 10, 29, 20)
        #expect(today.countdown == .done(next: next, nextDays: 6))
        #expect(today.scheduleDate == next)
        #expect(today.remainingDoses == 11)
        #expect(today.usedDoses == 1)
        #expect(today.totalDoses == 12)
        #expect(today.conditionPrompt == TodayModel.ConditionPrompt(doseID: logged.id, window: .h24))
    }

    @Test func exhaustedAfterLastCycleEnds() {
        let logged = dose(10, 22, 20)
        let today = model(prescription(totalDoses: 1), doses: [logged], now: TestCalendar.date(2026, 10, 28, 9))
        #expect(today.countdown == .exhausted)
        #expect(today.remainingDoses == 0)
    }

    @Test func clinicCardOnlyWithinSevenDays() {
        let clinic = TestCalendar.date(2026, 10, 28, 10)
        #expect(model(prescription(clinic: clinic), now: TestCalendar.date(2026, 10, 21, 9)).clinicDate == clinic)
        #expect(model(prescription(clinic: clinic), now: TestCalendar.date(2026, 10, 20, 9)).clinicDate == nil)
        #expect(model(prescription(clinic: clinic), now: TestCalendar.date(2026, 10, 29, 9)).clinicDate == nil)
    }

    @Test func weightSeriesAndDoseTicks() {
        let weights = [
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 5, 8), kilograms: 82),
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 20, 8), kilograms: 80.4),
        ]
        let today = model(prescription(), doses: [dose(10, 22, 20)], weights: weights, now: TestCalendar.date(2026, 10, 23, 9))
        #expect(today.latestWeight?.kilograms == 80.4)
        #expect(today.weightSeries.count == TodayModel.weightWeeks)
        #expect(today.doseDatesInSeries == [TestCalendar.date(2026, 10, 22, 20)])
    }

    /// R3-1 (D6): 첫 기록 전에 비어 있는 주만 센다. 남은 회차가 없으면 안내하지 않는다
    @Test func backfillCountsLeadingMissedWeeks() {
        // 10-22, 10-29 마디가 비었고 11-5에 첫 기록. 지금 11-6
        let now = TestCalendar.date(2026, 11, 6, 9)
        #expect(model(prescription(), now: now).backfillCount == 2)
        #expect(model(prescription(), doses: [dose(11, 5, 20)], now: now).backfillCount == 2)
        // 첫 기록(10-22) 뒤의 누락(10-29)은 앱을 쓰기 전이 아니다
        #expect(model(prescription(), doses: [dose(10, 22, 20), dose(11, 5, 20)], now: now).backfillCount == 0)
        #expect(model(prescription(totalDoses: 1), doses: [dose(11, 5, 20)], now: now).backfillCount == 0)
        #expect(model(nil, now: now).backfillCount == 0)
    }

    /// 1-1b 펜 현황 (D7): 펜 3개(12회) 중 첫 펜 1회를 썼고 소진 예상일은 마지막 마디
    @Test func penStatusAndExhaustion() {
        let today = model(prescription(), doses: [dose(10, 22, 20, 5)], now: TestCalendar.date(2026, 10, 23, 9))
        #expect(today.pens?.usedPerPen == [1, 0, 0])
        #expect(today.pens?.remainingPens == 3)
        #expect(today.exhaustionDate == TestCalendar.date(2027, 1, 7, 20))
    }

    /// D8: 맨 위 사실 한 줄(R17)과 지난 마디 정리(R16)
    @Test func dailyLineAndWeeklySummary() {
        // 10-22(목) 09:00 투약일, 기록 전
        let doseDay = model(prescription(), now: TestCalendar.date(2026, 10, 22, 9))
        #expect(doseDay.dailyLine == .doseDay(lastSite: nil))
        #expect(doseDay.weeklySummary == nil)

        // 10-29 09:00: 10-22 ~ 10-28 구간이 끝났고 그 안에 투약 1회
        let after = model(prescription(), doses: [dose(10, 22, 20, 5)], now: TestCalendar.date(2026, 10, 29, 9))
        #expect(after.weeklySummary?.period.start == TestCalendar.date(2026, 10, 22))
        #expect(after.weeklySummary?.doseCount == 1)
        // 기록이 하나도 없는 구간은 카드가 없다
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 30, 9)).weeklySummary == nil)
    }
}
