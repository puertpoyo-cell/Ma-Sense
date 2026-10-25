import Foundation
import SwiftData
import Testing

@testable import Masense

// DATA_MODEL.md CloudKit 호환 규칙과 디스크 저장. 출시 스키마 V1(1.0.0) → V2(1.1.0, 키 추가) 경량 이전
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

    /// 모르는 rawValue(나중 버전이 더한 값 등)는 기본값으로 읽는다. 부위는 "부위 기록 없음"(nil)으로 읽는다 (D6)
    @Test func unknownRawValuesFallBack() {
        let dose = Dose(administeredAt: .now, scheduledFor: .now, site: .thighRight, sequence: 1)
        dose.siteRaw = "unknownSite"
        #expect(dose.site == nil)
        let unknown = Dose(administeredAt: .now, scheduledFor: .now, site: nil, sequence: 1)
        #expect(unknown.siteRaw == Dose.unknownSiteRaw)
        unknown.site = .thighLeft
        #expect(unknown.siteRaw == "thighLeft")
        let protein = ProteinEntry(date: .now, meal: .lunch, foods: [.egg], estimatedGrams: 6)
        protein.foodsRaw = ["egg", "somethingNew"]
        #expect(protein.foods == [.egg, .other])
    }

    /// V1 저장소를 지금 스키마로 열면 기록과 설정이 그대로 남고 키는 비어 있다 (D5, V1 → V2 → V3)
    @Test func schemaV1StoreMigratesToV2() throws {
        let (directory, url) = try diskStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try autoreleasepool {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let v1 = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            let context = v1.mainContext
            let settings = SchemaV1.UserSettings()
            settings.hasAcceptedRoleNotice = true
            settings.proteinTargetGrams = 100
            context.insert(settings)
            context.insert(Prescription(startDate: TestCalendar.date(2026, 10, 16, 9), penCount: 2, scheduledWeekday: 5, scheduledHour: 20))
            try context.save()
        }

        let container = try ModelContainer.masense(url: copyStore(url, in: directory))
        let context = container.mainContext
        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.hasAcceptedRoleNotice)
        #expect(settings.proteinTargetGrams == 100)
        #expect(settings.heightCm == nil)
        #expect(try context.fetch(FetchDescriptor<Prescription>()).first?.penCount == 2)

        settings.heightCm = 170.5
        try context.save()
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.heightCm == 170.5)
    }

    /// V2 저장소를 지금 스키마로 열면 기록이 그대로 남고 물어볼 것을 새로 적을 수 있다 (D6, V2 → V3)
    @Test func schemaV2StoreMigratesToV3() throws {
        let (directory, url) = try diskStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try autoreleasepool {
            let schema = Schema(versionedSchema: SchemaV2.self)
            let v2 = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            let context = v2.mainContext
            let settings = SchemaV2.UserSettings()
            settings.heightCm = 168
            context.insert(settings)
            let prescription = Prescription(startDate: TestCalendar.date(2026, 10, 16, 9), penCount: 1, scheduledWeekday: 5, scheduledHour: 20)
            context.insert(prescription)
            let dose = Dose(administeredAt: TestCalendar.date(2026, 10, 22, 20), scheduledFor: TestCalendar.date(2026, 10, 22, 20), site: nil, sequence: 1)
            context.insert(dose)
            dose.prescription = prescription
            try context.save()
        }

        let container = try ModelContainer.masense(url: copyStore(url, in: directory))
        let context = container.mainContext
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.heightCm == 168)
        let dose = try #require(try context.fetch(FetchDescriptor<Dose>()).first)
        #expect(dose.site == nil)
        #expect(dose.prescription?.penCount == 1)
        #expect(try context.fetch(FetchDescriptor<ClinicQuestion>()).isEmpty)

        context.insert(ClinicQuestion(text: "질문"))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ClinicQuestion>()).map(\.text) == ["질문"])
    }

    /// V3 저장소를 지금 스키마로 열면 키·물어볼 것이 남고 체중 알림은 기본값(켜짐, 투약 요일, 8:00)이다 (D7, V3 → V4)
    @Test func schemaV3StoreMigratesToV4() throws {
        let (directory, url) = try diskStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try autoreleasepool {
            let schema = Schema(versionedSchema: SchemaV3.self)
            let v3 = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            let context = v3.mainContext
            let settings = SchemaV2.UserSettings()
            settings.heightCm = 171
            settings.reminderEnabled = false
            context.insert(settings)
            context.insert(ClinicQuestion(text: "질문"))
            try context.save()
        }

        let container = try ModelContainer.masense(url: copyStore(url, in: directory))
        let context = container.mainContext
        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.heightCm == 171)
        #expect(settings.reminderEnabled == false)
        #expect(settings.weightReminderEnabled == true)
        #expect(settings.weightReminderWeekday == nil)
        #expect(settings.weightReminderHour == 8)
        #expect(try context.fetch(FetchDescriptor<ClinicQuestion>()).map(\.text) == ["질문"])

        settings.weightReminderWeekday = 2
        try context.save()
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.weightReminderWeekday == 2)
    }

    /// V4 저장소를 지금 스키마로 열면 체중·제지방량이 남고 체지방률은 비어 있다 (D11, V4 → V5)
    @Test func schemaV4StoreMigratesToV5() throws {
        let (directory, url) = try diskStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try autoreleasepool {
            let schema = Schema(versionedSchema: SchemaV4.self)
            let v4 = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            let context = v4.mainContext
            let sample = SchemaV1.WeightSample()
            sample.measuredAt = TestCalendar.date(2026, 6, 26, 8)
            sample.kilograms = 75.6
            sample.sourceRaw = "healthKit"
            sample.leanBodyMassKg = 59.0
            context.insert(sample)
            try context.save()
        }

        let container = try ModelContainer.masense(url: copyStore(url, in: directory))
        let context = container.mainContext
        let sample = try #require(try context.fetch(FetchDescriptor<WeightSample>()).first)
        #expect(sample.kilograms == 75.6)
        #expect(sample.source == .healthKit)
        #expect(sample.leanBodyMassKg == 59.0)
        #expect(sample.bodyFatPercent == nil)

        sample.bodyFatPercent = 22.0
        try context.save()
        #expect(try context.fetch(FetchDescriptor<WeightSample>()).first?.bodyFatPercent == 22.0)
    }

    /// 이전 버전 컨테이너가 아직 파일을 붙잡고 있으면 같은 파일의 이전(migration)이 독점 잠금을 기다리다 멈출 수 있다.
    /// 저장한 파일(본 파일·-wal·-shm)을 새 위치로 복사해 그 사본을 연다 (앱에서는 컨테이너가 하나라 해당 없음)
    private func copyStore(_ url: URL, in directory: URL) throws -> URL {
        let migratedURL = directory.appendingPathComponent("Migrated.store")
        for suffix in StoreLocation.fileSuffixes {
            let source = URL(fileURLWithPath: url.path + suffix)
            if FileManager.default.fileExists(atPath: source.path) {
                try FileManager.default.copyItem(at: source, to: URL(fileURLWithPath: migratedURL.path + suffix))
            }
        }
        return migratedURL
    }

    /// 규칙 2: 모든 저장 속성에 기본값이 있어 인자 없이도 만들 수 있다 (UserSettings)
    @Test func settingsDefaults() throws {
        let container = try ModelContainer.masense(inMemory: true)
        let settings = try UserSettings.current(in: container.mainContext)
        #expect(settings.reportTheme == "midnight")
        #expect(settings.reportDefaultPeriod == nil)
        #expect(settings.eveningReminderHour == 20)
        #expect(settings.heightCm == nil)
        #expect(settings.weightReminderEnabled)
        #expect(settings.weightReminderHour == 8)
        #expect(settings.weightReminderMinute == 0)
    }
}
