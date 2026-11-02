import Foundation

/// D37 잠 흐름 (RULES.md R29, 2026-11-02 사람 결정 "잠 흐름 + 리포트").
/// 건강 앱 수면 기록을 밤 단위로 묶고, 투약 후 며칠째인지에 따라 나란히 놓는다.
/// 원인을 판단하지 않는다. 숫자만 모으고 해석은 의사와 (COMPLIANCE.md). 저장하지 않고 볼 때마다 건강 앱에서 읽는다

enum SleepStage: Equatable {
    case inBed, asleep, awake
}

/// 건강 앱 수면 샘플 한 조각
struct SleepSegment: Equatable {
    let start: Date
    let end: Date
    let stage: SleepStage
}

/// 하룻밤. `day`는 일어난 날 00:00 (11월 2일 새벽에 깼으면 11월 2일 밤으로 센다)
struct SleepNight: Equatable, Identifiable, Hashable {
    let day: Date
    let asleepMinutes: Int
    /// 잠든 사이 5분 이상 깨어 있던 횟수
    let awakenings: Int
    let bedtime: Date
    let wakeTime: Date
    var id: Date { day }
}

/// 투약 후 며칠째(0 = 투약일 다음 아침이 아니라 투약한 날에 일어난 밤)의 평균
struct SleepFlowDay: Equatable, Identifiable {
    let offset: Int
    let nights: Int
    let averageAsleepMinutes: Int?
    let averageAwakenings: Double?
    /// 일어난 시각 평균 (자정부터 분)
    let averageWakeMinute: Int?
    var id: Int { offset }
}

/// 기간 평균 (리포트·물어볼 것 문장)
struct SleepSummary: Equatable, Hashable {
    let nights: Int
    let averageAsleepMinutes: Int
    let averageAwakenings: Double
    let averageWakeMinute: Int
}

enum SleepRules {
    /// 깨어남으로 세는 최소 틈 (분)
    static let awakeningMinutes: Double = 5
    /// 한 밤으로 묶는 최대 틈 (시간). 이보다 길게 떨어지면 다른 잠(낮잠 등)
    static let sessionGapHours: Double = 3
    /// 흐름에 넣는 투약 후 날 수 (0...6)
    static let flowDays = 0...6
    /// 잠 흐름이 보는 기간 (주)
    static let flowWeeks = 8

    /// 수면 조각 → 밤. 잠든 조각(없으면 침대에 있던 조각)을 겹침 없이 합치고, 3시간 넘게 떨어지면 다른 잠으로 나눈다.
    /// 같은 날 일어난 잠이 여럿이면 가장 오래 잔 것만 그날 밤으로 본다
    static func nights(from segments: [SleepSegment], calendar: Calendar) -> [SleepNight] {
        let asleep = segments.filter { $0.stage == .asleep }
        let source = asleep.isEmpty ? segments.filter { $0.stage == .inBed } : asleep
        let merged = merge(source.map { ($0.start, $0.end) })
        guard !merged.isEmpty else { return [] }

        var sessions: [[(Date, Date)]] = []
        for interval in merged {
            if let last = sessions.last?.last, interval.0.timeIntervalSince(last.1) <= sessionGapHours * 3600 {
                sessions[sessions.count - 1].append(interval)
            } else {
                sessions.append([interval])
            }
        }

        var byDay: [Date: SleepNight] = [:]
        for session in sessions {
            guard let first = session.first, let last = session.last else { continue }
            let minutes = session.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) } / 60
            let gaps = zip(session, session.dropFirst()).filter { $1.0.timeIntervalSince($0.1) >= awakeningMinutes * 60 }.count
            let night = SleepNight(
                day: calendar.startOfDay(for: last.1),
                asleepMinutes: Int(minutes.rounded()),
                awakenings: gaps,
                bedtime: first.0,
                wakeTime: last.1
            )
            if let existing = byDay[night.day], existing.asleepMinutes >= night.asleepMinutes { continue }
            byDay[night.day] = night
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    /// 투약 후 며칠째별 평균. 밤의 날짜 이전(같은 날 포함) 가장 최근 투약일에서 센다. 7일 이상이면 넣지 않는다
    static func flow(nights: [SleepNight], doseDates: [Date], calendar: Calendar) -> [SleepFlowDay] {
        let doseDays = Set(doseDates.map { calendar.startOfDay(for: $0) }).sorted()
        var buckets: [Int: [SleepNight]] = [:]
        for night in nights {
            guard let doseDay = doseDays.last(where: { $0 <= night.day }),
                  let offset = calendar.dateComponents([.day], from: doseDay, to: night.day).day,
                  flowDays.contains(offset)
            else { continue }
            buckets[offset, default: []].append(night)
        }
        return flowDays.map { offset in
            let list = buckets[offset] ?? []
            guard let summary = summary(list, calendar: calendar) else {
                return SleepFlowDay(offset: offset, nights: 0, averageAsleepMinutes: nil, averageAwakenings: nil, averageWakeMinute: nil)
            }
            return SleepFlowDay(
                offset: offset,
                nights: summary.nights,
                averageAsleepMinutes: summary.averageAsleepMinutes,
                averageAwakenings: summary.averageAwakenings,
                averageWakeMinute: summary.averageWakeMinute
            )
        }
    }

    /// 밤들의 평균. 비어 있으면 nil
    static func summary(_ nights: [SleepNight], calendar: Calendar) -> SleepSummary? {
        guard !nights.isEmpty else { return nil }
        let count = Double(nights.count)
        let minutes = nights.reduce(0) { $0 + $1.asleepMinutes }
        let awakenings = nights.reduce(0) { $0 + $1.awakenings }
        let wake = nights.reduce(0) { total, night in
            let parts = calendar.dateComponents([.hour, .minute], from: night.wakeTime)
            return total + (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
        return SleepSummary(
            nights: nights.count,
            averageAsleepMinutes: Int((Double(minutes) / count).rounded()),
            averageAwakenings: (Double(awakenings) / count * 10).rounded() / 10,
            averageWakeMinute: Int((Double(wake) / count).rounded())
        )
    }

    /// 기간 안(일어난 날 기준)의 밤
    static func nights(_ nights: [SleepNight], in period: DateInterval) -> [SleepNight] {
        nights.filter { $0.day >= period.start && $0.day <= period.end }
    }

    /// 겹치거나 맞닿은 구간을 합친다
    private static func merge(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
        var result: [(Date, Date)] = []
        for interval in intervals.filter({ $0.1 > $0.0 }).sorted(by: { $0.0 < $1.0 }) {
            if let last = result.last, interval.0 <= last.1 {
                result[result.count - 1].1 = max(last.1, interval.1)
            } else {
                result.append(interval)
            }
        }
        return result
    }
}
