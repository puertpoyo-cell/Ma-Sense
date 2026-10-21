import Foundation
import SwiftData
import Testing

@testable import Masense

// V1 디스크 저장소가 V2로 경량 마이그레이션되고 기존 기록이 남는지 (DATA_MODEL.md 스키마 버전)
@MainActor
struct MigrationTests {
    @Test func v1StoreMigratesToV2KeepingRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Masense.store")

        // 1. V1 스키마로 저장소를 만들고 기록을 남긴다
        do {
            let v1 = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(
                for: v1,
                configurations: [ModelConfiguration(schema: v1, url: url, cloudKitDatabase: .none)]
            )
            let context = container.mainContext
            let prescription = Prescription(startDate: TestCalendar.date(2026, 10, 16, 9), penCount: 2, scheduledWeekday: 5, scheduledHour: 20)
            context.insert(prescription)
            let administered = TestCalendar.date(2026, 10, 22, 20)
            let dose = Dose(administeredAt: administered, scheduledFor: administered, site: .thighLeft, sequence: 1)
            context.insert(dose)
            dose.prescription = prescription
            context.insert(WeightSample(measuredAt: administered, kilograms: 81.5, source: .manual))
            try context.save()
        }

        // 2. 현재(V2) 컨테이너로 같은 파일을 연다
        let container = try ModelContainer.masense(url: url)
        let context = container.mainContext
        let prescriptions = try context.fetch(FetchDescriptor<Prescription>())
        #expect(prescriptions.count == 1)
        #expect(prescriptions.first?.doses.count == 1)
        #expect(try context.fetch(FetchDescriptor<WeightSample>()).first?.kilograms == 81.5)

        // 3. 새 엔티티를 쓸 수 있다
        context.insert(ProteinEntry(date: TestCalendar.date(2026, 10, 23), meal: .breakfast, foods: [.egg, .egg], estimatedGrams: 12))
        context.insert(StrengthSession(startedAt: TestCalendar.date(2026, 10, 23, 7), durationMinutes: 20, kind: .strength))
        context.insert(HabitCheck(date: TestCalendar.date(2026, 10, 23), water: true))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ProteinEntry>()).first?.foods == [.egg, .egg])
        #expect(try context.fetch(FetchDescriptor<StrengthSession>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<HabitCheck>()).first?.water == true)
    }
}
