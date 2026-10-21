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
        #expect(today.conditionPrompt == nil)
        #expect(today.clinicDate == nil)
    }

    @Test func upcomingCountsCalendarDaysAndAllowsEarlyLogInsideCycle() {
        let first = TestCalendar.date(2026, 10, 22, 20)
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 16, 9)).countdown
            == .upcoming(scheduled: first, daysLeft: 6, canLogEarly: false))
        // 10-20 20:00부터 첫 마디 구간
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 21, 9)).countdown
            == .upcoming(scheduled: first, daysLeft: 1, canLogEarly: true))
    }

    @Test func todayThenOverdue() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 22, 9)).countdown == .today(scheduled: scheduled))
        #expect(model(prescription(), now: TestCalendar.date(2026, 10, 22, 21)).countdown == .overdue(scheduled: scheduled))
    }

    @Test func doneShowsSiteNextDateAndOpensConditionWindow() {
        let logged = dose(10, 22, 20, 30, site: .abdomenLowerLeft)
        let today = model(prescription(), doses: [logged], now: TestCalendar.date(2026, 10, 23, 9))
        #expect(today.countdown == .done(site: .abdomenLowerLeft, next: TestCalendar.date(2026, 10, 29, 20)))
        #expect(today.remainingDoses == 11)
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
}
