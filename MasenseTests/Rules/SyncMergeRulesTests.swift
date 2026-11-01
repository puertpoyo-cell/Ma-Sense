import Foundation
import Testing

@testable import Masense

// D26 iCloud 동기화 중복 정리
struct SyncMergeRulesTests {
    private let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    private let c = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!

    @Test func oldestSurvivesAndTiesBreakByID() {
        let early = TestCalendar.date(2026, 10, 1)
        let late = TestCalendar.date(2026, 10, 30)
        let items: [SyncMergeRules.Item<Int>] = [
            .init(id: b, key: 1, createdAt: late),
            .init(id: a, key: 1, createdAt: early),
            .init(id: c, key: 2, createdAt: late),
        ]
        #expect(SyncMergeRules.duplicates(items) == [b: a])
        // 같은 시각이면 id 문자열이 앞선 것
        let tied: [SyncMergeRules.Item<String>] = [
            .init(id: c, key: "x", createdAt: early),
            .init(id: b, key: "x", createdAt: early),
        ]
        #expect(SyncMergeRules.duplicates(tied) == [c: b])
        #expect(SyncMergeRules.duplicates([SyncMergeRules.Item<Int>]()).isEmpty)
    }

    @Test func sameResultRegardlessOfOrder() {
        let day = TestCalendar.date(2026, 10, 1)
        let items: [SyncMergeRules.Item<Int>] = [
            .init(id: a, key: 0, createdAt: day),
            .init(id: b, key: 0, createdAt: day),
            .init(id: c, key: 0, createdAt: day),
        ]
        #expect(SyncMergeRules.duplicates(items) == SyncMergeRules.duplicates(Array(items.reversed())))
        #expect(SyncMergeRules.duplicates(items) == [b: a, c: a])
    }

    @Test func mergedNoteKeepsBothWhenDifferent() {
        #expect(SyncMergeRules.mergedNote("물 많이", nil) == "물 많이")
        #expect(SyncMergeRules.mergedNote(nil, " 산책 ") == "산책")
        #expect(SyncMergeRules.mergedNote("같음", "같음") == "같음")
        #expect(SyncMergeRules.mergedNote("아침", "저녁") == "아침\n저녁")
        #expect(SyncMergeRules.mergedNote(nil, "  ") == nil)
    }
}
