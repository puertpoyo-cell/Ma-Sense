import Foundation
import Testing

@testable import Masense

// RULES.md R15 진료 때 물어볼 것 (D6)
struct ClinicQuestionRulesTests {
    @Test func normalizedTrimsJoinsLinesAndLimitsLength() {
        #expect(ClinicQuestionRules.normalized("  다음 진료 때\n  물어볼 것  ") == "다음 진료 때 물어볼 것")
        #expect(ClinicQuestionRules.normalized(" \n  ") == nil)
        let long = String(repeating: "가", count: ClinicQuestionRules.maxLength + 10)
        #expect(ClinicQuestionRules.normalized(long)?.count == ClinicQuestionRules.maxLength)
    }

    @Test func pendingInWrittenOrderAskedMostRecentFirst() {
        let first = ClinicQuestionSnapshot(text: "첫째", createdAt: TestCalendar.date(2026, 10, 20, 9))
        let second = ClinicQuestionSnapshot(text: "둘째", createdAt: TestCalendar.date(2026, 10, 21, 9))
        let askedEarly = ClinicQuestionSnapshot(text: "먼저 물어봄", askedAt: TestCalendar.date(2026, 10, 22, 10), createdAt: TestCalendar.date(2026, 10, 1, 9))
        let askedLate = ClinicQuestionSnapshot(text: "나중에 물어봄", askedAt: TestCalendar.date(2026, 10, 23, 10), createdAt: TestCalendar.date(2026, 10, 2, 9))
        let all = [askedEarly, second, askedLate, first]
        #expect(ClinicQuestionRules.pending(all).map(\.text) == ["첫째", "둘째"])
        #expect(ClinicQuestionRules.asked(all).map(\.text) == ["나중에 물어봄", "먼저 물어봄"])
    }
}
