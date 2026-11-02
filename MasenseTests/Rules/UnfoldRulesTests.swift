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

    // 기록 탭 세로 전환: 오른쪽만 넓게 빈 화면(오른쪽 탭 막대)일 때만
    @Test func trailingRailWidthOnlyWhenRightSideIsReserved() {
        #expect(UnfoldRules.trailingRailWidth(leading: 0, trailing: 100) == 100)
        #expect(UnfoldRules.trailingRailWidth(leading: 0, trailing: 0) == nil)
        // 가로 iPhone 노치 여백은 양쪽이 비슷하다
        #expect(UnfoldRules.trailingRailWidth(leading: 59, trailing: 59) == nil)
        #expect(UnfoldRules.trailingRailWidth(leading: 0, trailing: 40) == nil)
    }
}
