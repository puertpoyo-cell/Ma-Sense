import Foundation
import Testing

@testable import Masense

// D20 기록 탭 날짜 중심: 주 7일, 날마다 기록 종류 표시
struct HistoryDayRulesTests {
    private let calendar = TestCalendar.seoul

    @Test func weekStartsOnCalendarFirstWeekday() {
        // 2026-10-22(목)이 든 주는 10-18(일)부터
        let week = HistoryDayRules.week(containing: TestCalendar.date(2026, 10, 22, 15), calendar: calendar)
        #expect(week.count == 7)
        #expect(week.first == TestCalendar.date(2026, 10, 18))
        #expect(week.last == TestCalendar.date(2026, 10, 24))
        #expect(HistoryDayRules.shiftWeek(TestCalendar.date(2026, 10, 22), by: -1, calendar: calendar) == TestCalendar.date(2026, 10, 15))
    }

    @Test func marksOnlyThatDayAndSkipCancelledDoses() {
        let day = TestCalendar.date(2026, 10, 22)
        let dose = DoseSnapshot(id: UUID(), administeredAt: TestCalendar.date(2026, 10, 22, 20), scheduledFor: day, site: .thighLeft, sequence: 1, isCancelled: false, note: nil, createdAt: nil)
        let cancelled = DoseSnapshot(id: UUID(), administeredAt: TestCalendar.date(2026, 10, 23, 20), scheduledFor: day, site: .thighLeft, sequence: 2, isCancelled: true, note: nil, createdAt: nil)
        let marks = HistoryDayRules.marks(
            on: day,
            doses: [dose, cancelled],
            checks: [],
            weights: [],
            proteins: [ProteinEntrySnapshot(date: day, meal: .lunch, foods: [.egg], estimatedGrams: 6)],
            sessions: [],
            visits: [TestCalendar.date(2026, 10, 22, 10)],
            calendar: calendar
        )
        #expect(marks == DayMarks(dose: true, protein: true, clinic: true))
        let next = HistoryDayRules.marks(on: TestCalendar.date(2026, 10, 23), doses: [dose, cancelled], checks: [], weights: [], proteins: [], sessions: [], calendar: calendar)
        #expect(next.isEmpty)
    }
}
