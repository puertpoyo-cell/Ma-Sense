import Foundation

/// 사진으로 단백질 확인 (D20). 기기 안 이미지 분류가 낸 이름으로 **식품 종류만** 짐작하고,
/// 양은 사용자에게 다시 묻는다 ("몇 개 드셨어요?"). 사진으로 양·칼로리를 판정하지 않는다 (COMPLIANCE.md 2.1-3·2.1-6).
/// g은 R9 표의 1회 기준을 단위에 맞춰 나눈 대략값이다
enum FoodPhotoRules {
    /// 분류 이름에 들어 있으면 그 식품으로 본다. 앞에 둔 식품부터 (두부를 콩보다, 셰이크를 우유보다 먼저)
    /// N-C2: 한식에서 흔한 것(계란말이·두부조림·닭갈비·삼겹살·생선구이·해산물)이 분류기에서 나오는 이름까지. 분류기 이름은 영문
    static let keywords: [(ProteinFood, [String])] = [
        (.egg, ["egg", "omelet", "omelette", "frittata", "scrambled", "quiche"]),
        (.tofu, ["tofu", "bean_curd", "beancurd", "soybean_curd"]),
        (.greekYogurt, ["yogurt", "yoghurt"]),
        (.proteinShake, ["smoothie", "milkshake", "protein_shake", "shake"]),
        (.chickenBreast, ["chicken", "poultry", "hen", "rotisserie", "drumstick", "wing"]),
        (.fish, ["fish", "salmon", "tuna", "mackerel", "cod", "sashimi", "sushi", "seafood", "shrimp", "prawn", "squid", "octopus",
                 "clam", "oyster", "mussel", "crab", "lobster", "eel", "anchovy"]),
        (.beef, ["beef", "steak", "burger", "hamburger", "bulgogi", "brisket", "short_rib", "rib", "meatball", "meatloaf", "roast_beef"]),
        (.pork, ["pork", "bacon", "ham", "sausage", "spare_rib", "pork_chop", "cutlet", "tonkatsu", "prosciutto"]),
        (.cheese, ["cheese", "mozzarella", "cheddar", "parmesan"]),
        (.milk, ["milk", "latte"]),
        (.beans, ["bean", "edamame", "soy", "legume", "lentil", "chickpea", "hummus", "natto"]),
    ]

    /// 이 확신도보다 낮은 이름은 쓰지 않는다
    static let minimumConfidence = 0.12
    /// 묻는 식품은 많아야 이만큼
    static let maxFoods = 3

    /// 분류 결과(이름, 확신도) → 짐작한 식품, 확신도 높은 순
    static func foods(from labels: [(identifier: String, confidence: Double)]) -> [ProteinFood] {
        var best: [ProteinFood: Double] = [:]
        for label in labels where label.confidence >= minimumConfidence {
            let name = label.identifier.lowercased()
            guard let food = keywords.first(where: { $0.1.contains { name.contains($0) } })?.0 else { continue }
            best[food] = max(best[food] ?? 0, label.confidence)
        }
        return best.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .prefix(maxFoods)
            .map(\.key)
    }

    /// 양을 묻는 단위. `grams`는 그 단위 1만큼의 단백질 g, `step`은 한 번 누를 때 늘어나는 양
    struct PortionUnit: Equatable, Hashable {
        let key: String
        let grams: Double
        let step: Double
    }

    /// 식품별 단위 (첫 번째가 기본). R9 표 1회 기준에서 나눈 값. 숟갈은 밥숟가락 하나(약 15 g)
    static func units(for food: ProteinFood) -> [PortionUnit] {
        switch food {
        case .egg: return [PortionUnit(key: "piece", grams: 6, step: 1)]
        case .tofu: return [PortionUnit(key: "halfBlock", grams: 12, step: 0.5)]
        case .chickenBreast: return [PortionUnit(key: "hundredGrams", grams: 23, step: 0.5)]
        case .greekYogurt: return [PortionUnit(key: "cup150", grams: 15, step: 0.5), PortionUnit(key: "spoon", grams: 1.5, step: 1)]
        case .proteinShake: return [PortionUnit(key: "serving", grams: 20, step: 0.5)]
        case .fish: return [PortionUnit(key: "fillet", grams: 20, step: 0.5)]
        case .beef: return [PortionUnit(key: "hundredGrams", grams: 22, step: 0.5)]
        case .pork: return [PortionUnit(key: "hundredGrams", grams: 20, step: 0.5)]
        case .beans: return [PortionUnit(key: "cup", grams: 8, step: 0.5), PortionUnit(key: "spoon", grams: 0.5, step: 1)]
        case .milk: return [PortionUnit(key: "cup", grams: 7, step: 0.5)]
        case .cheese: return [PortionUnit(key: "slice", grams: 5, step: 1)]
        case .other: return []
        }
    }

    /// 처음 묻는 양: 숟갈이면 5, 그 밖은 1
    static func defaultAmount(for unit: PortionUnit) -> Double {
        unit.key == "spoon" ? 5 : 1
    }

    /// 식품·단위·양 → 대략 g (반올림)
    static func grams(_ portions: [(food: ProteinFood, unit: PortionUnit, amount: Double)]) -> Int {
        Int((portions.reduce(0) { $0 + $1.unit.grams * max($1.amount, 0) }).rounded())
    }
}
