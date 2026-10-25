import Testing

@testable import Masense

// D13 바디맵 그림: 직접 고른 것 > 건강 앱 성별 > 남성
struct BodyFigureRulesTests {
    @Test func automaticFollowsHealthThenFallsBackToMale() {
        #expect(BodyFigureRules.figure(preference: .automatic, healthFigure: .female) == .female)
        #expect(BodyFigureRules.figure(preference: .automatic, healthFigure: .male) == .male)
        #expect(BodyFigureRules.figure(preference: .automatic, healthFigure: nil) == .male)
    }

    @Test func explicitChoiceWins() {
        #expect(BodyFigureRules.figure(preference: .male, healthFigure: .female) == .male)
        #expect(BodyFigureRules.figure(preference: .female, healthFigure: nil) == .female)
    }
}
