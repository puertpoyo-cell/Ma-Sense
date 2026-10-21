import Foundation

// ConditionCheck가 쓰는 값 타입들 (DATA_MODEL.md).

enum ConditionWindow: String, Codable, CaseIterable {
    case h24, h48
}

enum Symptom: String, Codable, CaseIterable, Identifiable {
    case nausea, vomiting, constipation, diarrhea
    case fatigue, headache, dizziness
    case injectionSiteReaction
    case heartburn, bloating

    var id: String { rawValue }

    var localizedName: String {
        L10n.string("symptom." + rawValue)
    }
}

extension ConditionWindow {
    /// "투약 후 24시간" / "투약 후 48시간"
    var titleKey: String { "condition.window." + rawValue }
}

extension AppetiteLevel {
    var titleKey: String { "appetite." + rawValue }
}

struct SymptomEntry: Codable, Hashable {
    var symptom: Symptom
    /// 0 없음, 1 약함, 2 보통, 3 심함
    var severity: Int

    static let severityRange = 0...3

    init(symptom: Symptom, severity: Int) {
        self.symptom = symptom
        self.severity = min(max(severity, Self.severityRange.lowerBound), Self.severityRange.upperBound)
    }
}

enum AppetiteLevel: String, Codable, CaseIterable {
    case normal, reduced, veryReduced
}
