import Foundation
import Testing

@testable import Masense

// D6 위젯 요약 (SCREENS.md 위젯). 목요일 20:00, 2026-10-16(금) 시작, 4회
struct WidgetRulesTests {
    private let calendar = TestCalendar.seoul

    private func prescription(totalDoses: Int = 4) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, totalDoses: totalDoses)
    }

    private func dose(_ month: Int, _ day: Int, site: BodySite? = .thighLeft, isCancelled: Bool = false) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, 20, 10)
        return DoseSnapshot(administeredAt: date, scheduledFor: date, site: site, sequence: 1, isCancelled: isCancelled)
    }

    private func snapshot(_ p: PrescriptionSnapshot?, doses: [DoseSnapshot] = [], allDoses: [DoseSnapshot]? = nil, now: Date) -> WidgetSnapshot {
        WidgetRules.snapshot(prescription: p, doses: doses, allDoses: allDoses ?? doses, now: now, calendar: calendar, siteName: { $0.rawValue })
    }

    @Test func upcomingDoneAndNoPrescription() {
        let now = TestCalendar.date(2026, 10, 20, 9)
        let upcoming = snapshot(prescription(), now: now)
        #expect(upcoming == WidgetSnapshot(
            phase: .upcoming, scheduledDate: TestCalendar.date(2026, 10, 22, 20),
            lastDoseDate: nil, lastSiteName: nil, remainingDoses: 4, updatedAt: now
        ))

        let logged = dose(10, 22)
        let done = snapshot(prescription(), doses: [logged], now: TestCalendar.date(2026, 10, 23, 9))
        #expect(done.phase == .done)
        #expect(done.scheduledDate == TestCalendar.date(2026, 10, 29, 20))
        #expect(done.lastDoseDate == logged.administeredAt)
        #expect(done.lastSiteName == "thighLeft")
        #expect(done.remainingDoses == 3)

        // 처방이 없어도 지난 처방의 마지막 부위는 보인다. 부위 기록 없음은 이름 없이
        let none = snapshot(nil, allDoses: [dose(10, 15), dose(10, 22, site: nil)], now: now)
        #expect(none.phase == .noPrescription)
        #expect(none.lastDoseDate == TestCalendar.date(2026, 10, 22, 20, 10))
        #expect(none.lastSiteName == nil)
    }

    @Test func overdueStaysUpcomingAndLastDoseEndsWithoutNext() {
        let overdue = snapshot(prescription(), now: TestCalendar.date(2026, 10, 23, 9))
        #expect(overdue.phase == .upcoming)
        #expect(overdue.scheduledDate == TestCalendar.date(2026, 10, 22, 20))

        let last = snapshot(prescription(totalDoses: 1), doses: [dose(10, 22)], now: TestCalendar.date(2026, 10, 23, 9))
        #expect(last.phase == .done)
        #expect(last.scheduledDate == nil)
        #expect(last.countdown(at: TestCalendar.date(2026, 10, 23, 9), calendar: calendar) == .exhausted)
    }

    // MARK: 위젯 쪽 표시 (Shared/WidgetSnapshot)

    @Test func countdownByCalendarDays() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        let upcoming = WidgetSnapshot(phase: .upcoming, scheduledDate: scheduled, updatedAt: scheduled)
        #expect(upcoming.countdown(at: TestCalendar.date(2026, 10, 20, 23), calendar: calendar) == .daysLeft(2, scheduled: scheduled))
        #expect(upcoming.countdown(at: TestCalendar.date(2026, 10, 21, 0, 1), calendar: calendar) == .daysLeft(1, scheduled: scheduled))
        #expect(upcoming.countdown(at: TestCalendar.date(2026, 10, 22, 9), calendar: calendar) == .today(scheduled: scheduled))
        #expect(upcoming.countdown(at: TestCalendar.date(2026, 10, 22, 21), calendar: calendar) == .overdue(daysPast: 0, scheduled: scheduled))
        #expect(upcoming.countdown(at: TestCalendar.date(2026, 10, 24, 9), calendar: calendar) == .overdue(daysPast: 2, scheduled: scheduled))
        #expect(WidgetSnapshot(phase: .noPrescription, updatedAt: scheduled).countdown(at: scheduled, calendar: calendar) == .noPrescription)
    }

    @Test func doneShowsUntilNextCycleStartsAndTimelineCoversTransitions() {
        let next = TestCalendar.date(2026, 10, 29, 20)
        let done = WidgetSnapshot(phase: .done, scheduledDate: next, updatedAt: next)
        #expect(done.showsDone(at: TestCalendar.date(2026, 10, 27, 19), calendar: calendar))
        #expect(!done.showsDone(at: TestCalendar.date(2026, 10, 27, 20), calendar: calendar))

        let now = TestCalendar.date(2026, 10, 23, 9, 30)
        let dates = done.timelineDates(from: now, calendar: calendar)
        #expect(dates.first == now)
        #expect(dates.contains(TestCalendar.date(2026, 10, 24)))
        #expect(dates.contains(TestCalendar.date(2026, 10, 27, 20)))
        #expect(dates.contains(next))
        #expect(dates == dates.sorted())
        #expect(dates.allSatisfy { $0 >= now })
    }

    @Test func snapshotRoundTripsThroughFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("widget-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let snapshot = WidgetSnapshot(
            phase: .upcoming, scheduledDate: TestCalendar.date(2026, 10, 22, 20),
            lastDoseDate: TestCalendar.date(2026, 10, 15, 20), lastSiteName: "허벅지 왼쪽", remainingDoses: 3,
            updatedAt: TestCalendar.date(2026, 10, 20, 9)
        )
        try snapshot.write(to: url)
        #expect(WidgetSnapshot.read(from: url) == snapshot)
        #expect(WidgetSnapshot.read(from: url.appendingPathExtension("missing")) == nil)
    }
}
