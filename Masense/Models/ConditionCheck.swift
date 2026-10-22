import Foundation
import SwiftData

/// 투약 후 24h·48h 컨디션 체크 (DATA_MODEL.md).
/// 심각도 3이 하나라도 있으면 UI는 `symptom.severe` 문구를 고정 노출하고, 그 이상의 판단은 하지 않는다.
@Model
final class ConditionCheck {
    var id: UUID = UUID()
    /// 응답 시각
    var checkedAt: Date = Date.now
    /// `ConditionWindow` rawValue
    var windowRaw: String = "h24"
    /// Codable 배열로 저장
    var symptoms: [SymptomEntry] = []
    /// `AppetiteLevel` rawValue
    var appetiteRaw: String = "normal"
    var note: String?
    var dose: Dose?
    var createdAt: Date = Date.now

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
        self.windowRaw = window.rawValue
        self.symptoms = symptoms
        self.appetiteRaw = appetite.rawValue
        self.note = note
        self.dose = dose
        self.createdAt = createdAt
    }

    var window: ConditionWindow {
        get { ConditionWindow(rawValue: windowRaw) ?? .h24 }
        set { windowRaw = newValue.rawValue }
    }

    var appetite: AppetiteLevel {
        get { AppetiteLevel(rawValue: appetiteRaw) ?? .normal }
        set { appetiteRaw = newValue.rawValue }
    }

    /// 심각도 3 증상이 하나라도 있는지
    var hasSevereSymptom: Bool {
        symptoms.contains { $0.severity >= 3 }
    }
}
