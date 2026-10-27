import Testing

@testable import Masense

// D20 사진으로 단백질 확인: 분류 이름 → 식품 종류, 단위·양 → 대략 g
struct FoodPhotoRulesTests {
    @Test func labelsMapToFoodsByConfidence() {
        let labels: [(identifier: String, confidence: Double)] = [
            ("fried_egg", 0.62), ("tofu", 0.3), ("food", 0.9), ("salmon", 0.05), ("egg", 0.4), ("bean_curd", 0.35),
        ]
        #expect(FoodPhotoRules.foods(from: labels) == [.egg, .tofu])
    }

    @Test func atMostThreeFoods() {
        let labels: [(identifier: String, confidence: Double)] = [
            ("egg", 0.5), ("steak", 0.4), ("cheese", 0.3), ("milk", 0.2),
        ]
        #expect(FoodPhotoRules.foods(from: labels) == [.egg, .beef, .cheese])
        #expect(FoodPhotoRules.foods(from: [("dessert", 0.9)]).isEmpty)
    }

    @Test func gramsFollowUnits() {
        let egg = FoodPhotoRules.units(for: .egg)[0]
        let spoon = FoodPhotoRules.units(for: .greekYogurt)[1]
        #expect(FoodPhotoRules.grams([(.egg, egg, 2), (.greekYogurt, spoon, 5)]) == 20)
        #expect(FoodPhotoRules.defaultAmount(for: spoon) == 5)
        #expect(FoodPhotoRules.units(for: .other).isEmpty)
        // 모든 식품(기타 제외)의 첫 단위는 R9 표 1회 기준 g과 같거나 그 묶음이다
        for food in ProteinFood.allCases where food != .other {
            #expect(FoodPhotoRules.units(for: food).first.map { Int($0.grams) } == food.defaultGrams)
        }
    }
}
