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
        trend(samples: samples, weeks: range.weeks ?? allWeeks(samples: samples, now: now, calendar: calendar), now: now, calendar: calendar)
    }

    /// 전체 기간의 주 수. 첫 기록이 있는 주부터 `now`의 주까지, 최소 4주
    static func allWeeks(samples: [WeightSampleSnapshot], now: Date, calendar: Calendar) -> Int {
        guard let earliest = samples.map(\.measuredAt).min(),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: earliest),
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)
        else { return 4 }
        let span = calendar.dateComponents([.weekOfYear], from: firstWeek.start, to: currentWeek.start).weekOfYear ?? 0
        return max(span + 1, 4)
    }

    /// 주 수로 정한 추이 (D24 핀치 확대·축소)
    static func trend(samples: [WeightSampleSnapshot], weeks: Int, now: Date, calendar: Calendar) -> WeightTrend {
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

    // MARK: D24 측정값을 이은 선·겹쳐 보기 (2026-10-30 사람 요청 "그래프로 보여 줘야지 추이가")

    /// 하루 측정값을 선으로 이을 구간. 두 측정 사이에 측정이 하나도 없는 주가 끼면 선을 끊는다 (R7 보간 금지와 같은 기준)
    static func lineSegments(_ daily: [DailyWeight], calendar: Calendar) -> [[DailyWeight]] {
        var segments: [[DailyWeight]] = []
        var previousWeek: Date?
        for point in daily.sorted(by: { $0.day < $1.day }) {
            let week = calendar.dateInterval(of: .weekOfYear, for: point.day)?.start ?? point.day
            if let previousWeek,
               let next = calendar.date(byAdding: .weekOfYear, value: 1, to: previousWeek),
               week <= next, !segments.isEmpty {
                segments[segments.count - 1].append(point)
            } else {
                segments.append([point])
            }
            previousWeek = week
        }
        return segments
    }

    /// 단위가 다른 값(kg, %)을 한 그래프에 겹칠 때 각자 자기 범위로 0...1에 맞춘다.
    /// 모두 같은 값이면 가운데(0.5). 높낮이의 모양만 비교하고 크기는 비교하지 않는다
    static func normalized(_ values: [Double]) -> [Double] {
        guard let low = values.min(), let high = values.max() else { return [] }
        guard high > low else { return values.map { _ in 0.5 } }
        return values.map { ($0 - low) / (high - low) }
    }

    /// D24-1 핀치로 고르는 가로 기간 단계 (주). 마지막 단계는 전체(`allWeeks`)
    static let zoomSteps = [2, 4, 8, 12, 26, 52]

    /// 핀치 배율로 다음 기간. 벌리면(배율 > 1) 짧게, 오므리면 길게. 단계 중 로그 거리로 가장 가까운 것에 붙는다.
    /// `maxWeeks`(전체)보다 긴 단계는 빼고 전체를 마지막 단계로 둔다
    static func zoomedWeeks(from base: Int, magnification: Double, maxWeeks: Int) -> Int {
        let candidates = zoomSteps.filter { $0 < maxWeeks } + [max(maxWeeks, zoomSteps[0])]
        guard magnification > 0, base > 0 else { return min(base, candidates.last ?? base) }
        let target = log(Double(base) / magnification)
        return candidates.min { abs(log(Double($0)) - target) < abs(log(Double($1)) - target) } ?? base
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
