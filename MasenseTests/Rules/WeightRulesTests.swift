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
}
