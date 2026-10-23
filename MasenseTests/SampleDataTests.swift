import Foundation
import SwiftData
import Testing

@testable import Masense

// 스크린샷용 예시 데이터: 화면 상태가 의도대로 나오고, 약물명·용량·메모가 없는지
@MainActor
struct SampleDataTests {
    private let container: ModelContainer
    private let calendar = TestCalendar.seoul
    private let now = TestCalendar.date(2026, 10, 22, 13)

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
        try SampleData.seed(into: container.mainContext, now: now, calendar: calendar)
    }

    @Test func homeShowsUpcomingDoseClinicCardAndMissedCycle() throws {
        let context = container.mainContext
        let prescription = try #require(try Prescription.active(in: context))
        #expect(prescription.doseLabel == nil)
        #expect(prescription.doses.allSatisfy { $0.note == nil })

        let today = TodayModel(
            prescription: prescription.snapshot,
            doses: prescription.doseSnapshots,
            checks: try ConditionCheck.all(in: context).compactMap(\.snapshot),
            weights: try WeightSample.all(in: context).map(\.snapshot),
            now: now,
            calendar: calendar
        )
        guard case let .daysLeft(_, days, canLogEarly) = today.countdown else {
            Issue.record("expected D-n countdown, got \(today.countdown)")
            return
        }
        #expect(days == 1)
        #expect(canLogEarly)
        #expect(today.clinicDate != nil)
        #expect(today.paceNotice == nil)

        let cycles = CycleRules.cycles(for: prescription.snapshot, doses: prescription.doseSnapshots, now: now, until: now, calendar: calendar)
        #expect(CycleRules.missedCycles(cycles: cycles, doses: prescription.doseSnapshots, now: now).count == 1)
        // 첫 기록은 부위 기록 없음 (D6 예시). 누락은 첫 기록 뒤라 오늘 화면 안내 카드는 없다
        #expect(prescription.doses.filter { $0.site == nil }.count == 1)
        #expect(today.backfillCount == 0)
    }

    @Test func settingsMarkOnboardingDone() throws {
        let settings = try UserSettings.current(in: container.mainContext)
        #expect(settings.hasCompletedOnboarding)
    }
}
