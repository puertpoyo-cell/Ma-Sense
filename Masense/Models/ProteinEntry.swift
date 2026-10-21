import Foundation
import SwiftData

/// 단백질 채우기: 끼니별 식품 체크 (DATA_MODEL.md, M2). 같은 식품을 여러 번 넣어 수량을 나타낸다.
@Model
final class ProteinEntry {
    @Attribute(.unique) var id: UUID
    /// 그 날 00:00 (로컬)
    var date: Date
    var meal: MealSlot
    var foods: [ProteinFood]
    /// 식품별 기본값 합산. 사용자가 덮어쓸 수 있다
    var estimatedGrams: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        meal: MealSlot,
        foods: [ProteinFood],
        estimatedGrams: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.meal = meal
        self.foods = foods
        self.estimatedGrams = estimatedGrams
        self.createdAt = createdAt
    }
}
