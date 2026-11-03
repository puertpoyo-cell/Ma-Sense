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

    // N-C2: 한식에서 흔한 분류기 이름
    @Test func koreanMealLabelsMapToFoods() {
        #expect(FoodPhotoRules.foods(from: [("scrambled_eggs", 0.5)]) == [.egg])
        #expect(FoodPhotoRules.foods(from: [("grilled_mackerel", 0.5), ("squid", 0.3)]) == [.fish])
        #expect(FoodPhotoRules.foods(from: [("short_ribs", 0.6)]) == [.beef])
        #expect(FoodPhotoRules.foods(from: [("pork_chop", 0.6), ("tonkatsu", 0.2)]) == [.pork])
        #expect(FoodPhotoRules.foods(from: [("natto", 0.4)]) == [.beans])
    }
}

// D39 여러 조각 합치기, 글자에서 식품, 영양성분표 단백질 g
struct FoodPhotoTextRulesTests {
    @Test func mergedKeepsHighestConfidencePerName() {
        let merged = FoodPhotoRules.merged([[("egg", 0.2), ("plate", 0.9)], [("egg", 0.6)]])
        #expect(merged.map(\.identifier) == ["plate", "egg"])
        #expect(merged[1].confidence == 0.6)
        #expect(FoodPhotoRules.cropRects.count == 6)
    }

    @Test func textFindsFoodsInOrderOfAppearance() {
        #expect(FoodPhotoRules.foods(fromText: ["그릭 요거트 플레인", "원재료: 우유"]) == [.greekYogurt, .milk])
        #expect(FoodPhotoRules.foods(fromText: ["닭가슴살 스테이크 100g"]) == [.chickenBreast, .beef])
        #expect(FoodPhotoRules.foods(fromText: ["Protein Shake"]) == [.proteinShake])
        #expect(FoodPhotoRules.foods(fromText: []).isEmpty)
    }

    @Test func nutritionLabelProteinGrams() {
        #expect(FoodPhotoRules.labelProteinGrams(in: ["열량 120kcal", "단백질 23g (41%)"]) == 23)
        #expect(FoodPhotoRules.labelProteinGrams(in: ["Protein 12.5 g"]) == 12.5)
        #expect(FoodPhotoRules.labelProteinGrams(in: ["단백질: 8 g", "단백질 20g"]) == 20)
        #expect(FoodPhotoRules.labelProteinGrams(in: ["단백질 함량 높음"]) == nil)
        #expect(FoodPhotoRules.labelProteinGrams(in: ["단백질 0g"]) == nil)
    }

    @Test func labelsAndTextCombineUpToThree() {
        let labels: [(identifier: String, confidence: Double)] = [("fried_egg", 0.5)]
        #expect(FoodPhotoRules.foods(labels: labels, text: ["두부 300g", "계란"]) == [.egg, .tofu])
        #expect(FoodPhotoRules.foods(labels: [("steak", 0.5), ("cheese", 0.4)], text: ["우유", "연어"]) == [.beef, .cheese, .milk])
        let unit = FoodPhotoRules.packageUnit(grams: 23)
        #expect(FoodPhotoRules.grams([(.chickenBreast, unit, 1.5)]) == 35)
        #expect(FoodPhotoRules.displayName("fried_egg") == "fried egg")
    }
}
