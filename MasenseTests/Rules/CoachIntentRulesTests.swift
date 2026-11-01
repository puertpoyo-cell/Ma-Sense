import Foundation
import Testing

@testable import Masense

// D30 마선생에게 글로 묻기: 분류만, 의사 질문이 먼저
struct CoachIntentRulesTests {
    @Test func doctorQuestionsWinOverTopics() {
        #expect(CoachIntentRules.classify("용량 늘려도 될까요") == .askDoctor)
        #expect(CoachIntentRules.classify("다음 단계로 가도 돼?") == .askDoctor)
        #expect(CoachIntentRules.classify("Lv2로 올려도 되나") == .askDoctor)
        #expect(CoachIntentRules.classify("메스꺼움이 너무 심해요") == .askDoctor)
        #expect(CoachIntentRules.classify("주사 한 번 건너뛰어도 돼?") == .askDoctor)
        #expect(CoachIntentRules.classify("약을 바꿔도 될까") == .askDoctor)
        // "예약"은 약 질문이 아니다
        #expect(CoachIntentRules.classify("예약을 바꾸고 싶어") == .topic(.clinic))
    }

    @Test func topicsByKeywords() {
        #expect(CoachIntentRules.classify("단백질 뭐 먹지") == .topic(.protein))
        #expect(CoachIntentRules.classify("오늘 뭐부터 할까") == .topic(.today))
        #expect(CoachIntentRules.classify("요즘 잠을 잘 못 자") == .topic(.sleep))
        #expect(CoachIntentRules.classify("운동 어떻게 시작해") == .topic(.movement))
        #expect(CoachIntentRules.classify("속이 울렁거려") == .topic(.condition))
        #expect(CoachIntentRules.classify("다음 진료 예약 언제지") == .topic(.clinic))
        #expect(CoachIntentRules.classify("ㅎㅎ") == .unknown)
        #expect(CoachIntentRules.classify("   ") == .unknown)
    }

    @Test func modelNeverOverridesDoctorRule() {
        #expect(CoachIntentRules.merge(rule: .askDoctor, model: .topic(.protein)) == .askDoctor)
        #expect(CoachIntentRules.merge(rule: .unknown, model: .askDoctor) == .askDoctor)
        #expect(CoachIntentRules.merge(rule: .topic(.water), model: .topic(.sleep)) == .topic(.water))
        #expect(CoachIntentRules.merge(rule: .unknown, model: .topic(.sleep)) == .topic(.sleep))
        #expect(CoachIntentRules.merge(rule: .unknown, model: nil) == .unknown)
    }

    @Test func suggestedTopicsFollowContext() {
        let calendar = TestCalendar.seoul
        // 2026-10-22(목) 14시: 단백질 기록 없음 + 진료 기록 권유
        var c = CoachContext()
        c.clinicNeedsRecord = true
        let topics = CoachRules.suggestedTopics(context: c, now: TestCalendar.date(2026, 10, 22, 14), calendar: calendar)
        #expect(Array(topics.prefix(2)) == [.clinic, .protein])
        #expect(Set(topics) == Set(CoachTopic.allCases))
        #expect(topics.count == CoachTopic.allCases.count)
        // 밤에는 잠
        let night = CoachRules.suggestedTopics(context: CoachContext(proteinEntriesToday: 1, strengthThisWeek: 1), now: TestCalendar.date(2026, 10, 19, 22), calendar: calendar)
        #expect(night.first == .sleep)
    }

    @Test func greetingByContextAndTime() {
        let calendar = TestCalendar.seoul
        #expect(CoachRules.greeting(context: CoachContext(), now: TestCalendar.date(2026, 10, 22, 8), calendar: calendar) == .greetingAt(.morning))
        #expect(CoachRules.greeting(context: CoachContext(), now: TestCalendar.date(2026, 10, 22, 23), calendar: calendar) == .greetingAt(.night))
        var c = CoachContext()
        c.clinicNeedsRecord = true
        #expect(CoachRules.greeting(context: c, now: TestCalendar.date(2026, 10, 22, 8), calendar: calendar) == .clinicFollowUp)
    }
}
