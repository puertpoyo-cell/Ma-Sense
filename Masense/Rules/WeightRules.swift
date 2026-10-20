import Foundation

/// 주 단위 체중 점. 샘플 없는 주는 `averageKg == nil`로 두고 선을 끊는다 (보간 금지).
struct WeekPoint: Equatable {
    let weekStart: Date
    let averageKg: Double?
    let sampleCount: Int
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

    /// 가장 최근 샘플 (홈 1-3 카드)
    static func latestSample(_ samples: [WeightSampleSnapshot]) -> WeightSampleSnapshot? {
        samples.max { $0.measuredAt < $1.measuredAt }
    }
}
