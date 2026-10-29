import Foundation
import SwiftData

/// 기본 습관: 수분·식이섬유·수면 가벼운 체크 (DATA_MODEL.md, M2 P2). 점수화하지 않는다.
@Model
final class HabitCheck {
    var id: UUID = UUID()
    /// 그 날 00:00
    var date: Date = Date.now
    var water: Bool = false
    var fiber: Bool = false
    var sleep: Bool = false
    /// 그날 메모 (N-E3, SchemaV7). 자유 글, 앱은 해석하지 않는다
    var note: String?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        date: Date,
        water: Bool = false,
        fiber: Bool = false,
        sleep: Bool = false,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.water = water
        self.fiber = fiber
        self.sleep = sleep
        self.note = note
        self.createdAt = createdAt
    }
}
