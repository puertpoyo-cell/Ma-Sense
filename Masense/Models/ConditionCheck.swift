import Foundation
import SwiftData

/// 투약 후 24h·48h 컨디션 체크 (DATA_MODEL.md).
/// 심각도 3이 하나라도 있으면 UI는 `symptom.severe` 문구를 고정 노출하고, 그 이상의 판단은 하지 않는다.
@Model
final class ConditionCheck {
    @Attribute(.unique) var id: UUID
    /// 응답 시각
    var checkedAt: Date
    var window: ConditionWindow
    /// Codable 배열로 저장
    var symptoms: [SymptomEntry]
    var appetite: AppetiteLevel
    var note: String?
    var dose: Dose?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        checkedAt: Date,
        window: ConditionWindow,
        symptoms: [SymptomEntry] = [],
        appetite: AppetiteLevel = .normal,
        note: String? = nil,
        dose: Dose? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.checkedAt = checkedAt
        self.window = window
        self.symptoms = symptoms
        self.appetite = appetite
        self.note = note
        self.dose = dose
        self.createdAt = createdAt
    }

    /// 심각도 3 증상이 하나라도 있는지
    var hasSevereSymptom: Bool {
        symptoms.contains { $0.severity >= 3 }
    }
}
