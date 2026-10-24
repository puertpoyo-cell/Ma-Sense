import Foundation
import SwiftData

/// 단백질 채우기: 끼니별 식품 체크 (DATA_MODEL.md, M2). 같은 식품을 여러 번 넣어 수량을 나타낸다.
@Model
final class ProteinEntry {
    var id: UUID = UUID()
    /// 그 날 00:00 (로컬)
    var date: Date = Date.now
    /// `MealSlot` rawValue
    var mealRaw: String = "breakfast"
    /// `ProteinFood` rawValue 배열
    var foodsRaw: [String] = []
    /// 식품별 기본값 합산. 사용자가 덮어쓸 수 있다
    var estimatedGrams: Int = 0
    var createdAt: Date = Date.now

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
        self.mealRaw = meal.rawValue
        self.foodsRaw = foods.map(\.rawValue)
        self.estimatedGrams = estimatedGrams
        self.createdAt = createdAt
    }

    var meal: MealSlot {
        get { MealSlot(rawValue: mealRaw) ?? .breakfast }
        set { mealRaw = newValue.rawValue }
    }

    /// 모르는 rawValue는 `.other`로 읽는다 (식품 수량을 잃지 않게)
    var foods: [ProteinFood] {
        get { foodsRaw.map { ProteinFood(rawValue: $0) ?? .other } }
        set { foodsRaw = newValue.map(\.rawValue) }
    }
}
