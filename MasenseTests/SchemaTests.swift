import Foundation
import SwiftData
import Testing

@testable import Masense

// DATA_MODEL.md CloudKit 호환 규칙과 디스크 저장 (2026-10-22 출시 전 재정리 후 단일 SchemaV1)
@MainActor
struct SchemaTests {
    private func diskStore() throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appendingPathComponent("Masense.store"))
    }

    /// 규칙 1: `@Attribute(.unique)` 금지
    @Test func noUniqueAttributes() throws {
        let container = try ModelContainer.masense(inMemory: true)
        for entity in container.schema.entities {
            for attribute in entity.attributes {
                #expect(!attribute.isUnique, "\(entity.name).\(attribute.name)")
            }
        }
    }

    /// 규칙 4: 열거형은 rawValue 문자열로 저장하고, 디스크에 썼다가 다시 열어도 같은 값으로 읽힌다
    @Test func enumsRoundTripAsRawValuesOnDisk() throws {
        let (directory, url) = try diskStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let checkedAt = TestCalendar.date(2026, 10, 23, 20)

        do {
            let container = try ModelContainer.masense(url: url)
            let context = container.mainContext
            let prescription = Prescription(startDate: TestCalendar.date(2026, 10, 16, 9), penCount: 2, scheduledWeekday: 5, scheduledHour: 20)
            context.insert(prescription)
            let dose = Dose(administeredAt: checkedAt, scheduledFor: checkedAt, site: .thighLeft, sequence: 1)
            context.insert(dose)
            dose.prescription = prescription
            let check = ConditionCheck(checkedAt: checkedAt, window: .h48, symptoms: [SymptomEntry(symptom: .nausea, severity: 2)], appetite: .reduced)
            context.insert(check)
            check.dose = dose
            context.insert(WeightSample(measuredAt: checkedAt, kilograms: 81.5, source: .healthKit))
            context.insert(ProteinEntry(date: TestCalendar.date(2026, 10, 23), meal: .dinner, foods: [.tofu, .egg], estimatedGrams: 16))
            context.insert(StrengthSession(startedAt: checkedAt, durationMinutes: 20, kind: .walk, intensity: .light, source: .healthKit))
            try context.save()
        }

        // 컨테이너를 붙잡아 둔다. 임시값의 mainContext만 쓰면 컨테이너가 해제되어 테스트 프로세스가 죽는다
        let container = try ModelContainer.masense(url: url)
        let context = container.mainContext
        let dose = try #require(try context.fetch(FetchDescriptor<Dose>()).first)
        #expect(dose.site == .thighLeft)
        #expect(dose.siteRaw == "thighLeft")
        #expect(dose.prescription?.doses.count == 1)
        let check = try #require(try context.fetch(FetchDescriptor<ConditionCheck>()).first)
        #expect(check.window == .h48)
        #expect(check.appetite == .reduced)
        #expect(check.symptoms == [SymptomEntry(symptom: .nausea, severity: 2)])
        #expect(try context.fetch(FetchDescriptor<WeightSample>()).first?.source == .healthKit)
        let protein = try #require(try context.fetch(FetchDescriptor<ProteinEntry>()).first)
        #expect(protein.meal == .dinner)
        #expect(protein.foods == [.tofu, .egg])
        let session = try #require(try context.fetch(FetchDescriptor<StrengthSession>()).first)
        #expect(session.kind == .walk)
        #expect(session.intensity == .light)
        #expect(session.source == .healthKit)
    }

    /// 모르는 rawValue(나중 버전이 더한 값 등)는 기본값으로 읽는다
    @Test func unknownRawValuesFallBack() {
        let dose = Dose(administeredAt: .now, scheduledFor: .now, site: .thighRight, sequence: 1)
        dose.siteRaw = "unknownSite"
        #expect(dose.site == .abdomenUpperLeft)
        let protein = ProteinEntry(date: .now, meal: .lunch, foods: [.egg], estimatedGrams: 6)
        protein.foodsRaw = ["egg", "somethingNew"]
        #expect(protein.foods == [.egg, .other])
    }

    /// 규칙 2: 모든 저장 속성에 기본값이 있어 인자 없이도 만들 수 있다 (UserSettings)
    @Test func settingsDefaults() throws {
        let container = try ModelContainer.masense(inMemory: true)
        let settings = try UserSettings.current(in: container.mainContext)
        #expect(settings.reportTheme == "midnight")
        #expect(settings.reportDefaultPeriod == nil)
        #expect(settings.eveningReminderHour == 20)
    }
}
