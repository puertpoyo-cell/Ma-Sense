import Foundation
import SwiftData
import Testing

@testable import Masense

// D26 두 기기가 iCloud로 합쳐진 뒤의 중복 정리
@MainActor
struct SyncMergeServiceTests {
    private let container: ModelContainer
    private let calendar = TestCalendar.seoul
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    private let older = TestCalendar.date(2026, 10, 16, 9)
    private let newer = TestCalendar.date(2026, 11, 1, 9)

    @Test func settingsMergeIntoOldestAndKeepConfirmations() throws {
        // 기기 A: 온보딩을 마친 설정. 기기 B: 새로 깔아 키만 적은 설정
        context.insert(UserSettings(hasAcceptedRoleNotice: true, hasConfirmedAdult: true, hasPurchasedPro: false, createdAt: older))
        context.insert(UserSettings(heightCm: 172, hasPurchasedPro: true, createdAt: newer))
        try context.save()

        #expect(try SyncMergeService.mergeDuplicates(context: context, calendar: calendar))
        let all = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(all.count == 1)
        #expect(all[0].hasCompletedOnboarding)
        #expect(all[0].hasPurchasedPro)
        #expect(all[0].heightCm == 172)
        // 다시 돌려도 바뀌는 것이 없다
        #expect(try SyncMergeService.mergeDuplicates(context: context, calendar: calendar) == false)
    }

    @Test func samePrescriptionMergesAndDosesMoveThenDedupe() throws {
        let start = TestCalendar.date(2026, 10, 16, 9)
        let a = Prescription(startDate: start, penCount: 1, scheduledWeekday: 5, scheduledHour: 20, createdAt: older)
        let b = Prescription(startDate: start.addingTimeInterval(3600), penCount: 1, scheduledWeekday: 5, scheduledHour: 20, createdAt: newer)
        context.insert(a)
        context.insert(b)
        let at = TestCalendar.date(2026, 10, 22, 20)
        let doseA = Dose(administeredAt: at, scheduledFor: at, site: .thighLeft, sequence: 1, prescription: a, createdAt: older)
        let doseB = Dose(administeredAt: at, scheduledFor: at, site: .thighLeft, sequence: 1, prescription: b, createdAt: newer)
        let laterB = Dose(administeredAt: at.addingTimeInterval(7 * 86400), scheduledFor: at, site: .thighRight, sequence: 2, prescription: b, createdAt: newer)
        context.insert(doseA)
        context.insert(doseB)
        context.insert(laterB)
        context.insert(ConditionCheck(checkedAt: at.addingTimeInterval(86400), window: .h24, dose: doseB))
        try context.save()

        #expect(try SyncMergeService.mergeDuplicates(context: context, calendar: calendar))
        let prescriptions = try context.fetch(FetchDescriptor<Prescription>())
        #expect(prescriptions.map(\.id) == [a.id])
        let doses = try context.fetch(FetchDescriptor<Dose>()).sorted { $0.administeredAt < $1.administeredAt }
        // 같은 투약은 하나로, 다른 기기에서만 적은 투약은 남는 처방으로 옮겨 온다
        #expect(doses.map(\.id) == [doseA.id, laterB.id])
        #expect(doses.allSatisfy { $0.prescription?.id == a.id })
        // 지운 투약의 컨디션 체크는 남는 투약으로
        #expect(doses[0].conditionChecks.count == 1)
    }

    @Test func habitsSameDayCombine() throws {
        let day = TestCalendar.date(2026, 11, 1, 8)
        context.insert(HabitCheck(date: day, water: true, note: "아침", createdAt: older))
        context.insert(HabitCheck(date: day.addingTimeInterval(3600), sleep: true, note: "저녁", createdAt: newer))
        try context.save()

        try SyncMergeService.mergeDuplicates(context: context, calendar: calendar)
        let all = try context.fetch(FetchDescriptor<HabitCheck>())
        #expect(all.count == 1)
        #expect(all[0].water && all[0].sleep && !all[0].fiber)
        #expect(all[0].note == "아침\n저녁")
    }

    @Test func healthImportsDedupeByHealthUUIDOnly() throws {
        let uuid = UUID()
        let at = TestCalendar.date(2026, 10, 30, 7)
        context.insert(WeightSample(measuredAt: at, kilograms: 77, source: .healthKit, healthKitUUID: uuid, createdAt: older))
        context.insert(WeightSample(measuredAt: at, kilograms: 77, source: .healthKit, healthKitUUID: uuid, createdAt: newer))
        // 직접 입력은 같은 값이어도 건드리지 않는다
        context.insert(WeightSample(measuredAt: at, kilograms: 77, source: .manual, createdAt: older))
        context.insert(WeightSample(measuredAt: at, kilograms: 77, source: .manual, createdAt: newer))
        try context.save()

        try SyncMergeService.mergeDuplicates(context: context, calendar: calendar)
        let all = try context.fetch(FetchDescriptor<WeightSample>())
        #expect(all.count == 3)
        #expect(all.filter { $0.healthKitUUID == uuid }.count == 1)
    }
}
