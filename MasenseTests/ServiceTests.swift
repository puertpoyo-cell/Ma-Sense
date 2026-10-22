import Foundation
import SwiftData
import Testing

@testable import Masense

// M1-b 서비스. 실제 HealthKit·StoreKit·UserNotifications 대신 Fake를 주입한다 (CLAUDE.md 테스트·빌드).
@MainActor
struct ServiceTests {
    // 컨테이너가 해제되면 mainContext를 쓰는 순간 크래시하므로 테스트 동안 붙잡아 둔다.
    // Swift Testing은 테스트마다 새 인스턴스를 만들어 테스트끼리 격리된다.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    private func makeContext() -> ModelContext {
        container.mainContext
    }

    @Test func notificationCoordinatorRegistersPlanFromStoredData() async throws {
        let context = makeContext()
        let prescription = Prescription(
            startDate: TestCalendar.date(2026, 10, 16, 9),
            penCount: 3,
            scheduledWeekday: 5,
            scheduledHour: 20,
            nextClinicDate: TestCalendar.date(2026, 11, 10, 10)
        )
        try Prescription.activate(prescription, in: context)

        let fake = FakeNotificationService()
        let coordinator = NotificationCoordinator(service: fake, calendar: TestCalendar.seoul)
        await coordinator.refresh(context: context, now: TestCalendar.date(2026, 10, 16, 9))

        #expect(fake.replaceCount == 1)
        #expect(fake.pending.filter { $0.kind == .doseDue }.count == 4)
        #expect(fake.pending.contains { $0.kind == .clinicSoon })

        // 기록하면 그 마디의 투약 알림이 사라진다
        let scheduled = TestCalendar.date(2026, 10, 22, 20)
        prescription.doses.append(Dose(administeredAt: scheduled, scheduledFor: scheduled, site: .thighLeft, sequence: 1))
        await coordinator.refresh(context: context, now: TestCalendar.date(2026, 10, 22, 21))
        #expect(!fake.pending.contains { $0.id == "dose.due.0" })
        #expect(fake.pending.contains { $0.kind == .conditionH24 })
    }

    @Test func notificationCoordinatorWithoutPrescriptionRegistersNothing() async throws {
        let context = makeContext()
        let fake = FakeNotificationService()
        await NotificationCoordinator(service: fake, calendar: TestCalendar.seoul).refresh(context: context, now: .now)
        #expect(fake.pending.isEmpty)
    }

    @Test func activatingPrescriptionArchivesPrevious() throws {
        let context = makeContext()
        let first = Prescription(startDate: TestCalendar.date(2026, 9, 1), penCount: 1, scheduledWeekday: 5, scheduledHour: 20)
        let second = Prescription(startDate: TestCalendar.date(2026, 10, 16), penCount: 2, scheduledWeekday: 5, scheduledHour: 20)
        try Prescription.activate(first, in: context)
        try Prescription.activate(second, in: context)
        #expect(first.isActive == false)
        #expect(second.isActive == true)
        #expect(try Prescription.active(in: context)?.penCount == 2)
    }

    @Test func userSettingsIsSingleRecord() throws {
        let context = makeContext()
        let a = try UserSettings.current(in: context)
        let b = try UserSettings.current(in: context)
        #expect(a.persistentModelID == b.persistentModelID)
        #expect(a.eveningReminderHour == 20)
    }

    @Test func weightSyncUpsertsUpdatesAndDeletes() async throws {
        let context = makeContext()
        let reader = FakeHealthKitService()
        let calendar = TestCalendar.seoul
        let now = TestCalendar.date(2026, 10, 22, 12)
        let uuid = UUID()

        context.insert(WeightSample(measuredAt: TestCalendar.date(2026, 10, 1), kilograms: 85, source: .manual))

        reader.samples = [HealthWeightSample(uuid: uuid, measuredAt: TestCalendar.date(2026, 10, 20, 8), kilograms: 80)]
        try await WeightSyncService.sync(reader: reader, context: context, now: now, calendar: calendar)
        var cached = try WeightSample.all(in: context).filter { $0.source == .healthKit }
        #expect(cached.count == 1)
        #expect(cached.first?.healthKitUUID == uuid)
        #expect(cached.first?.kilograms == 80)

        reader.samples = [HealthWeightSample(uuid: uuid, measuredAt: TestCalendar.date(2026, 10, 20, 8), kilograms: 79.4)]
        try await WeightSyncService.sync(reader: reader, context: context, now: now, calendar: calendar)
        cached = try WeightSample.all(in: context).filter { $0.source == .healthKit }
        #expect(cached.count == 1)
        #expect(cached.first?.kilograms == 79.4)

        reader.samples = []
        try await WeightSyncService.sync(reader: reader, context: context, now: now, calendar: calendar)
        let all = try WeightSample.all(in: context)
        #expect(all.filter { $0.source == .healthKit }.isEmpty)
        #expect(all.filter { $0.source == .manual }.count == 1)
    }

    @Test func fakeStoreRoundTrip() async throws {
        let store = FakeStoreService()
        #expect(await store.refreshEntitlement() == false)
        #expect(try await store.purchase())
        #expect(await store.refreshEntitlement())
        #expect(try await store.restore())
    }

    @Test func notificationBodyUsesLocalizedKeyAndArgument() {
        let low = PlannedNotification(id: "prescription.low.0", kind: .prescriptionLow, fireDate: .now, argument: 2)
        let body = NotificationService.body(for: low)
        #expect(body.contains("2"))
        #expect(!body.contains("%"))
        #expect(!body.contains("!"))
    }
}
