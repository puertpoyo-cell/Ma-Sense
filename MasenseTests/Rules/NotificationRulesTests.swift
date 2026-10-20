import Foundation
import Testing

@testable import Masense

// RULES.md R4
struct NotificationRulesTests {
    private let calendar = TestCalendar.seoul
    private let now = TestCalendar.date(2026, 10, 16, 9)

    /// 목요일, 12회차, 다음 진료 11-10
    private func prescription(hour: Int = 20, totalDoses: Int = 12, clinic: Date? = TestCalendar.date(2026, 11, 10, 10)) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: hour, totalDoses: totalDoses, nextClinicDate: clinic)
    }

    private func dose(_ month: Int, _ day: Int, hour: Int = 20) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, hour)
        return DoseSnapshot(administeredAt: date, scheduledFor: date, site: .abdomenUpperLeft, sequence: 1)
    }

    private func makePlan(
        p: PrescriptionSnapshot? = nil,
        settings: SettingsSnapshot = SettingsSnapshot(),
        doses: [DoseSnapshot] = [],
        checks: [ConditionCheckSnapshot] = [],
        now: Date? = nil
    ) -> [PlannedNotification] {
        NotificationRules.notificationPlan(p: p ?? prescription(), settings: settings, doses: doses, checks: checks, now: now ?? self.now, calendar: calendar)
    }

    @Test func fourWeekHorizonAndSortedUniqueIDs() {
        let plan = makePlan()
        let due = plan.filter { $0.kind == .doseDue }
        // 10-22, 10-29, 11-05, 11-12 까지. 11-19는 4주 밖
        #expect(due.map(\.fireDate) == [
            TestCalendar.date(2026, 10, 22, 20),
            TestCalendar.date(2026, 10, 29, 20),
            TestCalendar.date(2026, 11, 5, 20),
            TestCalendar.date(2026, 11, 12, 20),
        ])
        #expect(plan.filter { $0.kind == .doseEvening }.isEmpty) // 예정 20:00 = 저녁 20:00 → 리마인드 없음
        #expect(plan.filter { $0.kind == .clinicSoon }.map(\.fireDate) == [TestCalendar.date(2026, 11, 9, 9)])
        #expect(plan.filter { $0.kind == .prescriptionLow }.isEmpty)
        #expect(Set(plan.map(\.id)).count == plan.count)
        #expect(plan.map(\.fireDate) == plan.map(\.fireDate).sorted())
    }

    @Test func eveningReminderOnlyWhenScheduledBeforeEveningHour() {
        let plan = makePlan(p: prescription(hour: 9))
        let evenings = plan.filter { $0.kind == .doseEvening }
        #expect(evenings.count == 4)
        #expect(evenings.first?.fireDate == TestCalendar.date(2026, 10, 22, 20))
    }

    @Test func loggedDoseRemovesCycleRemindersAndAddsConditionChecks() {
        let logged = dose(10, 22)
        let now = TestCalendar.date(2026, 10, 22, 21)
        let plan = makePlan(p: prescription(hour: 9), doses: [logged], now: now)

        #expect(!plan.contains { $0.id == "dose.due.0" })
        #expect(!plan.contains { $0.id == "dose.evening.0" })
        #expect(plan.contains { $0.id == "dose.due.1" })
        #expect(plan.filter { $0.kind == .conditionH24 }.map(\.fireDate) == [TestCalendar.date(2026, 10, 23, 20)])
        #expect(plan.filter { $0.kind == .conditionH48 }.map(\.fireDate) == [TestCalendar.date(2026, 10, 24, 20)])
    }

    @Test func answeredConditionWindowIsNotScheduled() {
        let logged = dose(10, 22)
        let h24 = ConditionCheckSnapshot(doseID: logged.id, window: .h24, checkedAt: TestCalendar.date(2026, 10, 23, 12))
        let plan = makePlan(doses: [logged], checks: [h24], now: TestCalendar.date(2026, 10, 23, 13))
        #expect(plan.filter { $0.kind == .conditionH24 }.isEmpty)
        #expect(plan.filter { $0.kind == .conditionH48 }.count == 1)
    }

    @Test func lowPrescriptionNoticeRidesWithNextDoseOnce() {
        let plan = makePlan(p: prescription(totalDoses: 2))
        let low = plan.filter { $0.kind == .prescriptionLow }
        #expect(low.count == 1)
        #expect(low.first?.fireDate == TestCalendar.date(2026, 10, 22, 20))
        #expect(low.first?.argument == 2)
    }

    @Test func settingsToggles() {
        let noReminder = makePlan(settings: SettingsSnapshot(reminderEnabled: false), doses: [dose(10, 22)], now: TestCalendar.date(2026, 10, 22, 21))
        #expect(noReminder.allSatisfy { $0.kind == .conditionH24 || $0.kind == .conditionH48 || $0.kind == .clinicSoon })

        let noCondition = makePlan(settings: SettingsSnapshot(conditionCheckEnabled: false), doses: [dose(10, 22)], now: TestCalendar.date(2026, 10, 22, 21))
        #expect(!noCondition.contains { $0.kind == .conditionH24 || $0.kind == .conditionH48 })

        let noClinic = makePlan(p: prescription(clinic: nil))
        #expect(!noClinic.contains { $0.kind == .clinicSoon })
    }

    @Test func pastFireDatesAreSkipped() {
        let plan = makePlan(now: TestCalendar.date(2026, 10, 22, 20, 1))
        #expect(!plan.contains { $0.id == "dose.due.0" })
        #expect(plan.contains { $0.id == "dose.due.1" })
    }
}
