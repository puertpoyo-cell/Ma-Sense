import Foundation

/// R13. 처방 소진 추정과 회차 계산.
enum PrescriptionRules {
    /// 취소되지 않은 기록 수
    static func usedDoses(_ doses: [DoseSnapshot]) -> Int {
        doses.filter { !$0.isCancelled }.count
    }

    static func remainingDoses(p: PrescriptionSnapshot, doses: [DoseSnapshot]) -> Int {
        max(p.totalDoses - usedDoses(doses), 0)
    }

    /// 새 기록의 회차 (1부터). 사용자가 수정할 수 있다
    static func nextSequence(doses: [DoseSnapshot]) -> Int {
        usedDoses(doses) + 1
    }

    /// "n회차 (펜 m의 k번째)". `pen`·`position` 모두 1부터
    static func penPosition(sequence: Int, dosesPerPen: Int) -> (pen: Int, position: Int) {
        guard dosesPerPen > 0, sequence > 0 else { return (pen: 1, position: max(sequence, 1)) }
        return (pen: (sequence - 1) / dosesPerPen + 1, position: (sequence - 1) % dosesPerPen + 1)
    }

    /// 소진 예상일. 남은 회차가 0이면 nil. 그 외에는 남은 회차를 모두 쓰는 마지막 마디의 예정일.
    static func exhaustionEstimate(
        p: PrescriptionSnapshot,
        doses: [DoseSnapshot],
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard remainingDoses(p: p, doses: doses) > 0 else { return nil }
        // CycleRules.cycles는 회차가 소진되는 마디에서 멈추므로 마지막 마디가 곧 소진 마디다
        return CycleRules.cycles(for: p, doses: doses, now: now, until: .distantFuture, calendar: calendar)
            .last?.scheduledDate
    }
}
