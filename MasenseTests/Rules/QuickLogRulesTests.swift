import Foundation
import SwiftData
import Testing

@testable import Masense

// D51 한 번에 투약 기록 (위젯 버튼·Siri·단축어). 목요일 20:00, 2026-10-16(금) 시작, 4회
struct QuickLogRulesTests {
    private let calendar = TestCalendar.seoul

    private func prescription(totalDoses: Int = 4) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, totalDoses: totalDoses)
    }

    @Test func logsCurrentCycleWithoutSite() {
        // 예정일(10/22 목) 저녁 20:47에 누름 → 20:30으로 내리고 그 마디 예정일에 붙인다
        let outcome = QuickLogRules.outcome(prescription: prescription(), doses: [], at: TestCalendar.date(2026, 10, 22, 20, 47), calendar: calendar)
        guard case let .log(dose) = outcome else {
            Issue.record("expected log, got \(outcome)")
            return
        }
        #expect(dose.administeredAt == TestCalendar.date(2026, 10, 22, 20, 30))
        #expect(dose.scheduledFor == TestCalendar.date(2026, 10, 22, 20))
        #expect(dose.site == nil)
        #expect(dose.sequence == 1)
    }

    @Test func doesNotLogTwiceInOneCycle() {
        let first = DoseSnapshot(administeredAt: TestCalendar.date(2026, 10, 22, 20, 30), scheduledFor: TestCalendar.date(2026, 10, 22, 20), site: nil, sequence: 1)
        let outcome = QuickLogRules.outcome(prescription: prescription(), doses: [first], at: TestCalendar.date(2026, 10, 22, 21), calendar: calendar)
        #expect(outcome == .alreadyLogged(next: TestCalendar.date(2026, 10, 29, 20)))
    }

    @Test func noPrescriptionAndExhausted() {
        #expect(QuickLogRules.outcome(prescription: nil, doses: [], at: TestCalendar.date(2026, 10, 22, 20), calendar: calendar) == .noPrescription)
        // 1회짜리 처방을 기록한 뒤 그 마디가 지나면 소진
        let only = DoseSnapshot(administeredAt: TestCalendar.date(2026, 10, 22, 20), scheduledFor: TestCalendar.date(2026, 10, 22, 20), site: .thighLeft, sequence: 1)
        let outcome = QuickLogRules.outcome(prescription: prescription(totalDoses: 1), doses: [only], at: TestCalendar.date(2026, 11, 5, 20), calendar: calendar)
        #expect(outcome == .exhausted)
    }

    @Test func widgetSnapshotAfterQuickLog() {
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        let tapped = TestCalendar.date(2026, 10, 22, 20, 47)
        let before = WidgetSnapshot(phase: .upcoming, scheduledDate: scheduled, lastDoseDate: nil, lastSiteName: "thighLeft", remainingDoses: 4, updatedAt: scheduled)
        let after = before.afterQuickLog(at: tapped, calendar: calendar)
        #expect(after.phase == .done)
        #expect(after.scheduledDate == TestCalendar.date(2026, 10, 29, 20))
        #expect(after.remainingDoses == 3)
        #expect(after.lastDoseDate == tapped)
        #expect(after.lastSiteName == nil)
        // 두 번 눌러도 그대로
        #expect(after.afterQuickLog(at: tapped, calendar: calendar) == after)
        // 마지막 회차면 다음 예정이 없다
        var last = before
        last.remainingDoses = 1
        #expect(last.afterQuickLog(at: tapped, calendar: calendar).scheduledDate == nil)
    }

    @Test func queueKeepsTapsUntilCleared() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("QuickLogQueue-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(QuickLogQueue.read(from: url).isEmpty)
        QuickLogQueue.append(TestCalendar.date(2026, 10, 22, 21), to: url)
        QuickLogQueue.append(TestCalendar.date(2026, 10, 22, 20, 47), to: url)
        #expect(QuickLogQueue.read(from: url) == [TestCalendar.date(2026, 10, 22, 20, 47), TestCalendar.date(2026, 10, 22, 21)])
        QuickLogQueue.clear(at: url)
        #expect(QuickLogQueue.read(from: url).isEmpty)
    }
}

// 위젯에서 눌러 둔 기록을 앱이 저장소에 넣는다
@MainActor
struct QuickLogServiceTests {
    private let calendar = TestCalendar.seoul

    @Test func drainStoresOneDosePerCycleAndClearsQueue() throws {
        let container = try ModelContainer.masense(inMemory: true)
        let context = container.mainContext
        let prescription = Prescription(startDate: TestCalendar.date(2026, 10, 16, 9), penCount: 1, scheduledWeekday: 5, scheduledHour: 20)
        context.insert(prescription)
        try context.save()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("QuickLogQueue-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        // 같은 마디에 두 번 누름 → 한 번만 들어간다
        QuickLogQueue.append(TestCalendar.date(2026, 10, 22, 20, 47), to: url)
        QuickLogQueue.append(TestCalendar.date(2026, 10, 22, 20, 48), to: url)

        #expect(QuickLogService.drain(in: context, calendar: calendar, queueURL: url) == 1)
        let doses = try context.fetch(FetchDescriptor<Dose>())
        #expect(doses.count == 1)
        #expect(doses.first?.site == nil)
        #expect(doses.first?.administeredAt == TestCalendar.date(2026, 10, 22, 20, 30))
        #expect(doses.first?.prescription === prescription)
        #expect(QuickLogQueue.read(from: url).isEmpty)
        #expect(QuickLogService.drain(in: context, calendar: calendar, queueURL: url) == 0)
    }

    @Test func logWithoutPrescription() throws {
        let container = try ModelContainer.masense(inMemory: true)
        #expect(QuickLogService.log(in: container.mainContext, at: TestCalendar.date(2026, 10, 22, 20), calendar: calendar) == .noPrescription)
    }
}
