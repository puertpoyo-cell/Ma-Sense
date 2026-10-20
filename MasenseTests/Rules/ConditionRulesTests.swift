import Foundation
import Testing

@testable import Masense

// RULES.md R5
struct ConditionRulesTests {
    private let administered = TestCalendar.date(2026, 10, 22, 20)
    private let hour: TimeInterval = 3_600

    private func dose(isCancelled: Bool = false) -> DoseSnapshot {
        DoseSnapshot(administeredAt: administered, scheduledFor: administered, site: .thighLeft, sequence: 1, isCancelled: isCancelled)
    }

    private func windows(after hours: Double, checks: [ConditionCheckSnapshot] = [], dose: DoseSnapshot? = nil) -> [ConditionWindow] {
        let subject = dose ?? self.dose()
        return ConditionRules.openConditionWindows(dose: subject, checks: checks, now: administered.addingTimeInterval(hours * hour))
    }

    @Test func windowBoundaries() {
        #expect(windows(after: 11.99).isEmpty)
        #expect(windows(after: 12) == [.h24])
        #expect(windows(after: 35.99) == [.h24])
        #expect(windows(after: 36) == [.h48])
        #expect(windows(after: 95.99) == [.h48])
        #expect(windows(after: 96).isEmpty)
    }

    @Test func answeredWindowIsClosed() {
        let target = dose()
        let h24 = ConditionCheckSnapshot(doseID: target.id, window: .h24, checkedAt: administered.addingTimeInterval(20 * hour))
        #expect(windows(after: 20, checks: [h24], dose: target).isEmpty)
        #expect(windows(after: 40, checks: [h24], dose: target) == [.h48])

        let otherDoseCheck = ConditionCheckSnapshot(doseID: UUID(), window: .h24, checkedAt: administered)
        #expect(windows(after: 20, checks: [otherDoseCheck], dose: target) == [.h24])
    }

    @Test func cancelledDoseHasNoWindows() {
        #expect(windows(after: 20, dose: dose(isCancelled: true)).isEmpty)
    }

    @Test func combinedListPutsH24First() {
        let older = DoseSnapshot(administeredAt: administered.addingTimeInterval(-40 * hour), scheduledFor: administered, site: .abdomenUpperLeft, sequence: 1)
        let newer = dose()
        let now = administered.addingTimeInterval(20 * hour) // older: 60h → h48, newer: 20h → h24
        let open = ConditionRules.openConditionWindows(doses: [older, newer], checks: [], now: now)
        #expect(open.map { $0.window } == [.h24, .h48])
        #expect(open.map { $0.dose.id } == [newer.id, older.id])
    }
}
