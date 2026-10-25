import Foundation

/// 오늘 화면 맨 위 "마선생 한마디" (R20, D12). 캐릭터가 말하는 한 줄.
/// 과정(기록·단백질·움직임·쉼)을 다정하게 권할 뿐 체중 결과·감량을 평가하거나 칭찬하지 않는다 (COMPLIANCE.md 3.1)
enum CoachLine: Equatable {
    /// R17 사실 한 줄 (투약일·남은 펜·체중 기록 없음)
    case fact(DailyLine)
    /// R11 저컨디션 날: 쉬기·걷기도 기록이 된다
    case lowCondition
    /// R10 식욕 저하일: 아래 "작게 자주" 식품
    case lowAppetite
    /// 오후인데 오늘 단백질 기록이 없다
    case proteinNotYet
    /// 주 후반인데 이번 주 근력운동 기록이 없다
    case strengthNotYet
    /// 날마다 돌아가는 일반 한마디 (0..<`CoachRules.tipCount`)
    case tip(Int)

    /// 건강관리 정보라 "의사와 상의하세요" 고지를 함께 보이는 줄
    var isHealthTip: Bool {
        switch self {
        case .lowAppetite, .strengthNotYet: return true
        case let .tip(index): return CoachRules.healthTipIndices.contains(index)
        default: return false
        }
    }
}

enum CoachRules {
    static let tipCount = 8
    /// 일반 한마디 중 건강관리 정보인 것 (단백질·물·근력·수면)
    static let healthTipIndices: Set<Int> = [2, 3, 5, 6]
    /// 이 시각 이후에만 단백질 기록을 권한다
    static let proteinNudgeHour = 12
    /// 주 시작(달력 firstWeekday)부터 며칠이 지나야 근력운동을 권하는지
    static let strengthNudgeDaysIntoWeek = 4

    /// 우선순위: 사실 한 줄 > 저컨디션 > 식욕 저하 > 단백질 > 근력 > 일반 한마디(날짜로 돌림)
    static func line(
        dailyLine: DailyLine?,
        isLowCondition: Bool,
        isLowAppetite: Bool,
        proteinEntriesToday: Int,
        strengthThisWeek: Int,
        now: Date,
        calendar: Calendar
    ) -> CoachLine {
        if let dailyLine { return .fact(dailyLine) }
        if isLowCondition { return .lowCondition }
        if isLowAppetite { return .lowAppetite }
        if proteinEntriesToday == 0, calendar.component(.hour, from: now) >= proteinNudgeHour {
            return .proteinNotYet
        }
        if strengthThisWeek == 0,
           let week = calendar.dateInterval(of: .weekOfYear, for: now),
           let days = calendar.dateComponents([.day], from: week.start, to: calendar.startOfDay(for: now)).day,
           days >= strengthNudgeDaysIntoWeek {
            return .strengthNotYet
        }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        return .tip(dayOfYear % tipCount)
    }
}
