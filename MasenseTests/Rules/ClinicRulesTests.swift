import Foundation
import Testing

@testable import Masense

// D28 진료 예약·결과 흐름
struct ClinicRulesTests {
    private let calendar = TestCalendar.seoul
    private let now = TestCalendar.date(2026, 11, 1, 10)

    @Test func appointmentStates() {
        #expect(ClinicRules.appointment(next: nil, visitDates: [], now: now, calendar: calendar) == .none)
        let soon = TestCalendar.date(2026, 11, 28, 14, 30)
        #expect(ClinicRules.appointment(next: soon, visitDates: [], now: now, calendar: calendar) == .upcoming(date: soon, days: 27))
        let today = TestCalendar.date(2026, 11, 1, 15)
        #expect(ClinicRules.appointment(next: today, visitDates: [], now: now, calendar: calendar) == .today(date: today))
        // 화면의 10.29 진료: 지났고 결과 없음 → 결과 적기
        let past = TestCalendar.date(2026, 10, 29)
        #expect(ClinicRules.appointment(next: past, visitDates: [TestCalendar.date(2026, 10, 3)], now: now, calendar: calendar) == .needsResult(date: past))
        // 그 뒤에 적은 진료 기록이 있으면(10.31) 다음 예약 차례
        #expect(ClinicRules.appointment(next: past, visitDates: [TestCalendar.date(2026, 10, 31, 11)], now: now, calendar: calendar) == .recorded(date: past))
        // 오늘 진료를 적었으면 다음 예약 차례
        #expect(ClinicRules.appointment(next: today, visitDates: [TestCalendar.date(2026, 11, 1, 16)], now: now, calendar: calendar) == .recorded(date: today))
    }

    @Test func timeIsOptional() {
        #expect(!ClinicRules.hasTime(TestCalendar.date(2026, 11, 28), calendar: calendar))
        #expect(ClinicRules.hasTime(TestCalendar.date(2026, 11, 28, 14, 30), calendar: calendar))
        let day = TestCalendar.date(2026, 11, 28, 9)
        #expect(ClinicRules.appointmentDate(day: day, time: nil, calendar: calendar) == TestCalendar.date(2026, 11, 28))
        #expect(ClinicRules.appointmentDate(day: day, time: TestCalendar.date(2026, 1, 1, 14, 30), calendar: calendar) == TestCalendar.date(2026, 11, 28, 14, 30))
    }

    @Test func totalPackagesIgnoresZero() {
        #expect(ClinicRules.totalPackages([1, 2, 0]) == 3)
        #expect(ClinicRules.totalPackages([]) == 0)
    }
}
