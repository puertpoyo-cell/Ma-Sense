import Foundation
import Testing

@testable import Masense

// R17 오늘 화면 사실 한 줄 (D8). 목요일 20:00, 2026-10-16(금) 시작 → 첫 예정 10-22(목)
struct DailyLineRulesTests {
    private let calendar = TestCalendar.seoul

    private func prescription(totalDoses: Int = 12, dosesPerPen: Int = 1) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, dosesPerPen: dosesPerPen, totalDoses: totalDoses)
    }

    private let recentWeight = [WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 21, 8), kilograms: 80)]

    @Test func doseDayComesFirstWithLastSite() {
        let previous = DoseSnapshot(administeredAt: TestCalendar.date(2026, 10, 15, 20), scheduledFor: TestCalendar.date(2026, 10, 15, 20), site: .thighRight, sequence: 1)
        let line = DailyLineRules.line(prescription: prescription(), doses: [], allDoses: [previous], weights: [],
                                       now: TestCalendar.date(2026, 10, 22, 9), calendar: calendar)
        #expect(line == .doseDay(lastSite: .thighRight))
        // 예정 시각이 지나도 그날이면 투약일
        #expect(DailyLineRules.line(prescription: prescription(), doses: [], allDoses: [], weights: recentWeight,
                                    now: TestCalendar.date(2026, 10, 22, 22), calendar: calendar) == .doseDay(lastSite: nil))
    }

    @Test func lowSupplyThenNoRecentWeight() {
        // 1회 남음 (1회용 펜 2개 중 1개 씀), 투약일 아님
        let used = DoseSnapshot(administeredAt: TestCalendar.date(2026, 10, 22, 20), scheduledFor: TestCalendar.date(2026, 10, 22, 20), site: .thighLeft, sequence: 1)
        let now = TestCalendar.date(2026, 10, 24, 9)
        #expect(DailyLineRules.line(prescription: prescription(totalDoses: 2), doses: [used], allDoses: [used], weights: recentWeight, now: now, calendar: calendar)
            == .lowSupply(remaining: 1, isSingleUsePen: true))
        // 넉넉하면 체중 기록을 본다
        #expect(DailyLineRules.line(prescription: prescription(), doses: [used], allDoses: [used], weights: [], now: now, calendar: calendar) == .noRecentWeight)
        #expect(DailyLineRules.line(prescription: prescription(), doses: [used], allDoses: [used], weights: recentWeight, now: now, calendar: calendar) == nil)
        // 처방이 없어도 체중은 본다
        #expect(DailyLineRules.line(prescription: nil, doses: [], allDoses: [], weights: [], now: now, calendar: calendar) == .noRecentWeight)
    }
}
