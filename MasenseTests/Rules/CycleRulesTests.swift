import Foundation
import Testing

@testable import Masense

// RULES.md R1·R2·R3
struct CycleRulesTests {
    private let calendar = TestCalendar.seoul
    private let thursday = 5

    /// 목요일 20:00, 7일 간격, 2026-10-16(금) 시작, 12회차
    private func prescription(start: Date = TestCalendar.date(2026, 10, 16, 9), totalDoses: Int = 12) -> PrescriptionSnapshot {
        PrescriptionSnapshot(
            startDate: start,
            intervalDays: 7,
            scheduledWeekday: thursday,
            scheduledHour: 20,
            scheduledMinute: 0,
            totalDoses: totalDoses
        )
    }

    private func dose(at date: Date, scheduledFor: Date, sequence: Int = 1, isCancelled: Bool = false) -> DoseSnapshot {
        DoseSnapshot(administeredAt: date, scheduledFor: scheduledFor, site: .abdomenUpperLeft, sequence: sequence, isCancelled: isCancelled)
    }

    // MARK: R1

    @Test func firstCycleIsNextThursdayWhenStartIsFriday() {
        let first = CycleRules.firstScheduledDate(for: prescription(), calendar: calendar)
        #expect(first == TestCalendar.date(2026, 10, 22, 20))
    }

    @Test func firstCycleIsSameDayWhenStartIsScheduledWeekday() {
        let p = prescription(start: TestCalendar.date(2026, 10, 22, 10))
        let first = CycleRules.firstScheduledDate(for: p, calendar: calendar)
        #expect(first == TestCalendar.date(2026, 10, 22, 20))
    }

    @Test func cycleIntervalStartsTwoDaysBeforeScheduledDate() throws {
        let now = TestCalendar.date(2026, 10, 16, 9)
        let cycles = CycleRules.cycles(for: prescription(), doses: [], now: now, until: .distantFuture, calendar: calendar)
        let first = try #require(cycles.first)
        #expect(first.index == 0)
        #expect(first.scheduledDate == TestCalendar.date(2026, 10, 22, 20))
        #expect(first.interval.start == TestCalendar.date(2026, 10, 20, 20))
        #expect(first.interval.end == TestCalendar.date(2026, 10, 27, 20))
        #expect(first.contains(TestCalendar.date(2026, 10, 20, 20)))
        #expect(!first.contains(TestCalendar.date(2026, 10, 27, 20)))
    }

    @Test func cyclesTileWithoutGapsAndStopAtTotalDoses() {
        let now = TestCalendar.date(2026, 10, 16, 9)
        let cycles = CycleRules.cycles(for: prescription(totalDoses: 12), doses: [], now: now, until: .distantFuture, calendar: calendar)
        #expect(cycles.count == 12)
        for (previous, next) in zip(cycles, cycles.dropFirst()) {
            #expect(previous.interval.end == next.interval.start)
            #expect(next.index == previous.index + 1)
        }
        #expect(cycles.last?.scheduledDate == TestCalendar.date(2027, 1, 7, 20))
    }

    @Test func cyclesCrossMonthAndYearBoundary() {
        // 2026-12-28(월) 시작 → 첫 마디 12-31(목), 다음 2027-01-07(목)
        let p = prescription(start: TestCalendar.date(2026, 12, 28), totalDoses: 2)
        let now = TestCalendar.date(2026, 12, 28)
        let cycles = CycleRules.cycles(for: p, doses: [], now: now, until: .distantFuture, calendar: calendar)
        #expect(cycles.map(\.scheduledDate) == [TestCalendar.date(2026, 12, 31, 20), TestCalendar.date(2027, 1, 7, 20)])
    }

    @Test func untilCapsScheduledDate() {
        let now = TestCalendar.date(2026, 10, 16, 9)
        let cycles = CycleRules.cycles(for: prescription(), doses: [], now: now, until: TestCalendar.date(2026, 11, 5, 20), calendar: calendar)
        #expect(cycles.map(\.scheduledDate) == [
            TestCalendar.date(2026, 10, 22, 20),
            TestCalendar.date(2026, 10, 29, 20),
            TestCalendar.date(2026, 11, 5, 20),
        ])
    }

    @Test func missedCyclesDoNotConsumeDoses() {
        // 2회차 처방, 두 마디를 모두 놓친 뒤의 시점 → 누락 2 + 예약 2 = 마디 4개
        let now = TestCalendar.date(2026, 11, 5, 9)
        let cycles = CycleRules.cycles(for: prescription(totalDoses: 2), doses: [], now: now, until: .distantFuture, calendar: calendar)
        #expect(cycles.count == 4)
        #expect(cycles.last?.scheduledDate == TestCalendar.date(2026, 11, 12, 20))
    }

    @Test func cancelledDosesDoNotConsume() {
        let now = TestCalendar.date(2026, 10, 23, 9)
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        let cancelled = dose(at: scheduled, scheduledFor: scheduled, isCancelled: true)
        let cycles = CycleRules.cycles(for: prescription(totalDoses: 1), doses: [cancelled], now: now, until: .distantFuture, calendar: calendar)
        #expect(cycles.count == 1)
        #expect(CycleRules.doses(in: cycles[0], from: [cancelled]).isEmpty)
    }

    @Test func invalidIntervalProducesNoCycles() {
        let p = PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16), intervalDays: 2, scheduledWeekday: thursday, scheduledHour: 20, totalDoses: 4)
        let cycles = CycleRules.cycles(for: p, doses: [], now: TestCalendar.date(2026, 10, 16), until: .distantFuture, calendar: calendar)
        #expect(cycles.isEmpty)
    }

    // MARK: R2

    @Test func dueBeforeFirstCycleWindowOpens() {
        let now = TestCalendar.date(2026, 10, 16, 9)
        let cycles = CycleRules.cycles(for: prescription(), doses: [], now: now, until: .distantFuture, calendar: calendar)
        guard case let .due(cycle, remaining)? = CycleRules.nextDose(cycles: cycles, doses: [], now: now) else {
            Issue.record("expected .due")
            return
        }
        #expect(cycle.index == 0)
        #expect(remaining == TestCalendar.date(2026, 10, 22, 20).timeIntervalSince(now))
    }

    @Test func dueSwitchesToOverdueAtScheduledDate() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        let cycles = CycleRules.cycles(for: prescription(), doses: [], now: scheduled, until: .distantFuture, calendar: calendar)

        let justBefore = scheduled.addingTimeInterval(-1)
        guard case .due? = CycleRules.nextDose(cycles: cycles, doses: [], now: justBefore) else {
            Issue.record("expected .due one second before")
            return
        }
        guard case let .overdue(cycle, elapsed)? = CycleRules.nextDose(cycles: cycles, doses: [], now: scheduled) else {
            Issue.record("expected .overdue at scheduled date")
            return
        }
        #expect(cycle.index == 0)
        #expect(elapsed == 0)
    }

    @Test func doneWhenCurrentCycleHasDose() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        let now = TestCalendar.date(2026, 10, 23, 9)
        let logged = dose(at: TestCalendar.date(2026, 10, 22, 20, 30), scheduledFor: scheduled)
        let cycles = CycleRules.cycles(for: prescription(), doses: [logged], now: now, until: .distantFuture, calendar: calendar)
        guard case let .done(cycle, next)? = CycleRules.nextDose(cycles: cycles, doses: [logged], now: now) else {
            Issue.record("expected .done")
            return
        }
        #expect(cycle.index == 0)
        #expect(next?.scheduledDate == TestCalendar.date(2026, 10, 29, 20))
    }

    @Test func nilAfterPrescriptionIsExhausted() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        let logged = dose(at: scheduled, scheduledFor: scheduled)
        let now = TestCalendar.date(2026, 10, 28, 9) // 유일한 마디 구간이 끝난 뒤
        let cycles = CycleRules.cycles(for: prescription(totalDoses: 1), doses: [logged], now: now, until: .distantFuture, calendar: calendar)
        #expect(cycles.count == 1)
        #expect(CycleRules.nextDose(cycles: cycles, doses: [logged], now: now) == nil)
    }

    // MARK: R3

    @Test func missedCycleIsComputedAndClearedByBackdatedDose() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        let now = TestCalendar.date(2026, 10, 30, 9)
        let cycles = CycleRules.cycles(for: prescription(), doses: [], now: now, until: .distantFuture, calendar: calendar)

        let missed = CycleRules.missedCycles(cycles: cycles, doses: [], now: now)
        #expect(missed.map(\.index) == [0])

        // "맞았는데 기록을 안 했다" → 과거 날짜로 추가하면 누락 해제
        let backdated = dose(at: TestCalendar.date(2026, 10, 23, 8), scheduledFor: scheduled)
        #expect(CycleRules.missedCycles(cycles: cycles, doses: [backdated], now: now).isEmpty)
    }

    @Test func currentCycleIsNotMissedUntilItEnds() {
        let now = TestCalendar.date(2026, 10, 25, 9) // 첫 마디 구간 안, 예정일 지남
        let cycles = CycleRules.cycles(for: prescription(), doses: [], now: now, until: .distantFuture, calendar: calendar)
        #expect(CycleRules.missedCycles(cycles: cycles, doses: [], now: now).isEmpty)
    }
}
