import Foundation
import Testing

@testable import Masense

// R16 주간 정리 (D8). 목요일 20:00, 2026-10-16(금) 시작 → 첫 예정 10-22(목)
struct WeeklySummaryRulesTests {
    private let calendar = TestCalendar.seoul

    private func prescription() -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, totalDoses: 12)
    }

    @Test func periodsStartOnDoseDayAndOnlyFinishedOnes() {
        // 10-29 09:00: 10-22 ~ 10-29 구간이 막 끝났다
        let periods = WeeklySummaryRules.finishedPeriods(prescription: prescription(), now: TestCalendar.date(2026, 10, 29, 9), calendar: calendar)
        #expect(periods == [DateInterval(start: TestCalendar.date(2026, 10, 22), end: TestCalendar.date(2026, 10, 29))])
        #expect(WeeklySummaryRules.finishedPeriods(prescription: prescription(), now: TestCalendar.date(2026, 10, 28, 23), calendar: calendar).isEmpty)
        // 최근 순, 개수 제한. 12-31 0시에 12-24 ~ 12-31 구간이 끝난다
        let many = WeeklySummaryRules.finishedPeriods(prescription: prescription(), now: TestCalendar.date(2026, 12, 31), calendar: calendar, limit: 3)
        #expect(many.map(\.start) == [TestCalendar.date(2026, 12, 24), TestCalendar.date(2026, 12, 17), TestCalendar.date(2026, 12, 10)])
    }

    @Test func summaryCountsFactsInsidePeriod() {
        let period = DateInterval(start: TestCalendar.date(2026, 10, 22), end: TestCalendar.date(2026, 10, 29))
        let dose = DoseSnapshot(administeredAt: TestCalendar.date(2026, 10, 22, 20), scheduledFor: TestCalendar.date(2026, 10, 22, 20), site: .thighLeft, sequence: 1)
        let cancelled = DoseSnapshot(administeredAt: TestCalendar.date(2026, 10, 23, 20), scheduledFor: TestCalendar.date(2026, 10, 22, 20), site: .thighLeft, sequence: 2, isCancelled: true)
        let checks = [
            ConditionCheckSnapshot(doseID: dose.id, window: .h24, checkedAt: TestCalendar.date(2026, 10, 23, 20),
                                   symptoms: [SymptomEntry(symptom: .nausea, severity: 2), SymptomEntry(symptom: .fatigue, severity: 1)]),
            ConditionCheckSnapshot(doseID: dose.id, window: .h48, checkedAt: TestCalendar.date(2026, 10, 24, 20),
                                   symptoms: [SymptomEntry(symptom: .nausea, severity: 1), SymptomEntry(symptom: .headache, severity: 0)]),
        ]
        let weights = [
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 21, 8), kilograms: 82.0), // 구간 밖
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 23, 8), kilograms: 81.2),
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 28, 8), kilograms: 80.8),
        ]
        let proteins = [
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 23), meal: .breakfast, foods: [.egg], estimatedGrams: 60),
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 23), meal: .lunch, foods: [.tofu], estimatedGrams: 50),
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 25), meal: .lunch, foods: [.tofu], estimatedGrams: 30),
        ]
        let sessions = [
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 24, 7), durationMinutes: 20, kind: .strength),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 25, 7), durationMinutes: 30, kind: .walk),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 29, 7), durationMinutes: 20, kind: .strength), // 구간 밖
        ]
        let summary = WeeklySummaryRules.summary(
            period: period, doses: [dose, cancelled], checks: checks, weights: weights,
            proteins: proteins, sessions: sessions, proteinTarget: 100, calendar: calendar
        )
        #expect(summary.doseCount == 1)
        #expect(summary.conditionCheckCount == 2)
        #expect(summary.topSymptoms == [
            WeeklySummary.SymptomCount(symptom: .nausea, count: 2),
            WeeklySummary.SymptomCount(symptom: .fatigue, count: 1),
        ])
        #expect(summary.weightCount == 2)
        #expect(summary.weightChangeText == "-0.4")
        #expect(summary.proteinDays == 2)
        #expect(summary.proteinMetDays == 1)
        #expect(summary.strengthCount == 1)
        #expect(summary.lightActivityCount == 1)
        #expect(!summary.isEmpty)

        let empty = WeeklySummaryRules.summary(period: period, doses: [], checks: [], weights: [], proteins: [], sessions: [], proteinTarget: nil, calendar: calendar)
        #expect(empty.isEmpty)
        #expect(empty.proteinMetDays == nil)
        #expect(empty.weightChangeText == nil)
    }
}
