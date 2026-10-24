import Foundation

/// 증상 하나의 주별 흐름 (R19, D9). 사용자가 기록한 강도 그대로, 해석 없음
struct SymptomFlow: Equatable, Identifiable {
    let symptom: Symptom
    /// 구간마다 가장 강하게 기록한 강도 (0 기록 없음, 1 약함, 2 보통, 3 심함), 오래된 구간부터
    let severities: [Int]

    var id: Symptom { symptom }
    /// 강도 1 이상으로 기록된 구간 수
    var recordedPeriods: Int { severities.filter { $0 > 0 }.count }
    var maxSeverity: Int { severities.max() ?? 0 }
}

/// R19 (D9). 최근 몇 주의 증상 기록을 증상별로 나란히. 판단·조언 없이 "물어볼 것"으로 옮길 수 있게만 한다
enum SymptomFlowRules {
    static let periodCount = 8

    /// 최근 `count`개 구간, 오래된 순. 구간은 R16과 같이 첫 예정일 0시부터 7일씩이고, 마지막은 지금 진행 중인 구간
    static func recentPeriods(prescription: PrescriptionSnapshot, now: Date, calendar: Calendar, count: Int = periodCount) -> [DateInterval] {
        guard count > 0,
              let first = CycleRules.firstScheduledDate(for: prescription, calendar: calendar)
        else { return [] }
        let firstDay = calendar.startOfDay(for: first)
        guard now >= firstDay,
              let days = calendar.dateComponents([.day], from: firstDay, to: calendar.startOfDay(for: now)).day
        else { return [] }
        let current = days / CycleRules.intervalDays
        return (max(0, current - count + 1)...current).compactMap { index in
            guard let start = calendar.date(byAdding: .day, value: CycleRules.intervalDays * index, to: firstDay),
                  let end = calendar.date(byAdding: .day, value: CycleRules.intervalDays * (index + 1), to: firstDay)
            else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

    /// 강도 1 이상으로 한 번이라도 기록된 증상만. 기록된 구간이 많은 순, 같으면 증상 목록 순
    static func flows(periods: [DateInterval], checks: [ConditionCheckSnapshot]) -> [SymptomFlow] {
        let byPeriod = periods.map { period in
            checks.filter { $0.checkedAt >= period.start && $0.checkedAt < period.end }
        }
        return Symptom.allCases
            .map { symptom in
                SymptomFlow(symptom: symptom, severities: byPeriod.map { periodChecks in
                    periodChecks
                        .flatMap(\.symptoms)
                        .filter { $0.symptom == symptom }
                        .map(\.severity)
                        .max() ?? 0
                })
            }
            .filter { $0.recordedPeriods > 0 }
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.recordedPeriods != rhs.element.recordedPeriods
                    ? lhs.element.recordedPeriods > rhs.element.recordedPeriods
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
