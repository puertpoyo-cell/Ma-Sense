import Foundation
import Testing

@testable import Masense

// RULES.md R3-1 지난 투약 한꺼번에 입력 (D6)
struct BackfillRulesTests {
    private let calendar = TestCalendar.seoul
    /// 2026-10-23(금) 10:00. 10-22(목) 마디가 지금 마디
    private let now = TestCalendar.date(2026, 10, 23, 10)

    /// 목요일 20:00, 2026-09-24(목) 시작. 마디 9-24, 10-1, 10-8, 10-15는 구간이 끝났다
    private func prescription(totalDoses: Int = 8) -> PrescriptionSnapshot {
        PrescriptionSnapshot(
            startDate: TestCalendar.date(2026, 9, 24, 9),
            scheduledWeekday: 5,
            scheduledHour: 20,
            totalDoses: totalDoses
        )
    }

    private func dose(_ month: Int, _ day: Int, sequence: Int, isCancelled: Bool = false) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, 20, 30)
        return DoseSnapshot(administeredAt: date, scheduledFor: date, site: .thighLeft, sequence: sequence, isCancelled: isCancelled)
    }

    @Test func candidatesAreMissedCyclesOfThePrescription() {
        let doses = [dose(10, 8, sequence: 1)]
        let candidates = BackfillRules.candidates(prescription: prescription(), doses: doses, now: now, calendar: calendar)
        #expect(candidates.map(\.scheduledDate) == [
            TestCalendar.date(2026, 9, 24, 20),
            TestCalendar.date(2026, 10, 1, 20),
            TestCalendar.date(2026, 10, 15, 20),
        ])
        // 첫 기록(10-8)보다 앞선 누락만 "앱을 쓰기 전" 안내에 센다
        #expect(BackfillRules.leadingCount(candidates: candidates, doses: doses) == 2)
        #expect(BackfillRules.leadingCount(candidates: candidates, doses: []) == 3)
        // 취소된 기록은 첫 기록으로 보지 않는다
        #expect(BackfillRules.leadingCount(candidates: candidates, doses: [dose(9, 24, sequence: 1, isCancelled: true)]) == 3)
    }

    @Test func defaultSelectionKeepsWithinRemainingDosesFromTheLatest() {
        let candidates = BackfillRules.candidates(prescription: prescription(totalDoses: 2), doses: [], now: now, calendar: calendar)
        #expect(candidates.count == 4)
        #expect(BackfillRules.defaultSelection(candidates: candidates, remaining: 2) == [2, 3])
        #expect(BackfillRules.defaultSelection(candidates: candidates, remaining: 8) == [0, 1, 2, 3])
        #expect(BackfillRules.defaultSelection(candidates: candidates, remaining: 0).isEmpty)
    }

    @Test func planNumbersChronologicallyAndShiftsLaterRecords() {
        let october8 = dose(10, 8, sequence: 1)
        let october22 = dose(10, 22, sequence: 2)
        let cancelled = dose(10, 16, sequence: 3, isCancelled: true)
        let plan = BackfillRules.plan(
            selected: [TestCalendar.date(2026, 10, 1, 20), TestCalendar.date(2026, 9, 24, 20)],
            doses: [october22, october8, cancelled]
        )
        #expect(plan.entries == [
            BackfillRules.Entry(scheduledDate: TestCalendar.date(2026, 9, 24, 20), sequence: 1),
            BackfillRules.Entry(scheduledDate: TestCalendar.date(2026, 10, 1, 20), sequence: 2),
        ])
        // 취소된 기록은 회차를 바꾸지 않는다
        #expect(plan.renumbered == [october8.id: 3, october22.id: 4])
    }

    @Test func planBetweenRecordsShiftsOnlyLaterOnes() {
        let october8 = dose(10, 8, sequence: 1)
        let october22 = dose(10, 22, sequence: 2)
        let plan = BackfillRules.plan(selected: [TestCalendar.date(2026, 10, 15, 20)], doses: [october8, october22])
        #expect(plan.entries == [BackfillRules.Entry(scheduledDate: TestCalendar.date(2026, 10, 15, 20), sequence: 2)])
        #expect(plan.renumbered == [october22.id: 3])
        #expect(BackfillRules.plan(selected: [], doses: [october8]) == BackfillRules.Plan(entries: [], renumbered: [:]))
    }
}
