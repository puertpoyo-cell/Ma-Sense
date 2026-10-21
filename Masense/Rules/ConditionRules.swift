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

    /// R10·R11 공용: 최근 48시간 안의 컨디션 체크에 강도 2 이상 증상이 있거나 식욕이 평소와 다르면 저컨디션 날.
    /// R10의 "구역 ≥ 2"를 R11의 "심각도 2 이상 증상"으로 넓혀 한 함수로 쓴다 (RULES.md R11).
    static let lowConditionLookback: TimeInterval = 48 * hour

    static func isLowConditionDay(checks: [ConditionCheckSnapshot], now: Date) -> Bool {
        checks.contains { check in
            let age = now.timeIntervalSince(check.checkedAt)
            guard age >= 0, age < lowConditionLookback else { return false }
            return check.symptoms.contains { $0.severity >= 2 } || check.appetite != .normal
        }
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
