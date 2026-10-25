import Foundation

/// 주 단위 체중 점. 샘플 없는 주는 `averageKg == nil`로 두고 선을 끊는다 (보간 금지).
struct WeekPoint: Equatable {
    let weekStart: Date
    let averageKg: Double?
    let sampleCount: Int
}

/// 체중 확대 그래프 기간 (D7)
enum WeightTrendRange: String, CaseIterable, Hashable {
    case weeks4, weeks12, months6, all

    /// 주 수. 전체는 nil (첫 기록이 있는 주부터)
    var weeks: Int? {
        switch self {
        case .weeks4: return 4
        case .weeks12: return 12
        case .months6: return 26
        case .all: return nil
        }
    }
}

/// 하루 평균 체중 (확대 그래프의 점)
struct DailyWeight: Equatable, Identifiable {
    let day: Date
    let kilograms: Double
    var id: Date { day }
}

/// 체중 확대 그래프 (D7). 판단·목표선 없이 측정값과 주 평균, 시작 대비 변화 숫자만
struct WeightTrend: Equatable {
    let weeks: [WeekPoint]
    let daily: [DailyWeight]

    var first: DailyWeight? { daily.first }
    var last: DailyWeight? { daily.last }

    /// 기간 첫 측정일 대비 마지막 측정일, 소수 1자리 부호 그대로 ("-3.2", "+0.4", "0.0"). 측정일이 2일 미만이면 nil
    var changeText: String? {
        guard daily.count >= 2, let first, let last else { return nil }
        return ReportBuilder.signedKilograms(last.kilograms - first.kilograms)
    }
}

/// 체중 추이에서 고를 수 있는 값 (D11). 숫자만, 구간 이름·판단 없음 (COMPLIANCE.md 2.2)
enum BodyMetric: String, CaseIterable, Hashable {
    case weight, bodyFat, leanMass

    func value(of sample: WeightSampleSnapshot) -> Double? {
        switch self {
        case .weight: return sample.kilograms
        case .bodyFat: return sample.bodyFatPercent
        case .leanMass: return sample.leanBodyMassKg
        }
    }
}

/// 가장 최근 측정 하나 (D11 체지방률·제지방량 셀)
struct MetricReading: Equatable {
    let value: Double
    let measuredAt: Date
}

/// R7. 체중 추이.
enum WeightRules {
    /// 최근 `weeks`주의 주 평균. 오래된 주부터. 같은 날 여러 샘플은 먼저 하루 평균으로 묶은 뒤 주 평균을 낸다.
    static func weeklyWeightSeries(
        samples: [WeightSampleSnapshot],
        weeks: Int,
        now: Date,
        calendar: Calendar
    ) -> [WeekPoint] {
        guard weeks > 0,
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)
        else { return [] }

        let weekStarts: [Date] = (0..<weeks).reversed().compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek.start)
        }
        guard let seriesStart = weekStarts.first else { return [] }

        // 날짜(일) → 그날 샘플 평균
        var dailyAverages: [Date: Double] = [:]
        var dailyCounts: [Date: Int] = [:]
        for sample in samples where sample.measuredAt >= seriesStart && sample.measuredAt < currentWeek.end {
            let day = calendar.startOfDay(for: sample.measuredAt)
            let count = dailyCounts[day, default: 0]
            let previous = dailyAverages[day, default: 0]
            dailyAverages[day] = (previous * Double(count) + sample.kilograms) / Double(count + 1)
            dailyCounts[day] = count + 1
        }

        return weekStarts.map { weekStart in
            guard let week = calendar.dateInterval(of: .weekOfYear, for: weekStart) else {
                return WeekPoint(weekStart: weekStart, averageKg: nil, sampleCount: 0)
            }
            let days = dailyAverages.keys.filter { $0 >= week.start && $0 < week.end }
            guard !days.isEmpty else {
                return WeekPoint(weekStart: weekStart, averageKg: nil, sampleCount: 0)
            }
            let average = days.reduce(0) { $0 + dailyAverages[$1, default: 0] } / Double(days.count)
            let count = days.reduce(0) { $0 + dailyCounts[$1, default: 0] }
            return WeekPoint(weekStart: weekStart, averageKg: average, sampleCount: count)
        }
    }

    /// 체중 차트의 투약일 눈금 (DESIGN_SYSTEM.md 5.5). 시리즈 첫 주 시작부터 `now`까지, 취소한 기록 제외, 시간순
    static func doseTicks(doses: [DoseSnapshot], series: [WeekPoint], now: Date) -> [Date] {
        guard let start = series.first?.weekStart else { return [] }
        return doses
            .filter { !$0.isCancelled && $0.administeredAt >= start && $0.administeredAt <= now }
            .map(\.administeredAt)
            .sorted()
    }

    // MARK: D7 체중 추이 확대

    /// 확대 그래프 기간. 전체는 첫 기록이 있는 주부터 (최소 4주)
    static func trend(samples: [WeightSampleSnapshot], range: WeightTrendRange, now: Date, calendar: Calendar) -> WeightTrend {
        let weeks: Int
        if let fixed = range.weeks {
            weeks = fixed
        } else if let earliest = samples.map(\.measuredAt).min(),
                  let firstWeek = calendar.dateInterval(of: .weekOfYear, for: earliest),
                  let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now) {
            let span = calendar.dateComponents([.weekOfYear], from: firstWeek.start, to: currentWeek.start).weekOfYear ?? 0
            weeks = max(span + 1, 4)
        } else {
            weeks = 4
        }
        let series = weeklyWeightSeries(samples: samples, weeks: weeks, now: now, calendar: calendar)
        guard let start = series.first?.weekStart else { return WeightTrend(weeks: [], daily: []) }

        // 하루 평균 (같은 날 여러 번 재면 평균)
        let grouped = Dictionary(grouping: samples.filter { $0.measuredAt >= start && $0.measuredAt <= now }) {
            calendar.startOfDay(for: $0.measuredAt)
        }
        let daily = grouped
            .map { day, items in DailyWeight(day: day, kilograms: items.reduce(0) { $0 + $1.kilograms } / Double(items.count)) }
            .sorted { $0.day < $1.day }
        return WeightTrend(weeks: series, daily: daily)
    }

    // MARK: D11 체성분·마지막 기록 구간

    /// 그 값이 있는 샘플만, 값을 `kilograms` 자리에 넣은 사본. 주 평균·추이 계산을 체중과 같은 함수로 하기 위해서다
    static func metricSamples(_ samples: [WeightSampleSnapshot], metric: BodyMetric) -> [WeightSampleSnapshot] {
        samples.compactMap { sample in
            metric.value(of: sample).map {
                WeightSampleSnapshot(measuredAt: sample.measuredAt, kilograms: $0, source: sample.source)
            }
        }
    }

    /// 그 값이 있는 가장 최근 측정
    static func latestReading(_ samples: [WeightSampleSnapshot], metric: BodyMetric) -> MetricReading? {
        samples
            .compactMap { sample in metric.value(of: sample).map { MetricReading(value: $0, measuredAt: sample.measuredAt) } }
            .max { $0.measuredAt < $1.measuredAt }
    }

    /// 그래프의 끝. 최근 `weeks`주에 측정이 있으면 `now`, 없으면 마지막 측정 시각.
    /// 오래 재지 않았을 때 빈 그래프 대신 마지막 기록 구간을 보인다 (D11, 화면에 "n. n.까지 기록")
    static func seriesEnd(samples: [WeightSampleSnapshot], weeks: Int, now: Date, calendar: Calendar) -> Date {
        guard let latest = samples.map(\.measuredAt).filter({ $0 <= now }).max() else { return now }
        let series = weeklyWeightSeries(samples: samples, weeks: weeks, now: now, calendar: calendar)
        return series.contains { $0.averageKg != nil } ? now : latest
    }

    /// 가장 최근 샘플 (홈 1-3 카드)
    static func latestSample(_ samples: [WeightSampleSnapshot]) -> WeightSampleSnapshot? {
        samples.max { $0.measuredAt < $1.measuredAt }
    }

    // MARK: R14 BMI (D5)

    /// BMI 계산에 쓰는 키 범위 (cm). 밖이면 입력 실수로 보고 계산하지 않는다
    static let bmiHeightRangeCm: ClosedRange<Double> = 100...250

    /// BMI = kg / m², 소수 1자리 반올림. 숫자만 돌려준다. 구간 이름(저체중·비만 등)으로 판단하지 않는다 (COMPLIANCE.md 2.2).
    /// 키가 없거나 범위 밖이거나 체중이 0 이하면 nil
    static func bmi(kilograms: Double, heightCm: Double?) -> Double? {
        guard let heightCm, bmiHeightRangeCm.contains(heightCm), kilograms > 0 else { return nil }
        let meters = heightCm / 100
        return (kilograms / (meters * meters) * 10).rounded() / 10
    }
}
