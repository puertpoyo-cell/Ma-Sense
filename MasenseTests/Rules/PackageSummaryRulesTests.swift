import Foundation
import Testing

@testable import Masense

// R18 패키지 정리 (D9). 목요일 20:00 투약, 4회 = 패키지 하나
struct PackageSummaryRulesTests {
    private let calendar = TestCalendar.seoul

    private func dose(_ month: Int, _ day: Int, sequence: Int, cancelled: Bool = false) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, 20)
        return DoseSnapshot(administeredAt: date, scheduledFor: date, site: .abdomenLowerLeft, sequence: sequence, isCancelled: cancelled)
    }

    private var fourWeeks: [DoseSnapshot] {
        [dose(10, 22, sequence: 1), dose(10, 29, sequence: 2), dose(11, 5, sequence: 3), dose(11, 12, sequence: 4)]
    }

    @Test func packageEndsAWeekAfterItsFourthDose() {
        let doses = fourWeeks + [dose(10, 23, sequence: 9, cancelled: true)]
        #expect(PackageSummaryRules.finishedPackages(doses: doses, now: TestCalendar.date(2026, 11, 18, 23), calendar: calendar).isEmpty)
        let finished = PackageSummaryRules.finishedPackages(doses: doses, now: TestCalendar.date(2026, 11, 19), calendar: calendar)
        #expect(finished == [PackagePeriod(
            number: 1,
            firstSequence: 1,
            lastSequence: 4,
            period: DateInterval(start: TestCalendar.date(2026, 10, 22), end: TestCalendar.date(2026, 11, 19))
        )])
    }

    @Test func incompletePackageIsNotSummarized() {
        let doses = Array(fourWeeks.prefix(3))
        #expect(PackageSummaryRules.finishedPackages(doses: doses, now: TestCalendar.date(2027, 1, 1), calendar: calendar).isEmpty)
    }

    @Test func earlyNextPackageCutsThePeriod() {
        // 다음 패키지 첫 투약을 5일 뒤에 했다
        let doses = fourWeeks + [dose(11, 17, sequence: 5)]
        let finished = PackageSummaryRules.finishedPackages(doses: doses, now: TestCalendar.date(2026, 11, 17, 21), calendar: calendar)
        #expect(finished.map(\.period) == [DateInterval(start: TestCalendar.date(2026, 10, 22), end: TestCalendar.date(2026, 11, 17))])
    }

    @Test func mostRecentFirstWithLimit() {
        var doses: [DoseSnapshot] = []
        for week in 0..<8 {
            let date = TestCalendar.seoul.date(byAdding: .day, value: 7 * week, to: TestCalendar.date(2026, 10, 22, 20))!
            doses.append(DoseSnapshot(administeredAt: date, scheduledFor: date, site: nil, sequence: week + 1))
        }
        let finished = PackageSummaryRules.finishedPackages(doses: doses, now: TestCalendar.date(2027, 1, 1), calendar: calendar)
        #expect(finished.map(\.number) == [2, 1])
        #expect(finished.first?.firstSequence == 5)
        #expect(finished.first?.lastSequence == 8)
        #expect(PackageSummaryRules.finishedPackages(doses: doses, now: TestCalendar.date(2027, 1, 1), calendar: calendar, limit: 1).map(\.number) == [2])
    }

    @Test func todayCardOnlyForAWeekAfterThePackageEnds() {
        #expect(PackageSummaryRules.recentlyFinished(doses: fourWeeks, now: TestCalendar.date(2026, 11, 25, 23), calendar: calendar)?.number == 1)
        #expect(PackageSummaryRules.recentlyFinished(doses: fourWeeks, now: TestCalendar.date(2026, 11, 26), calendar: calendar) == nil)
    }
}
