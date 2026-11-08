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
    /// 진료일 당일·다음 날인데 진료 기록이 없다 (N-F4). "진료 기록을 남겨 둘까요"
    case clinicFollowUp
    /// 기록을 마친 직후 (D19). 체중이 늘든 줄든 같은 말투, 평가 없음
    case recorded(CoachRecordKind)
    /// 사진으로 확인하고 기록한 단백질 대략 g (D20). 많다·적다 평가 없음
    case proteinEstimate(Int)
    /// 말 걸기 주제의 고정 대답 (D19, `CoachRules.answerCounts`)
    case answer(CoachTopic, Int)
    /// D30 시간대 인사 (아침·낮·저녁·밤)
    case greetingAt(CoachDayPart)
    /// D30 글로 물은 것이 의사와 상의할 이야기. "물어볼 것에 담을까요"
    case askDoctor
    /// D30 알아듣지 못함
    case notUnderstood
    /// D30 물어볼 것에 담음
    case savedQuestion
    /// D44 다음 진료까지 n일 (0 = 오늘). 리포트 미리 만들기
    case clinicSoon(Int)
    /// D44 진료가 일주일 안인데 물어볼 것이 비어 있다
    case questionsEmpty
    /// D44 같은 증상을 n마디 이어서 기록했다. 물어볼 것으로
    case repeatedSymptom(Symptom, Int)
    /// D44 지난 투약 뒤 컨디션 기록이 비어 있다
    case conditionMissing
    /// D44 남은 펜으로 맞는 마지막 투약일이 다음 진료보다 한참 앞이다. 병원에 미리 확인
    case pensShort(lastDose: Date, clinic: Date)
    /// D44 기록이 n일째 비어 있다
    case recordGap(Int)

    /// 캐릭터 표정 (D19). 말에 맞춰 얼굴만 바꾼다
    var mood: CoachMood {
        switch self {
        case .recorded, .proteinEstimate: return .happy
        case .lowCondition, .lowAppetite, .answer(.condition, _), .askDoctor: return .gentle
        case .savedQuestion: return .happy
        case .clinicSoon, .questionsEmpty, .pensShort: return .thinking
        case .repeatedSymptom, .recordGap: return .gentle
        case .notUnderstood: return .thinking
        case .fact(.lowSupply), .place(.pens), .place(.report), .place(.clinic), .tip(4), .answer(.clinic, _), .clinicFollowUp: return .thinking
        case .tip(0), .tip(3), .tip(7), .answer(.water, _): return .wink
        default: return .smile
        }
    }

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
        case .clinicFollowUp: return "clinicFollowUp"
        case let .recorded(kind): return "recorded." + kind.rawValue
        case .proteinEstimate: return "proteinEstimate"
        case let .answer(topic, index): return "answer." + topic.rawValue + "." + String(index)
        case let .greetingAt(part): return "greeting." + part.rawValue
        case .askDoctor: return "askDoctor"
        case .notUnderstood: return "notUnderstood"
        case .savedQuestion: return "savedQuestion"
        case .clinicSoon: return "clinicSoon"
        case .questionsEmpty: return "questionsEmpty"
        case let .repeatedSymptom(symptom, _): return "repeatedSymptom." + symptom.rawValue
        case .conditionMissing: return "conditionMissing"
        case .pensShort: return "pensShort"
        case .recordGap: return "recordGap"
        }
    }

    /// 건강관리 정보라 "의사와 상의하세요" 고지를 함께 보이는 줄
    var isHealthTip: Bool {
        switch self {
        case .lowAppetite, .strengthNotYet: return true
        case let .tip(index): return CoachRules.healthTipIndices.contains(index)
        case let .answer(topic, index): return CoachRules.healthAnswers.contains("\(topic.rawValue).\(index)")
        default: return false
        }
    }
}

/// D35 마선생이 나올 때 얼굴 움직임 (2026-11-02 사람 요청 "살짝 커지거나 부르르 떨거나 통통 튀거나")
enum CoachEntrance: String, CaseIterable {
    /// 살짝 커졌다 제자리
    case pop
    /// 좌우로 부르르
    case wiggle
    /// 위로 통통 두 번
    case bounce

    /// 표정에 맞춰: 기쁨·윙크는 통통, 생각은 부르르, 다정은 살짝 커짐.
    /// 기본 웃음은 말투(`variant`)마다 돌려 같은 말이라도 매번 조금 다르게
    static func `for`(_ line: CoachLine, variant: Int) -> CoachEntrance {
        switch line.mood {
        case .happy, .wink: return .bounce
        case .thinking: return .wiggle
        case .gentle: return .pop
        case .smile: return allCases[((variant % allCases.count) + allCases.count) % allCases.count]
        }
    }
}

/// D42 마선생 말투 (2026-11-06 사람 요청 "약간 매운맛, 빨간 배경, 약간 채찍질"). 기기 설정(UserDefaults), 기본 순한맛.
/// 매운맛은 과정(기록·단백질·움직임·물·잠)만 단호하게 재촉한다. 체중 결과 평가·질책, 느낌표, 의료 판단은 매운맛에도 없다 (COMPLIANCE.md 3.1).
/// 저컨디션·식욕 저하·의사 상의·고정 대답처럼 다정해야 하는 줄은 매운맛에서도 순한 문장을 쓴다
enum CoachTone: String, CaseIterable {
    case mild
    case spicy

    static let key = "coach.tone"
}

/// D30 하루 때. 인사를 바꾼다
enum CoachDayPart: String, CaseIterable {
    case morning, afternoon, evening, night

    /// 5~11시 아침, 11~17시 낮, 17~21시 저녁, 그 밖 밤
    static func of(_ date: Date, calendar: Calendar) -> CoachDayPart {
        switch calendar.component(.hour, from: date) {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
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
    /// D20 진료 탭
    case clinic
}

/// D18 말 걸기에서 고르는 주제 (D19에서 물·수면·체중·컨디션 추가). 화면에는 이 순서로
enum CoachTopic: String, CaseIterable {
    case today
    case protein
    case movement
    case water
    case sleep
    case weight
    case condition
    case clinic
    case more
}

/// D19 기록 직후 한마디의 종류
enum CoachRecordKind: String, CaseIterable {
    case dose
    case condition
    case weight
    case protein
    case exercise
}

/// D19 캐릭터 표정
enum CoachMood: String, CaseIterable {
    case smile
    case happy
    case gentle
    case thinking
    case wink
}

/// 자리별 한마디를 고르는 데 필요한 오늘의 사실
struct CoachContext: Equatable {
    var dailyLine: DailyLine?
    var isLowCondition = false
    var isLowAppetite = false
    var proteinEntriesToday = 0
    var strengthThisWeek = 0
    /// N-F4: 다음 진료일이 오늘이거나 어제인데 그날 진료 기록이 없다
    var clinicNeedsRecord = false
    /// D44 기록·진료 상황 (CoachFactsRules)
    var facts = CoachFacts()
}

enum CoachRules {
    static let tipCount = 8
    /// 한 줄마다 같은 뜻의 다른 말투 수 (D18). 화면이 그중 하나를 고른다
    static let variantCount = 3
    /// 주제별 고정 대답 수 (`coach.answer.<topic>.<n>`)
    static let answerCounts: [CoachTopic: Int] = [
        .today: 2, .protein: 2, .movement: 2, .water: 3, .sleep: 3, .weight: 3, .condition: 4, .clinic: 2,
    ]
    /// 고정 대답 중 건강관리 정보 (고지를 붙인다)
    static let healthAnswers: Set<String> = ["water.0", "sleep.0", "protein.0", "movement.0", "movement.1"]
    /// 일반 한마디 중 건강관리 정보인 것 (단백질·물·근력·수면)
    static let healthTipIndices: Set<Int> = [2, 3, 5, 6]
    /// 이 시각 이후에만 단백질 기록을 권한다
    static let proteinNudgeHour = 12
    /// 주 시작(달력 firstWeekday)부터 며칠이 지나야 근력운동을 권하는지
    static let strengthNudgeDaysIntoWeek = 4

    /// 우선순위: 사실 한 줄 > 저컨디션 > 식욕 저하 > 진료 기록 권유(N-F4) > 단백질 > 근력 > 일반 한마디(날짜로 돌림)
    static func line(
        dailyLine: DailyLine?,
        isLowCondition: Bool,
        isLowAppetite: Bool,
        proteinEntriesToday: Int,
        strengthThisWeek: Int,
        clinicNeedsRecord: Bool = false,
        now: Date,
        calendar: Calendar
    ) -> CoachLine {
        if let dailyLine { return .fact(dailyLine) }
        if isLowCondition { return .lowCondition }
        if isLowAppetite { return .lowAppetite }
        if clinicNeedsRecord { return .clinicFollowUp }
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
            let primary = line(
                dailyLine: c.dailyLine,
                isLowCondition: c.isLowCondition,
                isLowAppetite: c.isLowAppetite,
                proteinEntriesToday: c.proteinEntriesToday,
                strengthThisWeek: c.strengthThisWeek,
                clinicNeedsRecord: c.clinicNeedsRecord,
                now: now,
                calendar: calendar
            )
            // D44: 일반 한마디보다 기록·진료 제안이 먼저
            let facts = factLines(c.facts, for: .todayTop)
            if case .tip = primary { return facts + [primary] }
            return [primary] + facts
        case .pens:
            var result: [CoachLine] = []
            if let fact = c.dailyLine, case .lowSupply = fact { result.append(.fact(fact)) }
            result += factLines(c.facts, for: .pens)
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
            return factLines(c.facts, for: .history) + [.place(.history), .tip(0)]
        case .report:
            return factLines(c.facts, for: .report) + [.place(.report), .tip(4)]
        case .clinic:
            return (c.clinicNeedsRecord ? [.clinicFollowUp] : []) + factLines(c.facts, for: .clinic) + [.place(.clinic), .tip(4)]
        }
    }

    /// D44 자리별 기록·진료 제안. 급한 것(펜·진료 임박)부터
    static func factLines(_ f: CoachFacts, for spot: CoachSpot) -> [CoachLine] {
        let pens: [CoachLine] = f.pensLastDose.flatMap { last in f.pensClinic.map { [.pensShort(lastDose: last, clinic: $0)] } } ?? []
        let soon: [CoachLine] = f.daysToClinic.flatMap { $0 <= CoachFactsRules.clinicSoonDays ? [.clinicSoon($0)] : nil } ?? []
        let questions: [CoachLine] = f.daysToClinic != nil && f.openQuestions == 0 ? [.questionsEmpty] : []
        let symptom: [CoachLine] = f.repeatedSymptom.map { [.repeatedSymptom($0, f.repeatedPeriods)] } ?? []
        let condition: [CoachLine] = f.conditionMissing ? [.conditionMissing] : []
        let gap: [CoachLine] = f.recordGapDays.map { [.recordGap($0)] } ?? []
        switch spot {
        case .todayTop: return pens + soon + condition + symptom + questions
        case .pens: return pens
        case .history: return gap + condition + symptom + soon
        case .clinic: return pens + soon + questions + symptom
        case .report: return soon + questions + condition + symptom
        default: return []
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
            let gap: [CoachLine] = c.facts.recordGapDays.map { [.recordGap($0)] } ?? []
            candidates = lines(for: .todayTop, context: c, now: now, calendar: calendar) + gap + [.tip(0), .tip(3)] + answers(.today)
        case .protein:
            var result: [CoachLine] = []
            if c.isLowAppetite { result.append(.lowAppetite) }
            if c.proteinEntriesToday == 0, isAfternoon { result.append(.proteinNotYet) }
            candidates = result + [.tip(2), .tip(3)] + answers(.protein)
        case .movement:
            var result: [CoachLine] = []
            if c.isLowCondition { result.append(.lowCondition) }
            if c.strengthThisWeek == 0 { result.append(.strengthNotYet) }
            candidates = result + [.tip(5), .tip(6)] + answers(.movement)
        case .water:
            candidates = [.tip(3)] + answers(.water)
        case .sleep:
            candidates = [.tip(6)] + answers(.sleep)
        case .weight:
            var result: [CoachLine] = []
            if c.dailyLine == .noRecentWeight { result.append(.fact(.noRecentWeight)) }
            candidates = result + [.tip(1), .tip(7)] + answers(.weight)
        case .condition:
            var result: [CoachLine] = []
            if c.isLowCondition { result.append(.lowCondition) }
            if let symptom = c.facts.repeatedSymptom { result.append(.repeatedSymptom(symptom, c.facts.repeatedPeriods)) }
            if c.facts.conditionMissing { result.append(.conditionMissing) }
            candidates = result + answers(.condition)
        case .clinic:
            var result: [CoachLine] = []
            if c.clinicNeedsRecord { result.append(.clinicFollowUp) }
            result += factLines(c.facts, for: .clinic)
            if let fact = c.dailyLine, case .lowSupply = fact { result.append(.fact(fact)) }
            candidates = result + [.tip(4), .place(.report), .place(.history)] + answers(.clinic)
        case .more:
            // 오늘 날짜에서 시작해 일반 한마디를 차례로
            let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
            candidates = (0..<tipCount).map { .tip((day + $0) % tipCount) }
        }
        return candidates.first { !shownKeys.contains($0.key) } ?? candidates[0]
    }

    /// D30 말 걸기 주제 버튼 순서. 지금 상황에 맞는 주제를 앞으로, 나머지는 원래 순서
    static func suggestedTopics(context c: CoachContext, now: Date, calendar: Calendar) -> [CoachTopic] {
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let daysIntoWeek = (weekday - calendar.firstWeekday + 7) % 7
        var first: [CoachTopic] = []
        if c.clinicNeedsRecord || c.facts.pensLastDose != nil || c.facts.daysToClinic != nil { first.append(.clinic) }
        if c.isLowCondition || c.isLowAppetite || c.facts.repeatedSymptom != nil || c.facts.conditionMissing { first.append(.condition) }
        if c.proteinEntriesToday == 0, hour >= proteinNudgeHour { first.append(.protein) }
        if c.strengthThisWeek == 0, daysIntoWeek >= strengthNudgeDaysIntoWeek { first.append(.movement) }
        if c.dailyLine == .noRecentWeight { first.append(.weight) }
        if hour >= 21 || hour < 5 { first.append(.sleep) }
        if (5..<11).contains(hour) { first.append(.water) }
        if let fact = c.dailyLine, case .lowSupply = fact { first.append(.clinic) }
        var seen = Set<CoachTopic>()
        return (first + [.today] + CoachTopic.allCases).filter { seen.insert($0).inserted }
    }

    /// D30 말 걸기 첫 인사: 진료 기록 권유처럼 지금 꼭 할 말이 있으면 그것, 없으면 시간대 인사
    static func greeting(context c: CoachContext, now: Date, calendar: Calendar) -> CoachLine {
        if c.clinicNeedsRecord { return .clinicFollowUp }
        if c.isLowCondition { return .lowCondition }
        // D44 진료 임박·펜 부족은 인사보다 먼저
        if let last = c.facts.pensLastDose, let clinic = c.facts.pensClinic { return .pensShort(lastDose: last, clinic: clinic) }
        if let days = c.facts.daysToClinic, days <= 1 { return .clinicSoon(days) }
        return .greetingAt(CoachDayPart.of(now, calendar: calendar))
    }

    private static func answers(_ topic: CoachTopic) -> [CoachLine] {
        (0..<(answerCounts[topic] ?? 0)).map { .answer(topic, $0) }
    }

    /// D42 매운맛 문장이 있는 줄의 키 앞부분 (`coach.<base>.spicy[.v2|.v3]`). 여기 없는 줄은 매운맛에서도 순한 문장
    static let spicyBases: Set<String> = [
        "greeting", "greeting.morning", "greeting.afternoon", "greeting.evening", "greeting.night",
        "proteinNotYet", "strengthNotYet", "noWeight", "doseDay.noSite", "clinicFollowUp",
        "tip.0", "tip.1", "tip.2", "tip.3", "tip.4", "tip.5", "tip.6", "tip.7",
        "place.pens", "place.history", "place.report", "place.clinic",
        "recorded.dose", "recorded.condition", "recorded.exercise", "recorded.protein",
        "notUnderstood", "savedQuestion",
        "questionsEmpty", "conditionMissing", "clinicSoon.today",
    ]

    /// 매운맛에서도 순한 문장만 쓰는 줄 (다정해야 하거나 결과를 말하는 줄). `spicyBases`와 겹치면 안 된다 (테스트)
    static let alwaysMildBases: Set<String> = ["lowCondition", "lowAppetite", "askDoctor", "recorded.weight"]

    /// 문구 키: `coach.<base>` + 매운맛이면 `.spicy` + 말투 `.v2`/`.v3`. 매운맛 문장이 없는 줄은 순한 키
    static func localizedKey(base: String, variant: Int, tone: CoachTone) -> String {
        let suffix = variant == 0 ? "" : ".v" + String(variant + 1)
        let spicy = tone == .spicy && spicyBases.contains(base) ? ".spicy" : ""
        return "coach." + base + spicy + suffix
    }

    /// N-F4. 다음 진료일이 오늘 또는 어제이고, 그날짜의 진료 기록이 없으면 true
    static func clinicNeedsRecord(nextClinicDate: Date?, visitDates: [Date], now: Date, calendar: Calendar) -> Bool {
        guard let clinic = nextClinicDate else { return false }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: clinic), to: calendar.startOfDay(for: now)).day ?? 0
        guard (0...1).contains(days) else { return false }
        return !visitDates.contains { calendar.isDate($0, inSameDayAs: clinic) }
    }
}
