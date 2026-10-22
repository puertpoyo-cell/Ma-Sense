import Foundation
import Testing

@testable import Masense

// RULES.md R13
struct PrescriptionRulesTests {
    private let calendar = TestCalendar.seoul

    private func prescription(totalDoses: Int = 12) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, dosesPerPen: 4, totalDoses: totalDoses)
    }

    private func dose(_ month: Int, _ day: Int, isCancelled: Bool = false) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, 20)
        return DoseSnapshot(administeredAt: date, scheduledFor: date, site: .abdomenLowerLeft, sequence: 1, isCancelled: isCancelled)
    }

    @Test func remainingAndSequence() {
        let doses = [dose(10, 22), dose(10, 29), dose(11, 5, isCancelled: true)]
        #expect(PrescriptionRules.usedDoses(doses) == 2)
        #expect(PrescriptionRules.remainingDoses(p: prescription(), doses: doses) == 10)
        #expect(PrescriptionRules.nextSequence(doses: doses) == 3)
        #expect(PrescriptionRules.remainingDoses(p: prescription(totalDoses: 1), doses: doses) == 0)
    }

    @Test func penPosition() {
        #expect(PrescriptionRules.penPosition(sequence: 1, dosesPerPen: 4) == (pen: 1, position: 1))
        #expect(PrescriptionRules.penPosition(sequence: 4, dosesPerPen: 4) == (pen: 1, position: 4))
        #expect(PrescriptionRules.penPosition(sequence: 5, dosesPerPen: 4) == (pen: 2, position: 1))
        #expect(PrescriptionRules.penPosition(sequence: 3, dosesPerPen: 0) == (pen: 1, position: 3))
    }

    @Test func exhaustionEstimateIsLastCycle() {
        let now = TestCalendar.date(2026, 10, 16, 9)
        #expect(PrescriptionRules.exhaustionEstimate(p: prescription(), doses: [], now: now, calendar: calendar) == TestCalendar.date(2027, 1, 7, 20))
    }

    @Test func exhaustionEstimateShiftsWithMissedCycles() {
        // 2회차, 두 마디 누락 뒤 → 11-05, 11-12에 쓰므로 소진 예상 11-12
        let now = TestCalendar.date(2026, 11, 5, 9)
        #expect(PrescriptionRules.exhaustionEstimate(p: prescription(totalDoses: 2), doses: [], now: now, calendar: calendar) == TestCalendar.date(2026, 11, 12, 20))
    }

    @Test func exhaustionEstimateIsNilWhenNothingRemains() {
        let now = TestCalendar.date(2026, 10, 23, 9)
        #expect(PrescriptionRules.exhaustionEstimate(p: prescription(totalDoses: 1), doses: [dose(10, 22)], now: now, calendar: calendar) == nil)
    }
}
