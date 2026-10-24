import Foundation
import Testing

@testable import Masense

/// EXPORT_FORMAT.md 고정 샘플. formatVersion을 올리면 이전 버전 파일을 지우지 않고 새 fixture를 더한다
enum ExportFixture {
    private final class BundleToken {}

    static func data(_ name: String = "export_v1") throws -> Data {
        let fileName = "\(name).masense.json"
        if let url = Bundle(for: BundleToken.self).url(forResource: fileName, withExtension: nil) {
            return try Data(contentsOf: url)
        }
        // 테스트 번들에 복사되지 않았으면 소스 폴더에서 읽는다
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(fileName)
        return try Data(contentsOf: url)
    }

    static func document() throws -> ExportDocument {
        try ExportCodec.decode(data())
    }
}

// EXPORT_FORMAT.md 파일 형식과 가져오기 규칙 1~6
struct ExportCodecTests {
    // MARK: 파일 형식

    @Test func fixtureDecodes() throws {
        let document = try ExportFixture.document()
        #expect(document.format == "masense-export")
        #expect(document.formatVersion == 1)
        #expect(document.exportedAt == TestCalendar.date(2026, 10, 21, 8, 30))
        #expect(document.device == ExportDocument.Device(model: "iPhone16,2", systemVersion: "18.1"))
        #expect(document.settings?.proteinTargetGrams == 110)
        #expect(document.settings?.bodyWeightForGuideKg == nil)
        #expect(document.prescriptions.map(\.isActive) == [false, true])
        #expect(document.prescriptions[1].nextClinicDate == TestCalendar.date(2026, 10, 28))
        #expect(document.doses.map(\.site) == ["abdomenUpperLeft", "thighRight", "thighLeft"])
        #expect(document.doses[2].prescriptionId == document.prescriptions[1].id)
        #expect(document.conditionChecks.first?.symptoms == [
            ExportDocument.SymptomRecord(symptom: "nausea", severity: 2),
            ExportDocument.SymptomRecord(symptom: "fatigue", severity: 1),
        ])
        #expect(document.weightSamples.map(\.kilograms) == [79.1, 78.4])
        #expect(document.proteinEntries.first?.foods == ["egg", "egg", "milk"])
        // D6 이전 파일: clinicQuestions 키가 없으면 빈 배열
        #expect(document.clinicQuestions.isEmpty)
    }

    @Test func encodeWritesOffsetDatesAndExplicitNulls() throws {
        let document = try ExportFixture.document()
        let data = try ExportCodec.encode(document, timeZone: TestCalendar.seoul.timeZone)
        let json = try JSONSerialization.jsonObject(with: data)
        let object = try #require(json as? [String: Any])
        #expect(object["format"] as? String == "masense-export")
        #expect(object["exportedAt"] as? String == "2026-10-21T08:30:00.000+09:00")

        let doses = try #require(object["doses"] as? [[String: Any]])
        #expect(doses[2]["administeredAt"] as? String == "2026-10-15T20:05:00.000+09:00")
        #expect(doses[2]["site"] as? String == "thighLeft")
        // 빈 값도 키를 지우지 않고 null로 쓴다
        #expect(doses[2]["note"] is NSNull)
        let prescriptions = try #require(object["prescriptions"] as? [[String: Any]])
        #expect(prescriptions[1]["endDate"] is NSNull)

        #expect(try ExportCodec.decode(data) == document)
    }

    @Test func missingM2ArraysReadAsEmpty() throws {
        let json = try JSONSerialization.jsonObject(with: ExportFixture.data())
        var object = try #require(json as? [String: Any])
        object.removeValue(forKey: "proteinEntries")
        object.removeValue(forKey: "strengthSessions")
        object["habitChecks"] = [Any]()

        let document = try ExportCodec.decode(JSONSerialization.data(withJSONObject: object))
        #expect(document.proteinEntries.isEmpty)
        #expect(document.strengthSessions.isEmpty)
        #expect(document.habitChecks.isEmpty)
        #expect(document.doses.count == 3)
    }

    @Test func datesWithoutFractionalSecondsAreAccepted() {
        #expect(ExportCodec.parseDate("2026-10-21T20:00:00.000+09:00") == TestCalendar.date(2026, 10, 21, 20))
        #expect(ExportCodec.parseDate("2026-10-21T20:00:00+09:00") == TestCalendar.date(2026, 10, 21, 20))
        #expect(ExportCodec.parseDate("2026-10-21T11:00:00.000Z") == TestCalendar.date(2026, 10, 21, 20))
        #expect(ExportCodec.parseDate("21/10/2026") == nil)
    }

    @Test func fileNameUsesLocalDate() {
        // 서울 10-22 08:30은 UTC로 10-21
        let name = ExportCodec.fileName(exportedAt: TestCalendar.date(2026, 10, 22, 8, 30), calendar: TestCalendar.seoul)
        #expect(name == "Masense_Export_2026-10-22.masense.json")
    }

    // MARK: 규칙 1~3

    @Test func rejectsOtherFilesAndNewerVersions() {
        #expect(throws: ExportCodec.ImportError.notMasenseExport) {
            _ = try ExportCodec.decode(Data("not json".utf8))
        }
        #expect(throws: ExportCodec.ImportError.notMasenseExport) {
            _ = try ExportCodec.decode(Data(#"{"format": "other", "formatVersion": 1}"#.utf8))
        }
        #expect(throws: ExportCodec.ImportError.needsAppUpdate) {
            _ = try ExportCodec.decode(Data(#"{"format": "masense-export", "formatVersion": 2}"#.utf8))
        }
        #expect(throws: ExportCodec.ImportError.unreadable) {
            _ = try ExportCodec.decode(Data(#"{"format": "masense-export", "formatVersion": 1}"#.utf8))
        }
    }

    @Test func migrationChainsStepsAndStampsVersion() throws {
        let steps: [Int: ExportMigration.Step] = [
            1: { object in
                var object = object
                object["renamed"] = object.removeValue(forKey: "old")
                return object
            },
            2: { object in
                var object = object
                object["added"] = true
                return object
            },
        ]
        let migrated = try ExportMigration.migrate(["formatVersion": 1, "old": "x"], from: 1, to: 3, steps: steps)
        #expect(migrated["formatVersion"] as? Int == 3)
        #expect(migrated["renamed"] as? String == "x")
        #expect(!migrated.keys.contains("old"))
        #expect(migrated["added"] as? Bool == true)
    }

    @Test func migrationWithMissingStepIsUnreadable() throws {
        #expect(throws: ExportCodec.ImportError.unreadable) {
            _ = try ExportMigration.migrate(["formatVersion": 1], from: 1, to: 2, steps: [:])
        }
        // 현재 버전은 바꾸지 않는다
        let current = try ExportMigration.migrate(["formatVersion": 1], from: 1)
        #expect(current["formatVersion"] as? Int == 1)
    }

    // MARK: 규칙 4~6

    @Test func replacePlanTakesEverythingButHealthAppRecords() throws {
        let document = try ExportFixture.document()
        // 교체 모드는 이 기기의 ID를 보지 않는다 (먼저 모두 지운다)
        let plan = ExportCodec.importPlan(document, mode: .replace, existingIDs: Set(document.doses.map(\.id)))

        #expect(plan.settings == document.settings)
        #expect(plan.prescriptions == document.prescriptions)
        #expect(plan.doses == document.doses)
        #expect(plan.conditionChecks == document.conditionChecks)
        #expect(plan.weightSamples.map(\.source) == ["manual"])
        #expect(plan.strengthSessions.map(\.source) == ["manual"])
        #expect(plan.result.leftToHealthApp == 2)
        #expect(plan.result.totalSkipped == 0)
    }

    @Test func addPlanSkipsExistingIDsButStillAttachesToThem() throws {
        let document = try ExportFixture.document()
        // 이 기기에 두 번째 처방과 세 번째 투약이 이미 있다
        let existing: Set<UUID> = [document.prescriptions[1].id, document.doses[2].id]
        let plan = ExportCodec.importPlan(document, mode: .add, existingIDs: existing)

        #expect(plan.settings == nil)
        #expect(plan.prescriptions.map(\.id) == [document.prescriptions[0].id])
        #expect(plan.result.prescriptions == ExportCodec.ImportResult.Count(imported: 1, skipped: 1))
        // 건너뛴 처방에 딸린 투약은 이 기기의 같은 처방에 붙는다
        #expect(plan.doses.map(\.id) == [document.doses[0].id, document.doses[1].id])
        #expect(plan.result.doses == ExportCodec.ImportResult.Count(imported: 2, skipped: 1))
        // 건너뛴 투약의 컨디션 체크도 이 기기의 같은 투약에 붙는다
        #expect(plan.conditionChecks == document.conditionChecks)
    }

    @Test func dosesWithoutPrescriptionInFileAreSkippedWithTheirChecks() throws {
        var document = try ExportFixture.document()
        document.doses[1].prescriptionId = nil
        document.doses[2].prescriptionId = UUID()
        var orphanCheck = document.conditionChecks[0]
        orphanCheck.id = UUID()
        orphanCheck.doseId = nil
        document.conditionChecks.append(orphanCheck)

        let plan = ExportCodec.importPlan(document, mode: .replace, existingIDs: [])
        #expect(plan.doses.map(\.id) == [document.doses[0].id])
        #expect(plan.result.doses == ExportCodec.ImportResult.Count(imported: 1, skipped: 2))
        #expect(plan.conditionChecks.isEmpty)
        #expect(plan.result.conditionChecks == ExportCodec.ImportResult.Count(imported: 0, skipped: 2))
        #expect(plan.result.totalSkipped == 4)
    }

    @Test func duplicateIDsInsideFileAreImportedOnce() throws {
        var document = try ExportFixture.document()
        document.habitChecks.append(document.habitChecks[0])
        let plan = ExportCodec.importPlan(document, mode: .replace, existingIDs: [])
        #expect(plan.habitChecks.count == 1)
        #expect(plan.result.habitChecks == ExportCodec.ImportResult.Count(imported: 1, skipped: 1))
    }
}
