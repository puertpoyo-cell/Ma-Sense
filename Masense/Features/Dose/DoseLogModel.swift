import Foundation
import Observation
import SwiftData

/// S2 투약 기록 폼. 과거 시각도 받아서 누락을 해제할 수 있다 (R3).
@Observable
final class DoseLogModel {
    var administeredAt: Date
    var site: BodySite?
    /// 처방 내 회차 (1부터). 자동 계산, 사용자가 고칠 수 있다
    var sequence: Int
    var note: String = ""

    /// 시트를 연 시각. 이보다 미래는 고를 수 없다
    let openedAt: Date
    /// 바디맵 최근 사용 부위 (R6)
    let history: [SiteUse]
    let dosesPerPen: Int
    let totalDoses: Int

    private let prescription: Prescription
    private let calendar: Calendar

    /// `initialDate`: 기록 탭의 누락 마디에서 열면 그 예정일로 시작한다 (R3 누락 해제)
    init(prescription: Prescription, initialDate: Date? = nil, now: Date = Date(), calendar: Calendar = .current) {
        let doses = prescription.doseSnapshots
        self.prescription = prescription
        self.calendar = calendar
        openedAt = now
        administeredAt = min(initialDate ?? now, now)
        sequence = PrescriptionRules.nextSequence(doses: doses)
        history = SiteRules.siteHistory(doses: doses)
        dosesPerPen = prescription.dosesPerPen
        totalDoses = prescription.totalDoses
    }

    var canSave: Bool { site != nil && sequence >= 1 }

    var penPosition: (pen: Int, position: Int) {
        PrescriptionRules.penPosition(sequence: sequence, dosesPerPen: dosesPerPen)
    }

    @discardableResult
    func save(in context: ModelContext) throws -> Dose? {
        guard let site, canSave else { return nil }
        let doses = prescription.doseSnapshots
        let cycles = CycleRules.cycles(
            for: prescription.snapshot,
            doses: doses,
            now: openedAt,
            until: .distantFuture,
            calendar: calendar
        )
        // 투약 시각이 속한 마디의 예정일. 어느 마디에도 없으면 투약 시각 그대로
        let scheduledFor = CycleRules.cycle(containing: administeredAt, in: cycles)?.scheduledDate ?? administeredAt
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let dose = Dose(
            administeredAt: administeredAt,
            scheduledFor: scheduledFor,
            site: site,
            sequence: sequence,
            note: trimmed.isEmpty ? nil : trimmed
        )
        context.insert(dose)
        dose.prescription = prescription
        try context.save()
        return dose
    }
}
