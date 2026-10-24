import Foundation
import Testing

@testable import Masense

// R19 증상 흐름 (D9). 목요일 20:00, 2026-10-16(금) 시작 → 첫 예정 10-22(목)
struct SymptomFlowRulesTests {
    private let calendar = TestCalendar.seoul

    private func prescription() -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, totalDoses: 12)
    }

    private func week(_ index: Int) -> DateInterval {
        let start = calendar.date(byAdding: .day, value: 7 * index, to: TestCalendar.date(2026, 10, 22))!
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
    }

    @Test func recentPeriodsEndWithTheCurrentWeek() {
        let now = TestCalendar.date(2026, 11, 5, 10)
        #expect(SymptomFlowRules.recentPeriods(prescription: prescription(), now: now, calendar: calendar) == [week(0), week(1), week(2)])
        #expect(SymptomFlowRules.recentPeriods(prescription: prescription(), now: now, calendar: calendar, count: 2) == [week(1), week(2)])
        #expect(SymptomFlowRules.recentPeriods(prescription: prescription(), now: TestCalendar.date(2026, 10, 21, 23), calendar: calendar).isEmpty)
    }

    @Test func flowsKeepRecordedSeverityPerWeek() {
        let doseID = UUID()
        let checks = [
            ConditionCheckSnapshot(doseID: doseID, window: .h24, checkedAt: TestCalendar.date(2026, 10, 23, 20),
                                   symptoms: [SymptomEntry(symptom: .nausea, severity: 2), SymptomEntry(symptom: .fatigue, severity: 1)]),
            ConditionCheckSnapshot(doseID: doseID, window: .h48, checkedAt: TestCalendar.date(2026, 10, 24, 20),
                                   symptoms: [SymptomEntry(symptom: .nausea, severity: 1)]),
            ConditionCheckSnapshot(doseID: doseID, window: .h24, checkedAt: TestCalendar.date(2026, 11, 6, 20),
                                   symptoms: [SymptomEntry(symptom: .nausea, severity: 3), SymptomEntry(symptom: .headache, severity: 0),
                                              SymptomEntry(symptom: .constipation, severity: 1)]),
            // 구간 밖
            ConditionCheckSnapshot(doseID: doseID, window: .h24, checkedAt: TestCalendar.date(2026, 11, 13, 20),
                                   symptoms: [SymptomEntry(symptom: .dizziness, severity: 2)]),
        ]
        let flows = SymptomFlowRules.flows(periods: [week(0), week(1), week(2)], checks: checks)
        #expect(flows.map(\.symptom) == [.nausea, .constipation, .fatigue])
        #expect(flows.first?.severities == [2, 0, 3])
        #expect(flows.first?.recordedPeriods == 2)
        #expect(flows.first?.maxSeverity == 3)
        #expect(flows.last?.severities == [1, 0, 0])
        #expect(SymptomFlowRules.flows(periods: [], checks: checks).isEmpty)
    }
}
