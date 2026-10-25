import Foundation

/// 이번 주 운동 사실. 주간 목표 수치를 띄우지 않는다 ("이번 주 근력 2회"처럼 사실만)
struct StrengthWeek: Equatable {
    let strengthCount: Int
    /// 걷기 + 유산소(D16) + 스트레칭. 화면 이름 "걷기·유산소 등"
    let lightCount: Int
    let restCount: Int
}

/// R11 근력운동 마디.
enum StrengthRules {
    static func strengthWeekSummary(sessions: [StrengthSessionSnapshot], weekOf date: Date, calendar: Calendar) -> StrengthWeek {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return StrengthWeek(strengthCount: 0, lightCount: 0, restCount: 0)
        }
        let inWeek = sessions.filter { $0.startedAt >= week.start && $0.startedAt < week.end }
        return StrengthWeek(
            strengthCount: inWeek.filter { $0.kind == .strength }.count,
            lightCount: inWeek.filter { lightKinds.contains($0.kind) }.count,
            restCount: inWeek.filter { $0.kind == .rest }.count
        )
    }

    /// 근력이 아닌 움직임 (주간 정리·오늘의 마디에서 함께 센다)
    static let lightKinds: Set<SessionKind> = [.walk, .cardio, .stretch]

    /// 저컨디션 날(`ConditionRules.isLowConditionDay`)이면 걷기·스트레칭·쉬기를 위로
    static func kindOrder(isLowCondition: Bool) -> [SessionKind] {
        isLowCondition ? [.walk, .stretch, .rest, .strength, .cardio] : [.strength, .walk, .cardio, .stretch, .rest]
    }
}
