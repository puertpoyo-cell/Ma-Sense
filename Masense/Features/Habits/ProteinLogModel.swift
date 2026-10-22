import Foundation
import Observation
import SwiftData

/// S7 단백질 채우기 폼. 식품 칩 + 수량, 합계는 "대략".
@Observable
final class ProteinLogModel {
    var meal: MealSlot
    /// `.other`를 골랐을 때 사용자가 적는 g
    var otherGramsText: String = ""
    private(set) var quantities: [ProteinFood: Int] = [:]

    /// 사용자·의료진이 입력한 하루 목표. nil이면 추정치만
    let target: Int?
    /// 이 기록 전까지 오늘 쌓인 g
    let recordedToday: Int
    /// R10 식욕 저하일이면 "작게 자주" 행을 위에 보인다
    let isLowAppetite: Bool

    static let quantityRange = 0...10
    static let otherGramsRange = 0...200

    private let now: Date
    private let calendar: Calendar

    init(
        target: Int?,
        recordedToday: Int,
        isLowAppetite: Bool,
        preselected: ProteinFood? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.target = target
        self.recordedToday = recordedToday
        self.isLowAppetite = isLowAppetite
        self.now = now
        self.calendar = calendar
        meal = Self.defaultMeal(at: now, calendar: calendar)
        if let preselected {
            quantities[preselected] = 1
        }
    }

    /// 지금 시각에 맞는 끼니 (10시 전 아침, 15시 전 점심, 21시 전 저녁, 그 뒤 간식)
    static func defaultMeal(at date: Date, calendar: Calendar) -> MealSlot {
        switch calendar.component(.hour, from: date) {
        case ..<10: return .breakfast
        case ..<15: return .lunch
        case ..<21: return .dinner
        default: return .snack
        }
    }

    func quantity(of food: ProteinFood) -> Int {
        quantities[food] ?? 0
    }

    func setQuantity(_ value: Int, for food: ProteinFood) {
        quantities[food] = min(max(value, Self.quantityRange.lowerBound), Self.quantityRange.upperBound)
    }

    /// 칩 탭: 없으면 1, 있으면 0
    func toggle(_ food: ProteinFood) {
        setQuantity(quantity(of: food) == 0 ? 1 : 0, for: food)
    }

    /// 수량만큼 반복한 식품 목록 (저장 형식)
    var foods: [ProteinFood] {
        ProteinFood.allCases.flatMap { Array(repeating: $0, count: quantity(of: $0)) }
    }

    var otherGrams: Int {
        guard quantity(of: .other) > 0, let value = Int(otherGramsText.trimmingCharacters(in: .whitespaces)) else { return 0 }
        return min(max(value, Self.otherGramsRange.lowerBound), Self.otherGramsRange.upperBound)
    }

    var estimatedGrams: Int {
        ProteinRules.estimatedGrams(for: foods) + otherGrams
    }

    /// 저장하면 오늘 합계
    var todayTotal: Int { recordedToday + estimatedGrams }

    var canSave: Bool { !foods.isEmpty }

    @discardableResult
    func save(in context: ModelContext) throws -> ProteinEntry? {
        guard canSave else { return nil }
        let entry = ProteinEntry(
            date: calendar.startOfDay(for: now),
            meal: meal,
            foods: foods,
            estimatedGrams: estimatedGrams
        )
        context.insert(entry)
        try context.save()
        return entry
    }
}
