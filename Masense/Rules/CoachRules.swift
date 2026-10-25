import Foundation

/// "마선생 한마디" (R20, D12·D18). 캐릭터가 말하는 한 줄.
/// D18: 화면 맨 위에 늘 떠 있지 않고, 스크롤하다 자리(`CoachSpot`)에 닿으면 그 자리에 맞는 한 줄이 팝업으로 한 번 튀어나온다.
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
    /// 자리에 붙은 고정 한마디 (펜·기록·리포트)
    case place(CoachSpot)
    /// 말 걸기를 눌렀을 때 첫 인사 (D18)
    case greeting

    /// 하루에 같은 한마디를 두 번 띄우지 않는 데 쓰는 키
    var key: String {
        switch self {
        case let .fact(line): return "fact." + line.kind
        case .lowCondition: return "lowCondition"
        case .lowAppetite: return "lowAppetite"
        case .proteinNotYet: return "proteinNotYet"
        case .strengthNotYet: return "strengthNotYet"
        case let .tip(index): return "tip." + String(index)
        case let .place(spot): return "place." + spot.rawValue
        case .greeting: return "greeting"
        }
    }

    /// 건강관리 정보라 "의사와 상의하세요" 고지를 함께 보이는 줄
    var isHealthTip: Bool {
        switch self {
        case .lowAppetite, .strengthNotYet: return true
        case let .tip(index): return CoachRules.healthTipIndices.contains(index)
        default: return false
        }
    }
}

/// D18 팝업이 뜨는 자리. 오늘 탭은 카드마다, 기록·리포트 탭은 탭을 열 때
enum CoachSpot: String, CaseIterable {
    /// 오늘 탭 맨 위 (카운트다운 카드)
    case todayTop
    case pens
    case weight
    case daily
    case routine
    case info
    case history
    case report
}

/// D18 말 걸기에서 고르는 주제
enum CoachTopic: String, CaseIterable {
    case today
    case protein
    case movement
    case clinic
    case more
}

/// 자리별 한마디를 고르는 데 필요한 오늘의 사실
struct CoachContext: Equatable {
    var dailyLine: DailyLine?
    var isLowCondition = false
    var isLowAppetite = false
    var proteinEntriesToday = 0
    var strengthThisWeek = 0
}

enum CoachRules {
    static let tipCount = 8
    /// 한 줄마다 같은 뜻의 다른 말투 수 (D18). 화면이 그중 하나를 고른다
    static let variantCount = 3
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

    /// D18 자리별 후보를 우선순위대로. 화면은 오늘 아직 띄우지 않은 첫 줄을 고른다 (모두 띄웠으면 그 자리는 조용히 지나간다)
    static func lines(for spot: CoachSpot, context c: CoachContext, now: Date, calendar: Calendar) -> [CoachLine] {
        let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        let isAfternoon = calendar.component(.hour, from: now) >= proteinNudgeHour
        switch spot {
        case .todayTop:
            return [line(
                dailyLine: c.dailyLine,
                isLowCondition: c.isLowCondition,
                isLowAppetite: c.isLowAppetite,
                proteinEntriesToday: c.proteinEntriesToday,
                strengthThisWeek: c.strengthThisWeek,
                now: now,
                calendar: calendar
            )]
        case .pens:
            var result: [CoachLine] = []
            if let fact = c.dailyLine, case .lowSupply = fact { result.append(.fact(fact)) }
            result.append(.place(.pens))
            return result
        case .weight:
            var result: [CoachLine] = []
            if c.dailyLine == .noRecentWeight { result.append(.fact(.noRecentWeight)) }
            // 같은 조건에서 재기 / 오르내림은 자연스럽다, 날마다 번갈아
            result += day % 2 == 0 ? [.tip(1), .tip(7)] : [.tip(7), .tip(1)]
            return result
        case .daily:
            var result: [CoachLine] = []
            if c.isLowAppetite { result.append(.lowAppetite) }
            if c.isLowCondition { result.append(.lowCondition) }
            if c.proteinEntriesToday == 0, isAfternoon { result.append(.proteinNotYet) }
            result += day % 2 == 0 ? [.tip(2), .tip(3), .tip(6)] : [.tip(3), .tip(2), .tip(6)]
            return result
        case .routine:
            var result: [CoachLine] = []
            if c.strengthThisWeek == 0 { result.append(.strengthNotYet) }
            result.append(.tip(5))
            return result
        case .info:
            return [.tip(4), .tip(0)]
        case .history:
            return [.place(.history), .tip(0)]
        case .report:
            return [.place(.report), .tip(4)]
        }
    }

    /// 오늘 이미 띄운 키를 빼고 첫 줄
    static func next(for spot: CoachSpot, context: CoachContext, shownKeys: Set<String>, now: Date, calendar: Calendar) -> CoachLine? {
        lines(for: spot, context: context, now: now, calendar: calendar).first { !shownKeys.contains($0.key) }
    }

    /// D18 말 걸기 주제에 대한 대답. 지금 상황에 맞는 줄을 먼저, 없으면 일반 한마디.
    /// `shownKeys`는 이번 대화에서 이미 한 줄 (같은 주제를 다시 물으면 다른 줄로)
    static func reply(to topic: CoachTopic, context c: CoachContext, shownKeys: Set<String>, now: Date, calendar: Calendar) -> CoachLine {
        let isAfternoon = calendar.component(.hour, from: now) >= proteinNudgeHour
        let candidates: [CoachLine]
        switch topic {
        case .today:
            candidates = lines(for: .todayTop, context: c, now: now, calendar: calendar) + [.tip(0), .tip(3)]
        case .protein:
            var result: [CoachLine] = []
            if c.isLowAppetite { result.append(.lowAppetite) }
            if c.proteinEntriesToday == 0, isAfternoon { result.append(.proteinNotYet) }
            candidates = result + [.tip(2), .tip(3)]
        case .movement:
            var result: [CoachLine] = []
            if c.isLowCondition { result.append(.lowCondition) }
            if c.strengthThisWeek == 0 { result.append(.strengthNotYet) }
            candidates = result + [.tip(5), .tip(6)]
        case .clinic:
            var result: [CoachLine] = []
            if let fact = c.dailyLine, case .lowSupply = fact { result.append(.fact(fact)) }
            candidates = result + [.tip(4), .place(.report), .place(.history)]
        case .more:
            // 오늘 날짜에서 시작해 일반 한마디를 차례로
            let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
            candidates = (0..<tipCount).map { .tip((day + $0) % tipCount) }
        }
        return candidates.first { !shownKeys.contains($0.key) } ?? candidates[0]
    }
}
