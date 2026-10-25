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

    // D18 자리별 팝업
    @Test func spotsPreferFactsThenFallBackToTips() {
        let now = TestCalendar.date(2026, 10, 22, 15)
        let low = CoachContext(dailyLine: .lowSupply(remaining: 1, isSingleUsePen: true), proteinEntriesToday: 1, strengthThisWeek: 1)
        #expect(CoachRules.lines(for: .pens, context: low, now: now, calendar: calendar).first == .fact(.lowSupply(remaining: 1, isSingleUsePen: true)))
        #expect(CoachRules.lines(for: .pens, context: CoachContext(), now: now, calendar: calendar) == [.place(.pens)])
        #expect(CoachRules.lines(for: .weight, context: CoachContext(dailyLine: .noRecentWeight), now: now, calendar: calendar).first == .fact(.noRecentWeight))
        #expect(CoachRules.lines(for: .daily, context: CoachContext(isLowAppetite: true), now: now, calendar: calendar).first == .lowAppetite)
        #expect(CoachRules.lines(for: .daily, context: CoachContext(proteinEntriesToday: 0), now: now, calendar: calendar).first == .proteinNotYet)
        #expect(CoachRules.lines(for: .routine, context: CoachContext(strengthThisWeek: 0), now: now, calendar: calendar).first == .strengthNotYet)
        #expect(CoachRules.lines(for: .history, context: CoachContext(), now: now, calendar: calendar).first == .place(.history))
    }

    @Test func nextSkipsLinesAlreadyShownToday() {
        let now = TestCalendar.date(2026, 10, 22, 15)
        let context = CoachContext(proteinEntriesToday: 0, strengthThisWeek: 1)
        // 맨 위에서 단백질 한마디를 이미 띄웠으면 오늘의 마디 자리에서는 일반 한마디로
        let top = CoachRules.next(for: .todayTop, context: context, shownKeys: [], now: now, calendar: calendar)
        #expect(top == .proteinNotYet)
        let daily = CoachRules.next(for: .daily, context: context, shownKeys: [top!.key], now: now, calendar: calendar)
        #expect(daily != .proteinNotYet)
        #expect(daily != nil)
        // 후보를 다 띄웠으면 조용히
        let all = Set(CoachRules.lines(for: .info, context: context, now: now, calendar: calendar).map(\.key))
        #expect(CoachRules.next(for: .info, context: context, shownKeys: all, now: now, calendar: calendar) == nil)
    }
}
