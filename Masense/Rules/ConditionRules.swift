import Foundation

/// R5. 컨디션 체크 윈도우.
enum ConditionRules {
    private static let hour: TimeInterval = 3_600

    /// `.h24`: 투약 후 12h 이상 36h 미만
    static let h24Window: Range<TimeInterval> = (12 * hour)..<(36 * hour)
    /// `.h48`: 투약 후 36h 이상 96h 미만
    static let h48Window: Range<TimeInterval> = (36 * hour)..<(96 * hour)

    /// 지금 열려 있는 창. 이미 응답한 창은 제외. 취소된 기록은 창이 없다.
    /// 창이 닫히면 홈에서 사라지고, 기록 화면에서는 "지난 체크"로 추가 입력할 수 있다.
    static func openConditionWindows(
        dose: DoseSnapshot,
        checks: [ConditionCheckSnapshot],
        now: Date
    ) -> [ConditionWindow] {
        guard !dose.isCancelled else { return [] }
        let elapsed = now.timeIntervalSince(dose.administeredAt)
        let answered = Set(checks.filter { $0.doseID == dose.id }.map(\.window))

        var open: [ConditionWindow] = []
        if h24Window.contains(elapsed), !answered.contains(.h24) {
            open.append(.h24)
        }
        if h48Window.contains(elapsed), !answered.contains(.h48) {
            open.append(.h48)
        }
        return open
    }

    /// 홈 1-2 카드용. 여러 기록 중 열린 창을 (기록, 창) 쌍으로. h24가 h48보다 앞, 같은 창이면 투약 시각 순.
    static func openConditionWindows(
        doses: [DoseSnapshot],
        checks: [ConditionCheckSnapshot],
        now: Date
    ) -> [(dose: DoseSnapshot, window: ConditionWindow)] {
        doses
            .flatMap { dose in
                openConditionWindows(dose: dose, checks: checks, now: now).map { (dose: dose, window: $0) }
            }
            .sorted { lhs, rhs in
                if lhs.window != rhs.window { return lhs.window == .h24 }
                return lhs.dose.administeredAt < rhs.dose.administeredAt
            }
    }
}
