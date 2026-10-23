import Foundation
import Testing

@testable import Masense

// D6 투약일 Live Activity (SCREENS.md Live Activity)
struct LiveActivityRulesTests {
    private let calendar = TestCalendar.seoul
    private let scheduled = TestCalendar.date(2026, 10, 22, 20)

    @Test func showsOnlyOnTheScheduledDayUntilLogged() {
        let upcoming = WidgetSnapshot(phase: .upcoming, scheduledDate: scheduled, updatedAt: scheduled)
        #expect(LiveActivityRules.doseDayScheduledDate(snapshot: upcoming, now: TestCalendar.date(2026, 10, 22, 8), calendar: calendar) == scheduled)
        // 예정 시각이 지나도 그날 안에는 남는다
        #expect(LiveActivityRules.doseDayScheduledDate(snapshot: upcoming, now: TestCalendar.date(2026, 10, 22, 23, 30), calendar: calendar) == scheduled)
        #expect(LiveActivityRules.doseDayScheduledDate(snapshot: upcoming, now: TestCalendar.date(2026, 10, 21, 20), calendar: calendar) == nil)
        #expect(LiveActivityRules.doseDayScheduledDate(snapshot: upcoming, now: TestCalendar.date(2026, 10, 23, 9), calendar: calendar) == nil)

        // 기록하면(done) 다음 예정이 오늘이 아니므로 끝난다
        let done = WidgetSnapshot(phase: .done, scheduledDate: TestCalendar.date(2026, 10, 29, 20), updatedAt: scheduled)
        #expect(LiveActivityRules.doseDayScheduledDate(snapshot: done, now: TestCalendar.date(2026, 10, 22, 21), calendar: calendar) == nil)
        #expect(LiveActivityRules.doseDayScheduledDate(snapshot: WidgetSnapshot(phase: .noPrescription, updatedAt: scheduled), now: scheduled, calendar: calendar) == nil)
    }

    @Test func redrawsAtScheduledTimeThenStaleAtTheEndOfTheDay() {
        #expect(LiveActivityRules.staleDate(for: scheduled, now: TestCalendar.date(2026, 10, 22, 9), calendar: calendar) == scheduled)
        #expect(LiveActivityRules.staleDate(for: scheduled, now: TestCalendar.date(2026, 10, 22, 21), calendar: calendar) == TestCalendar.date(2026, 10, 23))
    }
}
