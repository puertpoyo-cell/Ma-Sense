import Foundation

/// D51 (0.8) 한 번에 투약 기록: 위젯 버튼, Siri·단축어. 부위는 "기록 없음"(nil)으로 넣고 나중에 앱에서 고친다 (D6).
/// 같은 마디에 두 번 넣지 않는다 (위젯을 두 번 누르거나 다른 기기에서 이미 기록한 경우)
enum QuickLogOutcome: Equatable {
    case noPrescription
    /// 처방 회차를 모두 기록했다
    case exhausted
    /// 이번 마디에 이미 기록이 있다. `next`는 다음 예정 (없으면 nil)
    case alreadyLogged(next: Date?)
    case log(DoseSnapshot)
}

enum QuickLogRules {
    /// - Parameter at: 누른 시각. 저장 시각은 30분 단위로 내린다 (D25, 투약 기록 화면과 같음)
    static func outcome(prescription: PrescriptionSnapshot?, doses: [DoseSnapshot], at: Date, calendar: Calendar) -> QuickLogOutcome {
        guard let p = prescription else { return .noPrescription }
        let cycles = CycleRules.cycles(for: p, doses: doses, now: at, until: .distantFuture, calendar: calendar)
        switch CycleRules.nextDose(cycles: cycles, doses: doses, now: at) {
        case nil:
            return .exhausted
        case let .done(_, next)?:
            return .alreadyLogged(next: next?.scheduledDate)
        case .due?, .overdue?:
            let administeredAt = DoseTimeRules.roundedDown(at, calendar: calendar)
            // 투약 시각이 속한 마디의 예정일. 어느 마디에도 없으면 투약 시각 그대로 (DoseLogModel과 같음)
            let scheduledFor = CycleRules.cycle(containing: administeredAt, in: cycles)?.scheduledDate ?? administeredAt
            return .log(DoseSnapshot(
                administeredAt: administeredAt,
                scheduledFor: scheduledFor,
                site: nil,
                sequence: PrescriptionRules.nextSequence(doses: doses)
            ))
        }
    }
}
