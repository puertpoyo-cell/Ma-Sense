import Foundation

/// 주간 정리 한 장 (R16, D8). 사실·숫자만. 평가어·지난주와의 비교·목표 대비 없음
struct WeeklySummary: Equatable, Identifiable {
    struct SymptomCount: Equatable {
        let symptom: Symptom
        let count: Int
    }

    /// [투약 요일 0시, +7일)
    let period: DateInterval
    let doseCount: Int
    let conditionCheckCount: Int
    /// 강도 1 이상으로 기록된 증상, 많은 순 최대 2개
    let topSymptoms: [SymptomCount]
    let weightCount: Int
    /// 구간 첫 측정 대비 마지막 측정, 부호 그대로. 측정이 2회 미만이면 nil
    let weightChangeText: String?
    let proteinDays: Int
    /// 단백질 목표가 있을 때만 채운 날 수 (R9)
    let proteinMetDays: Int?
    let strengthCount: Int
    /// 걷기 + 스트레칭
    let lightActivityCount: Int

    var id: Date { period.start }

    var isEmpty: Bool {
        doseCount == 0 && conditionCheckCount == 0 && weightCount == 0 && proteinDays == 0
            && strengthCount == 0 && lightActivityCount == 0
    }
}

/// R16 (D8). 활성 처방의 투약 요일부터 7일을 한 구간으로 끊어 정리한다
enum WeeklySummaryRules {
    static let maxTopSymptoms = 2

    /// 끝난 구간, 최근 순 최대 `limit`개. 첫 구간은 처방의 첫 예정일(R1)이 있는 날부터
    static func finishedPeriods(prescription: PrescriptionSnapshot, now: Date, calendar: Calendar, limit: Int = 12) -> [DateInterval] {
        guard limit > 0,
              let first = CycleRules.firstScheduledDate(for: prescription, calendar: calendar)
        else { return [] }
        let firstDay = calendar.startOfDay(for: first)
        var periods: [DateInterval] = []
        var index = 0
        while let start = calendar.date(byAdding: .day, value: 7 * index, to: firstDay),
              let end = calendar.date(byAdding: .day, value: 7 * (index + 1), to: firstDay),
              end <= now {
            periods.append(DateInterval(start: start, end: end))
            index += 1
        }
        return Array(periods.suffix(limit).reversed())
    }

    static func summary(
        period: DateInterval,
        doses: [DoseSnapshot],
        checks: [ConditionCheckSnapshot],
        weights: [WeightSampleSnapshot],
        proteins: [ProteinEntrySnapshot],
        sessions: [StrengthSessionSnapshot],
        proteinTarget: Int?,
        calendar: Calendar
    ) -> WeeklySummary {
        let inPeriod = { (date: Date) in date >= period.start && date < period.end }
        let periodChecks = checks.filter { inPeriod($0.checkedAt) }

        var symptomCounts: [Symptom: Int] = [:]
        for check in periodChecks {
            for entry in check.symptoms where entry.severity > 0 {
                symptomCounts[entry.symptom, default: 0] += 1
            }
        }
        let order = Dictionary(uniqueKeysWithValues: Symptom.allCases.enumerated().map { ($1, $0) })
        let topSymptoms = symptomCounts
            .map { WeeklySummary.SymptomCount(symptom: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : (order[$0.symptom] ?? 0) < (order[$1.symptom] ?? 0) }
            .prefix(maxTopSymptoms)

        let periodWeights = weights.filter { inPeriod($0.measuredAt) }.sorted { $0.measuredAt < $1.measuredAt }
        var weightChange: String?
        if periodWeights.count >= 2, let first = periodWeights.first, let last = periodWeights.last {
            weightChange = ReportBuilder.signedKilograms(last.kilograms - first.kilograms)
        }

        let proteinByDay = Dictionary(grouping: proteins.filter { inPeriod($0.date) }) { calendar.startOfDay(for: $0.date) }
        var metDays: Int?
        if let target = proteinTarget, target > 0 {
            metDays = proteinByDay.values.filter { $0.reduce(0) { $0 + $1.estimatedGrams } >= target }.count
        }

        let periodSessions = sessions.filter { inPeriod($0.startedAt) }
        return WeeklySummary(
            period: period,
            doseCount: doses.filter { !$0.isCancelled && inPeriod($0.administeredAt) }.count,
            conditionCheckCount: periodChecks.count,
            topSymptoms: Array(topSymptoms),
            weightCount: periodWeights.count,
            weightChangeText: weightChange,
            proteinDays: proteinByDay.count,
            proteinMetDays: metDays,
            strengthCount: periodSessions.filter { $0.kind == .strength }.count,
            lightActivityCount: periodSessions.filter { $0.kind == .walk || $0.kind == .stretch }.count
        )
    }
}
