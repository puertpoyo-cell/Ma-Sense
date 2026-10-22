import Foundation
import SwiftData

/// 기본 습관: 수분·식이섬유·수면 가벼운 체크 (DATA_MODEL.md, M2 P2). 점수화하지 않는다.
@Model
final class HabitCheck {
    @Attribute(.unique) var id: UUID
    /// 그 날 00:00
    var date: Date
    var water: Bool
    var fiber: Bool
    var sleep: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        water: Bool = false,
        fiber: Bool = false,
        sleep: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.water = water
        self.fiber = fiber
        self.sleep = sleep
        self.createdAt = createdAt
    }
}
