import Foundation
import Testing

@testable import Masense

// D21 펼침 판정과 단 수
struct UnfoldRulesTests {
    @Test func unfoldIsWidthGrowthWithHeightKept() {
        let folded = CGSize(width: 400, height: 880)
        #expect(UnfoldRules.isUnfold(from: folded, to: CGSize(width: 820, height: 880)))
        // 펼친 기기는 높이가 조금 달라질 수 있다
        #expect(UnfoldRules.isUnfold(from: folded, to: CGSize(width: 800, height: 840)))
        // 회전: 폭은 늘지만 높이가 크게 줄어든다
        #expect(!UnfoldRules.isUnfold(from: folded, to: CGSize(width: 880, height: 400)))
        // 접기·같은 폭·처음 배치
        #expect(!UnfoldRules.isUnfold(from: CGSize(width: 820, height: 880), to: folded))
        #expect(!UnfoldRules.isUnfold(from: folded, to: folded))
        #expect(!UnfoldRules.isUnfold(from: .zero, to: folded))
    }

    @Test func twoColumnsOnlyWhenLandscapeAndWide() {
        #expect(UnfoldRules.columns(for: CGSize(width: 880, height: 820)) == 2)
        #expect(UnfoldRules.columns(for: CGSize(width: 820, height: 880)) == 1)
        #expect(UnfoldRules.columns(for: CGSize(width: 600, height: 400)) == 1)
        #expect(UnfoldRules.columns(for: CGSize(width: 400, height: 880)) == 1)
    }
}
