import Foundation
import Testing

@testable import Masense

// D25 투약 시각 30분 단위
struct DoseTimeRulesTests {
    private let calendar = TestCalendar.seoul

    private func time(_ hour: Int, _ minute: Int, second: Int = 0, day: Int = 31) -> Date {
        var parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second)
        parts.timeZone = calendar.timeZone
        return calendar.date(from: parts)!
    }

    @Test func roundsDownToHalfHour() {
        #expect(DoseTimeRules.roundedDown(time(20, 47, second: 59), calendar: calendar) == time(20, 30))
        #expect(DoseTimeRules.roundedDown(time(20, 29), calendar: calendar) == time(20, 0))
        #expect(DoseTimeRules.roundedDown(time(21, 0), calendar: calendar) == time(21, 0))
        #expect(DoseTimeRules.roundedDown(time(0, 10), calendar: calendar) == time(0, 0))
    }

    @Test func initialTimeIsLatestHalfHourOrMissedDate() {
        let now = time(20, 47)
        #expect(DoseTimeRules.initialTime(initialDate: nil, now: now, calendar: calendar) == time(20, 30))
        // 누락 마디: 그 예정일 시각 (내림)
        #expect(DoseTimeRules.initialTime(initialDate: time(20, 15, day: 24), now: now, calendar: calendar) == time(20, 0, day: 24))
        // 미래는 지금의 내림으로
        #expect(DoseTimeRules.initialTime(initialDate: time(21, 30), now: now, calendar: calendar) == time(20, 30))
    }

    @Test func shiftMovesByHalfHourButNotIntoFuture() {
        let now = time(20, 47)
        #expect(DoseTimeRules.shifted(time(20, 30), steps: -1, latest: now, calendar: calendar) == time(20, 0))
        #expect(DoseTimeRules.shifted(time(20, 0), steps: 1, latest: now, calendar: calendar) == time(20, 30))
        #expect(DoseTimeRules.shifted(time(20, 30), steps: 1, latest: now, calendar: calendar) == time(20, 30))
        // 자정을 넘어 전날로
        #expect(DoseTimeRules.shifted(time(0, 0), steps: -1, latest: now, calendar: calendar) == time(23, 30, day: 30))
    }
}
