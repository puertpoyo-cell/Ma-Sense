import Foundation

/// R3-1 (D6). 지난 투약 한꺼번에 입력. 이 앱을 쓰기 전에 맞은 투약을 활성 처방의 누락 마디에 채운다.
/// 기록 시각은 마디의 예정 일시. 부위는 사용자가 고르거나 비워 둔다(부위 기록 없음).
/// 앱은 어느 주를 맞았는지 판단하지 않는다. 사용자가 켜 둔 주만 기록한다.
enum BackfillRules {
    struct Entry: Equatable {
        let scheduledDate: Date
        let sequence: Int
    }

    struct Plan: Equatable {
        /// 새로 만들 기록, 예정일 순
        let entries: [Entry]
        /// 이미 있는 기록의 새 회차 (id → 회차). 새 기록보다 뒤에 맞은 기록만, 그 앞에 넣은 수만큼 밀린다
        let renumbered: [UUID: Int]
    }

    /// 채울 수 있는 마디 = 활성 처방의 누락 마디 (R3), 예정일 순
    static func candidates(prescription: PrescriptionSnapshot, doses: [DoseSnapshot], now: Date, calendar: Calendar) -> [Cycle] {
        let cycles = CycleRules.pastCycles(for: prescription, doses: doses, nextStart: nil, now: now, calendar: calendar)
        return CycleRules.missedCycles(cycles: cycles, doses: doses, now: now)
    }

    /// 처방의 첫 기록(취소 제외)보다 앞선 누락 마디 수. 기록이 없으면 전부. 오늘 화면 안내 카드에 쓴다
    static func leadingCount(candidates: [Cycle], doses: [DoseSnapshot]) -> Int {
        guard let first = doses.filter({ !$0.isCancelled }).map(\.administeredAt).min() else { return candidates.count }
        return candidates.filter { $0.scheduledDate < first }.count
    }

    /// 처음에 켜 둘 마디: 남은 회차를 넘지 않게 최근 마디부터. 마디 `index`
    static func defaultSelection(candidates: [Cycle], remaining: Int) -> Set<Int> {
        Set(candidates.suffix(max(remaining, 0)).map(\.index))
    }

    /// 새 기록의 회차는 취소되지 않은 기록과 합쳐 시간 순으로 센 번호.
    /// 이미 있는 기록은 그보다 앞에 넣은 새 기록 수만큼 회차가 밀린다
    static func plan(selected: [Date], doses: [DoseSnapshot]) -> Plan {
        let dates = selected.sorted()
        let active = doses.filter { !$0.isCancelled }
        let entries = dates.enumerated().map { offset, date in
            Entry(scheduledDate: date, sequence: active.filter { $0.administeredAt < date }.count + offset + 1)
        }
        var renumbered: [UUID: Int] = [:]
        for dose in active {
            let shift = dates.filter { $0 < dose.administeredAt }.count
            if shift > 0 {
                renumbered[dose.id] = dose.sequence + shift
            }
        }
        return Plan(entries: entries, renumbered: renumbered)
    }
}
