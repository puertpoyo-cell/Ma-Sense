import Foundation
import Testing

@testable import Masense

// RULES.md R4-1 알림 액션 (D6)
struct NotificationActionsTests {
    @Test func doseAndConditionNotificationsHaveActions() {
        #expect(NotificationActions.category(for: .doseDue) == NotificationActions.doseCategory)
        #expect(NotificationActions.category(for: .doseEvening) == NotificationActions.doseCategory)
        #expect(NotificationActions.category(for: .conditionH24) == NotificationActions.conditionCategory)
        #expect(NotificationActions.category(for: .conditionH48) == NotificationActions.conditionCategory)
        #expect(NotificationActions.category(for: .weightDue) == NotificationActions.weightCategory)
        #expect(NotificationActions.category(for: .clinicSoon) == nil)
        #expect(NotificationActions.category(for: .prescriptionLow) == nil)
    }

    @Test func responsesOpenTheRightPlaceOrSnooze() {
        let dose = NotificationActions.doseCategory
        let condition = NotificationActions.conditionCategory
        #expect(NotificationActions.response(action: NotificationActions.logDose, category: dose) == .open(.logDose))
        #expect(NotificationActions.response(action: NotificationActions.defaultAction, category: dose) == .open(.logDose))
        #expect(NotificationActions.response(action: NotificationActions.snooze, category: dose) == .snooze)
        #expect(NotificationActions.response(action: NotificationActions.logCondition, category: condition) == .open(.conditionCheck))
        #expect(NotificationActions.response(action: NotificationActions.defaultAction, category: condition) == .open(.conditionCheck))
        let weight = NotificationActions.weightCategory
        #expect(NotificationActions.response(action: NotificationActions.logWeight, category: weight) == .open(.logWeight))
        #expect(NotificationActions.response(action: NotificationActions.defaultAction, category: weight) == .open(.logWeight))
        #expect(AppRouter.route(for: URL(string: "masense://log-weight")!) == .logWeight)
        // 카테고리가 없는 알림(진료·소진)은 앱만 연다
        #expect(NotificationActions.response(action: NotificationActions.defaultAction, category: "") == nil)
        #expect(NotificationActions.response(action: NotificationActions.snooze, category: condition) == nil)
    }

    @Test func snoozeFiresOnceAnHourLaterWithSameWording() {
        let now = TestCalendar.date(2026, 10, 22, 20, 5)
        let snoozed = NotificationActions.snoozed(kind: .doseEvening, now: now)
        #expect(snoozed == PlannedNotification(
            id: NotificationActions.snoozeIdentifier,
            kind: .doseEvening,
            fireDate: TestCalendar.date(2026, 10, 22, 21, 5)
        ))
    }
}
