import Foundation
import Testing

@testable import Masense

// R20 마선생 한마디 (D12). 달력은 일요일 시작. 2026-10-22는 목요일
struct CoachRulesTests {
    private let calendar = TestCalendar.seoul

    private func line(
        dailyLine: DailyLine? = nil,
        lowCondition: Bool = false,
        lowAppetite: Bool = false,
        protein: Int = 1,
        strength: Int = 1,
        now: Date
    ) -> CoachLine {
        CoachRules.line(
            dailyLine: dailyLine,
            isLowCondition: lowCondition,
            isLowAppetite: lowAppetite,
            proteinEntriesToday: protein,
            strengthThisWeek: strength,
            now: now,
            calendar: calendar
        )
    }

    @Test func priorityFactThenConditionThenAppetite() {
        let now = TestCalendar.date(2026, 10, 22, 15)
        #expect(line(dailyLine: .noRecentWeight, lowCondition: true, lowAppetite: true, protein: 0, strength: 0, now: now) == .fact(.noRecentWeight))
        #expect(line(lowCondition: true, lowAppetite: true, protein: 0, strength: 0, now: now) == .lowCondition)
        #expect(line(lowAppetite: true, protein: 0, strength: 0, now: now) == .lowAppetite)
    }

    @Test func proteinOnlyFromNoon() {
        #expect(line(protein: 0, now: TestCalendar.date(2026, 10, 22, 11, 59)) != .proteinNotYet)
        #expect(line(protein: 0, now: TestCalendar.date(2026, 10, 22, 12)) == .proteinNotYet)
        #expect(line(protein: 2, now: TestCalendar.date(2026, 10, 22, 18)) != .proteinNotYet)
    }

    @Test func strengthOnlyLaterInTheWeek() {
        // 10-21(수)은 주 시작(10-18 일)부터 3일, 10-22(목)은 4일
        #expect(line(strength: 0, now: TestCalendar.date(2026, 10, 21, 9)) != .strengthNotYet)
        #expect(line(strength: 0, now: TestCalendar.date(2026, 10, 22, 9)) == .strengthNotYet)
        #expect(line(strength: 1, now: TestCalendar.date(2026, 10, 22, 9)) != .strengthNotYet)
    }

    @Test func tipsRotateByDayAndMarkHealthTips() {
        let monday = line(now: TestCalendar.date(2026, 10, 19, 9))
        let tuesday = line(now: TestCalendar.date(2026, 10, 20, 9))
        guard case let .tip(first) = monday, case let .tip(second) = tuesday else {
            Issue.record("expected tips, got \(monday), \(tuesday)")
            return
        }
        #expect((first + 1) % CoachRules.tipCount == second)
        #expect(CoachLine.tip(2).isHealthTip)
        #expect(!CoachLine.tip(0).isHealthTip)
        #expect(CoachLine.strengthNotYet.isHealthTip)
        #expect(!CoachLine.fact(.noRecentWeight).isHealthTip)
    }
}
