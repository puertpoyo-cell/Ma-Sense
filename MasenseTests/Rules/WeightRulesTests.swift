import Foundation
import Testing

@testable import Masense

// RULES.md R7. 달력은 일요일 시작. 2026-10-22(목)의 주는 10-18(일)부터.
struct WeightRulesTests {
    private let calendar = TestCalendar.seoul
    private let now = TestCalendar.date(2026, 10, 22, 12)

    private func sample(_ month: Int, _ day: Int, _ kg: Double, hour: Int = 8) -> WeightSampleSnapshot {
        WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, month, day, hour), kilograms: kg)
    }

    @Test func weeklyAveragesWithGapsAndSameDayAveraging() {
        let samples = [
            sample(10, 5, 80.0), sample(10, 5, 82.0, hour: 20), // 같은 날 → 81
            sample(10, 7, 83.0),                                // 주 평균 (81 + 83) / 2 = 82
            sample(10, 20, 79.5),
            sample(9, 1, 90.0),                                 // 범위 밖
        ]
        let series = WeightRules.weeklyWeightSeries(samples: samples, weeks: 3, now: now, calendar: calendar)

        #expect(series.map(\.weekStart) == [
            TestCalendar.date(2026, 10, 4),
            TestCalendar.date(2026, 10, 11),
            TestCalendar.date(2026, 10, 18),
        ])
        #expect(series[0].averageKg == 82.0)
        #expect(series[0].sampleCount == 3)
        #expect(series[1].averageKg == nil)
        #expect(series[1].sampleCount == 0)
        #expect(series[2].averageKg == 79.5)
        #expect(series[2].sampleCount == 1)
    }

    @Test func emptyInputs() {
        #expect(WeightRules.weeklyWeightSeries(samples: [], weeks: 0, now: now, calendar: calendar).isEmpty)
        let series = WeightRules.weeklyWeightSeries(samples: [], weeks: 2, now: now, calendar: calendar)
        #expect(series.count == 2)
        #expect(series.allSatisfy { $0.averageKg == nil })
    }

    @Test func latestSample() {
        let samples = [sample(10, 5, 80), sample(10, 20, 79.5), sample(10, 7, 83)]
        #expect(WeightRules.latestSample(samples)?.kilograms == 79.5)
        #expect(WeightRules.latestSample([]) == nil)
    }

    @Test func doseTicksWithinSeriesExcludeCancelledAndFuture() {
        let series = WeightRules.weeklyWeightSeries(samples: [], weeks: 2, now: now, calendar: calendar) // 10-11 ~
        func dose(_ day: Int, cancelled: Bool = false) -> DoseSnapshot {
            let date = TestCalendar.date(2026, 10, day, 20)
            return DoseSnapshot(administeredAt: date, scheduledFor: date, site: .thighLeft, sequence: day, isCancelled: cancelled)
        }
        let doses = [dose(15), dose(8), dose(22), dose(13, cancelled: true), dose(10)]
        // 10-8·10-10은 첫 주 전, 10-22 20시는 now(12시) 뒤, 10-13은 취소
        #expect(WeightRules.doseTicks(doses: doses, series: series, now: now) == [TestCalendar.date(2026, 10, 15, 20)])
        #expect(WeightRules.doseTicks(doses: doses, series: [], now: now).isEmpty)
    }

    // MARK: R14 BMI

    @Test func bmiIsKilogramsOverMetersSquaredRoundedToOneDecimal() {
        #expect(WeightRules.bmi(kilograms: 78.4, heightCm: 170) == 27.1)
        #expect(WeightRules.bmi(kilograms: 60, heightCm: 160) == 23.4)
        #expect(WeightRules.bmi(kilograms: 95.25, heightCm: 182.5) == 28.6)
    }

    @Test func bmiNeedsHeightInRangeAndPositiveWeight() {
        #expect(WeightRules.bmi(kilograms: 78.4, heightCm: nil) == nil)
        #expect(WeightRules.bmi(kilograms: 78.4, heightCm: 99) == nil)
        #expect(WeightRules.bmi(kilograms: 78.4, heightCm: 251) == nil)
        #expect(WeightRules.bmi(kilograms: 0, heightCm: 170) == nil)
        #expect(WeightRules.bmi(kilograms: 50, heightCm: 100) == 50.0)
        #expect(WeightRules.bmi(kilograms: 50, heightCm: 250) == 8.0)
    }

    /// D7 체중 추이 확대: 기간별 주 수, 하루 평균 점, 시작 대비 변화
    @Test func trendRangesDailyPointsAndChange() {
        let samples = [
            sample(8, 3, 84.0),
            sample(10, 5, 80.0), sample(10, 5, 82.0, hour: 20),
            sample(10, 20, 79.5),
        ]
        let recent = WeightRules.trend(samples: samples, range: .weeks4, now: now, calendar: calendar)
        #expect(recent.weeks.count == 4)
        #expect(recent.daily == [
            DailyWeight(day: TestCalendar.date(2026, 10, 5), kilograms: 81.0),
            DailyWeight(day: TestCalendar.date(2026, 10, 20), kilograms: 79.5),
        ])
        #expect(recent.changeText == "-1.5")

        // 전체: 8-3(월)의 주(8-2)부터 이번 주(10-18)까지 12주
        let all = WeightRules.trend(samples: samples, range: .all, now: now, calendar: calendar)
        #expect(all.weeks.first?.weekStart == TestCalendar.date(2026, 8, 2))
        #expect(all.weeks.count == 12)
        #expect(all.first?.kilograms == 84.0)
        #expect(all.changeText == "-4.5")

        #expect(WeightRules.trend(samples: samples, range: .months6, now: now, calendar: calendar).weeks.count == 26)
        // 측정일이 하루뿐이면 변화 없음, 기록이 없으면 전체도 4주
        #expect(WeightRules.trend(samples: [sample(10, 20, 79.5)], range: .weeks4, now: now, calendar: calendar).changeText == nil)
        #expect(WeightRules.trend(samples: [], range: .all, now: now, calendar: calendar).weeks.count == 4)
    }

    /// D11: 최근 기록이 없으면 그래프 끝을 마지막 측정으로 옮긴다
    @Test func seriesEndFallsBackToLastMeasurement() {
        // 6-20(토)은 6-14 주, 6-26(금)은 6-21 주
        let old = [sample(6, 20, 75.0), sample(6, 26, 76.0)]
        #expect(WeightRules.seriesEnd(samples: old, weeks: 8, now: now, calendar: calendar) == TestCalendar.date(2026, 6, 26, 8))
        let shifted = WeightRules.weeklyWeightSeries(samples: old, weeks: 8, now: TestCalendar.date(2026, 6, 26, 8), calendar: calendar)
        #expect(shifted.suffix(2).map(\.averageKg) == [75.0, 76.0])
        // 최근 8주 안에 하나라도 있으면 지금, 기록이 없으면 지금
        #expect(WeightRules.seriesEnd(samples: old + [sample(10, 1, 74.0)], weeks: 8, now: now, calendar: calendar) == now)
        #expect(WeightRules.seriesEnd(samples: [], weeks: 8, now: now, calendar: calendar) == now)
    }

    /// D11: 체지방률·제지방량을 같은 계산에 쓰고, 가장 최근 값을 고른다
    @Test func bodyMetricsUseTheSameSeries() {
        let samples = [
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 5, 8), kilograms: 80, leanBodyMassKg: 58.0, bodyFatPercent: 23.0),
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 12, 8), kilograms: 79.5, leanBodyMassKg: nil, bodyFatPercent: 22.4),
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 20, 8), kilograms: 79.0),
        ]
        #expect(WeightRules.metricSamples(samples, metric: .bodyFat).map(\.kilograms) == [23.0, 22.4])
        #expect(WeightRules.metricSamples(samples, metric: .weight).count == 3)
        #expect(WeightRules.latestReading(samples, metric: .bodyFat) == MetricReading(value: 22.4, measuredAt: TestCalendar.date(2026, 10, 12, 8)))
        #expect(WeightRules.latestReading(samples, metric: .leanMass)?.value == 58.0)
        let fat = WeightRules.trend(samples: WeightRules.metricSamples(samples, metric: .bodyFat), range: .weeks4, now: now, calendar: calendar)
        #expect(fat.changeText == "-0.6")
    }

    // D24 측정값을 이은 선: 측정이 없는 주가 끼면 끊는다. 일요일 시작 주
    @Test func lineSegmentsBreakOnlyAcrossEmptyWeek() {
        func day(_ m: Int, _ d: Int, _ kg: Double) -> DailyWeight {
            DailyWeight(day: TestCalendar.date(2026, m, d), kilograms: kg)
        }
        // 10-25(일)·10-27·10-30은 같은 주, 11-02(월)는 바로 다음 주 → 한 줄
        let joined = [day(10, 25, 79.2), day(10, 27, 78.0), day(10, 30, 77.0), day(11, 2, 76.8)]
        #expect(WeightRules.lineSegments(joined, calendar: calendar).map(\.count) == [4])
        // 10-05 주 다음 10-11 주가 비고 10-20 주 → 끊김
        let gapped = [day(10, 5, 81), day(10, 7, 83), day(10, 20, 79.5)]
        #expect(WeightRules.lineSegments(gapped, calendar: calendar).map(\.count) == [2, 1])
        // 정렬 안 된 입력도 시간순
        #expect(WeightRules.lineSegments(Array(gapped.reversed()), calendar: calendar).first?.first?.kilograms == 81)
        #expect(WeightRules.lineSegments([], calendar: calendar).isEmpty)
    }

    @Test func normalizedFitsEachSeriesToItsOwnRange() {
        #expect(WeightRules.normalized([79, 78, 77]) == [1, 0.5, 0])
        #expect(WeightRules.normalized([22.6, 22.6]) == [0.5, 0.5])
        #expect(WeightRules.normalized([]).isEmpty)
    }

    // D24-1 핀치: 벌리면 짧게, 오므리면 길게, 단계에 붙고 전체를 넘지 않는다
    @Test func pinchZoomSnapsToSteps() {
        #expect(WeightRules.zoomedWeeks(from: 12, magnification: 1, maxWeeks: 100) == 12)
        #expect(WeightRules.zoomedWeeks(from: 12, magnification: 1.5, maxWeeks: 100) == 8)
        #expect(WeightRules.zoomedWeeks(from: 12, magnification: 3, maxWeeks: 100) == 4)
        #expect(WeightRules.zoomedWeeks(from: 12, magnification: 10, maxWeeks: 100) == 2)
        #expect(WeightRules.zoomedWeeks(from: 12, magnification: 0.5, maxWeeks: 100) == 26)
        #expect(WeightRules.zoomedWeeks(from: 12, magnification: 0.05, maxWeeks: 100) == 100)
        // 기록이 10주뿐이면 12주 이상 단계는 없고 전체 10주가 끝
        #expect(WeightRules.zoomedWeeks(from: 8, magnification: 0.3, maxWeeks: 10) == 10)
        #expect(WeightRules.zoomedWeeks(from: 4, magnification: 0, maxWeeks: 10) == 4)
    }

    @Test func allWeeksSpansFromFirstRecordWithMinimumFour() {
        #expect(WeightRules.allWeeks(samples: [], now: now, calendar: calendar) == 4)
        #expect(WeightRules.allWeeks(samples: [sample(10, 20, 80)], now: now, calendar: calendar) == 4)
        // 9-01(화) 주(8-30)부터 10-18 주까지 7주 차이 → 7 + 1
        #expect(WeightRules.allWeeks(samples: [sample(9, 1, 80)], now: now, calendar: calendar) == 8)
    }
}
