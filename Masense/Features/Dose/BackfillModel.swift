import Foundation
import Observation
import SwiftData

/// 지난 투약 한꺼번에 입력 (D6, RULES.md R3-1). 활성 처방의 누락 마디를 나열하고, 사용자가 켜 둔 주만 예정 일시로 기록한다.
@Observable
final class BackfillModel {
    struct Row: Identifiable, Equatable {
        let cycle: Cycle
        var isIncluded: Bool
        /// nil = 부위 기록 없음
        var site: BodySite?
        var id: Int { cycle.index }
    }

    var rows: [Row]
    /// 남은 회차. 이보다 많이 켤 수 없다
    let remaining: Int
    let startDate: Date

    private let prescription: Prescription

    init(prescription: Prescription, now: Date = Date(), calendar: Calendar = .current) {
        let doses = prescription.doseSnapshots
        let snapshot = prescription.snapshot
        let candidates = BackfillRules.candidates(prescription: snapshot, doses: doses, now: now, calendar: calendar)
        let remaining = PrescriptionRules.remainingDoses(p: snapshot, doses: doses)
        let selected = BackfillRules.defaultSelection(candidates: candidates, remaining: remaining)
        self.prescription = prescription
        self.remaining = remaining
        startDate = prescription.startDate
        rows = candidates.map { Row(cycle: $0, isIncluded: selected.contains($0.index), site: nil) }
    }

    var selectedCount: Int { rows.filter(\.isIncluded).count }

    var canSave: Bool { selectedCount > 0 && selectedCount <= remaining }

    /// 남은 회차를 다 채웠으면 꺼진 주는 더 켤 수 없다
    func canToggle(_ row: Row) -> Bool {
        row.isIncluded || selectedCount < remaining
    }

    /// 새 기록보다 뒤에 있어 회차가 밀리는 기존 기록 수
    var renumberedCount: Int {
        plan.renumbered.count
    }

    private var plan: BackfillRules.Plan {
        BackfillRules.plan(selected: rows.filter(\.isIncluded).map(\.cycle.scheduledDate), doses: prescription.doseSnapshots)
    }

    /// 저장한 기록 수
    @discardableResult
    func save(in context: ModelContext) throws -> Int {
        guard canSave else { return 0 }
        let plan = self.plan
        let sites = Dictionary(rows.filter(\.isIncluded).map { ($0.cycle.scheduledDate, $0.site) }, uniquingKeysWith: { first, _ in first })
        for dose in prescription.doses {
            if let sequence = plan.renumbered[dose.id] {
                dose.sequence = sequence
            }
        }
        for entry in plan.entries {
            let dose = Dose(
                administeredAt: entry.scheduledDate,
                scheduledFor: entry.scheduledDate,
                site: sites[entry.scheduledDate] ?? nil,
                sequence: entry.sequence
            )
            context.insert(dose)
            dose.prescription = prescription
        }
        try context.save()
        return plan.entries.count
    }
}
