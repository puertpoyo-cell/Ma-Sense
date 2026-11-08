import Foundation
import Testing

@testable import Masense

// D45 투약 일정 옮기기
struct ScheduleShiftRulesTests {
    private let calendar = TestCalendar.seoul
    private func d(_ m: Int, _ day: Int, _ h: Int = 0) -> Date { TestCalendar.date(2026, m, day, h) }

    /// 11/1(일) 시작, 일요일 20시
    private let sunday = PrescriptionSnapshot(startDate: TestCalendar.date(2026, 11, 1), scheduledWeekday: 1, scheduledHour: 20, totalDoses: 8)

    private func dose(_ date: Date, _ sequence: Int) -> DoseSnapshot {
        DoseSnapshot(administeredAt: date, scheduledFor: date, site: nil, sequence: sequence)
    }

    @Test func offsetFromScheduledDay() {
        let doses = [dose(d(11, 1, 20), 1)]
        #expect(ScheduleShiftRules.dayOffset(administeredAt: d(11, 9, 20), prescription: sunday, doses: doses, calendar: calendar) == 1)
        #expect(ScheduleShiftRules.dayOffset(administeredAt: d(11, 8, 21), prescription: sunday, doses: doses, calendar: calendar) == 0)
        #expect(ScheduleShiftRules.dayOffset(administeredAt: d(11, 7, 20), prescription: sunday, doses: doses, calendar: calendar) == -1)
    }

    @Test func oneDayLateKeepsStartAndMovesNextDose() {
        let doses = [dose(d(11, 1, 20), 1), dose(d(11, 9, 20), 2)]
        let shifted = ScheduleShiftRules.shifted(sunday, doses: doses, weekday: 2, hour: 20, minute: 0, anchor: d(11, 9, 20), calendar: calendar)
        #expect(shifted.scheduledWeekday == 2)
        #expect(shifted.startDate == sunday.startDate)
        #expect(shifted.totalDoses == 8)
        // 다음 투약은 7일 뒤 월요일
        #expect(ScheduleShiftRules.upcoming(shifted, doses: doses, now: d(11, 10, 9), calendar: calendar) == d(11, 16, 20))
        // 바꾸지 않으면 일요일 그대로
        #expect(ScheduleShiftRules.upcoming(sunday, doses: doses, now: d(11, 10, 9), calendar: calendar) == d(11, 15, 20))
    }

    @Test func conflictingHistoryMovesStartToAnchor() {
        // 11/3·11/8 기록이 수요일 기준으로는 한 마디에 겹친다 → 시작일을 11/8로
        let doses = [dose(d(11, 3, 20), 1), dose(d(11, 8, 20), 2)]
        let shifted = ScheduleShiftRules.shifted(sunday, doses: doses, weekday: 4, hour: 20, minute: 0, anchor: d(11, 8, 20), calendar: calendar)
        #expect(shifted.startDate == d(11, 8))
        #expect(ScheduleShiftRules.isConsistent(shifted, doses: doses, calendar: calendar))
        #expect(ScheduleShiftRules.upcoming(shifted, doses: doses, now: d(11, 9, 9), calendar: calendar) == d(11, 11, 20))
    }

    @Test func consistencyCheck() {
        #expect(ScheduleShiftRules.isConsistent(sunday, doses: [dose(d(11, 1, 20), 1), dose(d(11, 8, 20), 2)], calendar: calendar))
        #expect(!ScheduleShiftRules.isConsistent(sunday, doses: [dose(d(11, 7, 20), 1), dose(d(11, 8, 20), 2)], calendar: calendar))
        #expect(ScheduleShiftRules.isConsistent(sunday, doses: [], calendar: calendar))
    }
}
