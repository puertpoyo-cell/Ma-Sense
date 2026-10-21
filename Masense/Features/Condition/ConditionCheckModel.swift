import Foundation
import Observation
import SwiftData

/// S3 컨디션 체크 폼. 강도 0인 증상은 저장하지 않는다.
@Observable
final class ConditionCheckModel {
    let window: ConditionWindow
    var appetite: AppetiteLevel = .normal
    var note: String = ""
    private(set) var severities: [Symptom: Int] = [:]

    private let dose: Dose

    init(dose: Dose, window: ConditionWindow) {
        self.dose = dose
        self.window = window
    }

    func severity(of symptom: Symptom) -> Int {
        severities[symptom] ?? 0
    }

    func setSeverity(_ severity: Int, for symptom: Symptom) {
        severities[symptom] = SymptomEntry(symptom: symptom, severity: severity).severity
    }

    /// 강도 1 이상만, `Symptom.allCases` 순서
    var entries: [SymptomEntry] {
        Symptom.allCases.compactMap { symptom in
            let value = severity(of: symptom)
            return value > 0 ? SymptomEntry(symptom: symptom, severity: value) : nil
        }
    }

    /// 심각도 3이 하나라도 있으면 "증상이 심하면 의사와 상담하세요."를 고정 노출. 그 이상의 판단은 하지 않는다
    var hasSevereSymptom: Bool {
        entries.contains { $0.severity >= 3 }
    }

    @discardableResult
    func save(in context: ModelContext, now: Date = Date()) throws -> ConditionCheck {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let check = ConditionCheck(
            checkedAt: now,
            window: window,
            symptoms: entries,
            appetite: appetite,
            note: trimmed.isEmpty ? nil : trimmed
        )
        context.insert(check)
        check.dose = dose
        try context.save()
        return check
    }
}
