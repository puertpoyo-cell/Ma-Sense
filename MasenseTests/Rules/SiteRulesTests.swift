import Foundation
import Testing

@testable import Masense

// RULES.md R6
struct SiteRulesTests {
    private func dose(_ day: Int, _ site: BodySite, isCancelled: Bool = false) -> DoseSnapshot {
        let date = TestCalendar.date(2026, 10, day, 20)
        return DoseSnapshot(administeredAt: date, scheduledFor: date, site: site, sequence: day, isCancelled: isCancelled)
    }

    @Test func historyIsMostRecentFirstAndLimited() {
        let doses = [
            dose(1, .abdomenUpperLeft),
            dose(8, .abdomenUpperRight),
            dose(15, .thighLeft),
            dose(22, .thighRight),
            dose(29, .upperArmLeft),
        ].shuffled()

        let history = SiteRules.siteHistory(doses: doses)
        #expect(history.map(\.site) == [.upperArmLeft, .thighRight, .thighLeft, .abdomenUpperRight])
        #expect(history.first?.date == TestCalendar.date(2026, 10, 29, 20))
        #expect(SiteRules.siteHistory(doses: doses, limit: 2).count == 2)
        #expect(SiteRules.siteHistory(doses: doses, limit: 0).isEmpty)
    }

    @Test func cancelledDosesAreExcluded() {
        let doses = [dose(1, .abdomenUpperLeft), dose(8, .thighLeft, isCancelled: true)]
        #expect(SiteRules.siteHistory(doses: doses).map(\.site) == [.abdomenUpperLeft])
    }

    @Test func recencyRank() {
        let history = SiteRules.siteHistory(doses: [dose(1, .thighLeft), dose(8, .thighRight), dose(15, .thighLeft)])
        #expect(SiteRules.recencyRank(of: .thighLeft, in: history) == 0)
        #expect(SiteRules.recencyRank(of: .thighRight, in: history) == 1)
        #expect(SiteRules.recencyRank(of: .upperArmLeft, in: history) == nil)
    }

    @Test func lastUseBySiteKeepsLatestPerSite() {
        let doses = [
            dose(1, .thighLeft),
            dose(8, .abdomenUpperLeft),
            dose(15, .thighLeft),
            dose(22, .thighRight, isCancelled: true),
        ].shuffled()
        let lastUse = SiteRules.lastUseBySite(doses: doses)
        #expect(lastUse == [
            .thighLeft: TestCalendar.date(2026, 10, 15, 20),
            .abdomenUpperLeft: TestCalendar.date(2026, 10, 8, 20),
        ])
        #expect(SiteRules.lastUseBySite(doses: []).isEmpty)
    }

    @Test func lastDoseNoteCountsCalendarDays() {
        let doses = [dose(8, .abdomenUpperLeft), dose(15, .thighLeft), dose(20, .thighRight, isCancelled: true)]
        // 10-22 09:00: 마지막 기록은 10-15 20:00, 달력으로 7일 전
        let note = SiteRules.lastDoseNote(doses: doses, now: TestCalendar.date(2026, 10, 22, 9), calendar: TestCalendar.seoul)
        #expect(note == LastDoseNote(site: .thighLeft, date: TestCalendar.date(2026, 10, 15, 20), daysAgo: 7))
        // 같은 날이면 0
        let sameDay = SiteRules.lastDoseNote(doses: doses, now: TestCalendar.date(2026, 10, 15, 23), calendar: TestCalendar.seoul)
        #expect(sameDay?.daysAgo == 0)
        #expect(SiteRules.lastDoseNote(doses: [], now: TestCalendar.date(2026, 10, 22), calendar: TestCalendar.seoul) == nil)
    }
}
