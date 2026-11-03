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

    /// D39 사진 속 글자(포장·메뉴판)에서 식품을 찾는 말. 한국어·영어, 앞에 둔 식품부터
    static let textKeywords: [(ProteinFood, [String])] = [
        (.chickenBreast, ["닭가슴살", "닭 가슴살", "닭안심", "닭고기", "치킨", "chicken"]),
        (.greekYogurt, ["그릭", "요거트", "요구르트", "yogurt", "yoghurt"]),
        (.proteinShake, ["프로틴", "쉐이크", "셰이크", "단백질 음료", "단백질음료", "protein shake", "whey", "웨이"]),
        (.tofu, ["두부", "순두부", "tofu"]),
        (.egg, ["계란", "달걀", "에그", "egg"]),
        (.fish, ["연어", "참치", "고등어", "삼치", "갈치", "생선", "새우", "오징어", "문어", "조개", "굴", "게살", "salmon", "tuna", "fish", "shrimp"]),
        (.beef, ["소고기", "쇠고기", "한우", "불고기", "스테이크", "갈비", "beef", "steak"]),
        (.pork, ["돼지", "삼겹", "목살", "돈까스", "돈가스", "베이컨", "햄", "소시지", "pork", "bacon", "ham", "sausage"]),
        (.cheese, ["치즈", "cheese"]),
        (.milk, ["우유", "라떼", "라테", "milk", "latte"]),
        (.beans, ["콩", "두유", "낫토", "병아리콩", "렌틸", "bean", "soy", "edamame", "lentil"]),
    ]

    /// 이 확신도보다 낮은 이름은 쓰지 않는다 (D39: 여러 조각으로 보면서 0.12 → 0.08)
    static let minimumConfidence = 0.08

    /// D39 사진을 나눠 보는 조각 (0...1 비율). 전체, 네 귀퉁이, 가운데. 한 상에 반찬이 여럿일 때 작은 것도 잡는다
    static let cropRects: [CGRect] = [
        CGRect(x: 0, y: 0, width: 1, height: 1),
        CGRect(x: 0, y: 0, width: 0.6, height: 0.6),
        CGRect(x: 0.4, y: 0, width: 0.6, height: 0.6),
        CGRect(x: 0, y: 0.4, width: 0.6, height: 0.6),
        CGRect(x: 0.4, y: 0.4, width: 0.6, height: 0.6),
        CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
    ]

    /// 조각마다 나온 분류 결과를 이름별 가장 높은 확신도로 합친다
    static func merged(_ runs: [[(identifier: String, confidence: Double)]]) -> [(identifier: String, confidence: Double)] {
        var best: [String: Double] = [:]
        for run in runs {
            for label in run { best[label.identifier] = max(best[label.identifier] ?? 0, label.confidence) }
        }
        return best.map { ($0.key, $0.value) }.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
    }

    /// D39 읽은 글자 → 식품 (글에 먼저 나온 순). 포장 이름·메뉴판에서
    static func foods(fromText lines: [String]) -> [ProteinFood] {
        let text = lines.joined(separator: "\n").lowercased()
        var found: [(ProteinFood, Int)] = []
        for (food, words) in textKeywords {
            let positions = words.compactMap { text.range(of: $0.lowercased())?.lowerBound }
            if let first = positions.min() {
                found.append((food, text.distance(from: text.startIndex, to: first)))
            }
        }
        return found.sorted { $0.1 < $1.1 }.map(\.0)
    }

    /// D39 영양성분표의 "단백질 12g" / "Protein 12 g". 여러 개면 가장 큰 값(1회 제공량 기준인 경우가 많다)
    static func labelProteinGrams(in lines: [String]) -> Double? {
        let text = lines.joined(separator: " ")
        let pattern = #"(?:단백질|protein)\s*[:：]?\s*([0-9]+(?:[.,][0-9]+)?)\s*(?:g|그램)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let values = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Double? in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[range].replacingOccurrences(of: ",", with: "."))
        }
        guard let grams = values.max(), grams > 0, grams < 200 else { return nil }
        return grams
    }

    /// 분류 결과와 읽은 글자를 합친 짐작. 분류(확신도 순) 먼저, 글자에서 찾은 것 뒤에, 3개까지
    static func foods(labels: [(identifier: String, confidence: Double)], text: [String]) -> [ProteinFood] {
        var result = foods(from: labels)
        for food in foods(fromText: text) where !result.contains(food) { result.append(food) }
        return Array(result.prefix(maxFoods))
    }

    /// 포장 표시 단위 (D39): 포장 1개에 영양성분표 단백질 g
    static let packageUnitKey = "package"
    static func packageUnit(grams: Double) -> PortionUnit {
        PortionUnit(key: packageUnitKey, grams: grams, step: 0.5)
    }

    /// 분류기 영문 이름을 보여 줄 때 ("fried_egg" → "fried egg")
    static func displayName(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ")
    }
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
