import Foundation

// M2 단백질·운동 기록이 쓰는 값 타입 (DATA_MODEL.md). 표시명은 Localizable.xcstrings.

enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }
    var titleKey: String { "meal." + rawValue }
}

enum ProteinFood: String, Codable, CaseIterable, Identifiable {
    case egg, tofu, chickenBreast, greekYogurt, proteinShake
    case fish, beef, pork, beans, milk, cheese, other

    var id: String { rawValue }
    var titleKey: String { "food." + rawValue }

    /// 1회 기준 대략의 단백질 g (RULES.md R9 표). 일반 식품 평균 추정치. `other`는 사용자가 합계를 직접 고친다
    var defaultGrams: Int {
        switch self {
        case .egg: return 6
        case .tofu: return 12
        case .chickenBreast: return 23
        case .greekYogurt: return 15
        case .proteinShake: return 20
        case .fish: return 20
        case .beef: return 22
        case .pork: return 20
        case .beans: return 8
        case .milk: return 7
        case .cheese: return 5
        case .other: return 0
        }
    }
}

enum SessionKind: String, Codable, CaseIterable, Identifiable {
    /// cardio: D16 피트니스 연동으로 더함 (달리기·자전거·수영 등). rawValue 문자열 저장이라 스키마 변경 없음
    case strength, walk, cardio, stretch, rest

    var id: String { rawValue }
    var titleKey: String { "session." + rawValue }
}

enum Intensity: String, Codable, CaseIterable, Identifiable {
    case light, moderate, vigorous

    var id: String { rawValue }
    var titleKey: String { "intensity." + rawValue }
}

enum SessionSource: String, Codable, CaseIterable {
    case manual, healthKit
}
