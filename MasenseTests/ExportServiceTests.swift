import Foundation
import SwiftData
import Testing

@testable import Masense

// 설정 > 데이터: 내보내기·가져오기·전체 삭제 (EXPORT_FORMAT.md)
@MainActor
struct ExportServiceTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    private var context: ModelContext { container.mainContext }

    private func seed() throws {
        let prescription = Prescription(
            startDate: TestCalendar.date(2026, 10, 16, 9),
            penCount: 1,
            scheduledWeekday: 5,
            scheduledHour: 20,
            doseLabel: "메모"
        )
        try Prescription.activate(prescription, in: context)
        let administered = TestCalendar.date(2026, 10, 22, 20)
        let dose = Dose(administeredAt: administered, scheduledFor: administered, site: .abdomenUpperLeft, sequence: 1, note: "왼쪽")
        context.insert(dose)
        dose.prescription = prescription
        let check = ConditionCheck(
            checkedAt: TestCalendar.date(2026, 10, 23, 20),
            window: .h24,
            symptoms: [SymptomEntry(symptom: .nausea, severity: 1)]
        )
        context.insert(check)
        check.dose = dose
        context.insert(WeightSample(measuredAt: TestCalendar.date(2026, 10, 20, 8), kilograms: 80.4, source: .manual))
        context.insert(ClinicQuestion(text: "질문", createdAt: TestCalendar.date(2026, 10, 21, 9)))
        _ = try UserSettings.current(in: context)
        try context.save()
    }

    @Test func exportFileIsNamedAndReadsBack() throws {
        try seed()
        let url = try ExportService.writeExportFile(context: context, now: TestCalendar.date(2026, 10, 24, 9), calendar: TestCalendar.seoul)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == "Masense_Export_2026-10-24.masense.json")

        let document = try ExportCodec.decode(Data(contentsOf: url))
        #expect(document.schemaVersion == "1.6.0")
        #expect(document.prescriptions.map(\.doseLabel) == ["메모"])
        #expect(document.doses.map(\.note) == ["왼쪽"])
        #expect(document.doses.first?.prescriptionId == document.prescriptions.first?.id)
        #expect(document.conditionChecks.first?.doseId == document.doses.first?.id)
        #expect(document.weightSamples.map(\.kilograms) == [80.4])
        #expect(document.settings?.reminderEnabled == true)
    }

    /// 내보내기 → 가져오기 → 같은 파일. 건강 앱 기록은 가져오지 않으므로 빠진다
    @Test func fixtureRoundTripsThroughStore() throws {
        let fixture = try ExportFixture.document()
        let result = try ExportService.apply(fixture, mode: .replace, context: context, calendar: TestCalendar.seoul)
        #expect(result.prescriptions.imported == 2)
        #expect(result.doses.imported == 3)
        #expect(result.conditionChecks.imported == 1)
        #expect(result.leftToHealthApp == 2)
        #expect(result.totalSkipped == 0)

        let exported = try ExportService.makeDocument(
            context: context,
            now: fixture.exportedAt,
            appVersion: fixture.appVersion,
            device: fixture.device
        )
        var expected = fixture
        // fixture는 스키마 1.0.0 때 내보낸 파일이다. 다시 내보내면 지금 스키마 버전이 적힌다
        expected.schemaVersion = ExportService.schemaVersion
        // D7 이전 파일이라 체중 알림 설정이 없다. 가져오면 기본값이 들어가 그대로 내보낸다
        expected.settings?.weightReminderEnabled = true
        expected.settings?.weightReminderHour = 8
        expected.settings?.weightReminderMinute = 0
        expected.weightSamples.removeAll { $0.source == "healthKit" }
        expected.strengthSessions.removeAll { $0.source == "healthKit" }
        #expect(exported == expected)
    }

    @Test func replaceImportClearsRecordsButKeepsDeviceSettings() throws {
        try seed()
        let settings = try UserSettings.current(in: context)
        settings.hasPurchasedPro = true
        settings.healthKitAuthorized = true
        try context.save()

        let fixture = try ExportFixture.document()
        _ = try ExportService.apply(fixture, mode: .replace, context: context, calendar: TestCalendar.seoul)

        #expect(try Set(context.fetch(FetchDescriptor<Prescription>()).map(\.id)) == Set(fixture.prescriptions.map(\.id)))
        #expect(try context.fetch(FetchDescriptor<Dose>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<WeightSample>()).map(\.kilograms) == [79.1])
        let after = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(after.count == 1)
        #expect(after.first?.hasPurchasedPro == true)
        #expect(after.first?.healthKitAuthorized == true)
        #expect(after.first?.proteinTargetGrams == 110)
        // fixture는 키가 없던 때의 파일이라 비어 있다
        #expect(after.first?.heightCm == nil)
    }

    /// D5: 키(heightCm)도 내보내고 교체 가져오기에서 되살린다. D7 체중 알림 설정도 같다
    @Test func heightRoundTripsThroughExport() throws {
        let settings = try UserSettings.current(in: context)
        settings.heightCm = 168.5
        settings.weightReminderWeekday = 3
        settings.weightReminderHour = 7
        try context.save()
        let data = try ExportCodec.encode(ExportService.makeDocument(context: context, now: TestCalendar.date(2026, 10, 24, 9)), timeZone: TestCalendar.seoul.timeZone)
        let document = try ExportCodec.decode(data)
        #expect(document.settings?.heightCm == 168.5)
        #expect(document.settings?.weightReminderWeekday == 3)

        settings.heightCm = nil
        settings.weightReminderWeekday = nil
        settings.weightReminderHour = 8
        try context.save()
        _ = try ExportService.apply(document, mode: .replace, context: context, calendar: TestCalendar.seoul)
        #expect(try UserSettings.current(in: context).heightCm == 168.5)
        #expect(try UserSettings.current(in: context).weightReminderWeekday == 3)
        #expect(try UserSettings.current(in: context).weightReminderHour == 7)
    }

    /// D6: 진료 때 물어볼 것도 내보내고 가져온다. 물어본 시각이 없으면 null
    @Test func clinicQuestionsRoundTripThroughExport() throws {
        context.insert(ClinicQuestion(text: "아직 묻지 않음", createdAt: TestCalendar.date(2026, 10, 20, 9)))
        context.insert(ClinicQuestion(text: "물어봄", askedAt: TestCalendar.date(2026, 10, 22, 10), createdAt: TestCalendar.date(2026, 10, 21, 9)))
        try context.save()
        let data = try ExportCodec.encode(ExportService.makeDocument(context: context, now: TestCalendar.date(2026, 10, 24, 9)), timeZone: TestCalendar.seoul.timeZone)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let records = try #require(object["clinicQuestions"] as? [[String: Any]])
        #expect(records.map { $0["text"] as? String } == ["아직 묻지 않음", "물어봄"])
        #expect(records.first?["askedAt"] is NSNull)

        let document = try ExportCodec.decode(data)
        let result = try ExportService.apply(document, mode: .replace, context: context, calendar: TestCalendar.seoul)
        #expect(result.clinicQuestions == ExportCodec.ImportResult.Count(imported: 2, skipped: 0))
        let stored = try context.fetch(FetchDescriptor<ClinicQuestion>(sortBy: [SortDescriptor(\.createdAt)]))
        #expect(stored.map(\.text) == ["아직 묻지 않음", "물어봄"])
        #expect(stored.map(\.askedAt) == [nil, TestCalendar.date(2026, 10, 22, 10)])

        let again = try ExportService.apply(document, mode: .add, context: context, calendar: TestCalendar.seoul)
        #expect(again.clinicQuestions == ExportCodec.ImportResult.Count(imported: 0, skipped: 2))
    }

    /// D20 진료 기록·검사 결과는 파일로 오가고, 검사지 사진은 파일에 없지만 교체 가져오기에서도 이 기기에 남는다
    @Test func clinicVisitsAndLabResultsRoundTripAndPhotosStay() throws {
        let visit = ClinicVisit(visitedAt: TestCalendar.date(2026, 10, 24, 10), note: "다음 진료 4주 뒤", createdAt: TestCalendar.date(2026, 10, 24, 11))
        context.insert(visit)
        let hba1c = LabResult(measuredAt: TestCalendar.date(2026, 10, 24), item: .hba1c, value: 5.9, unit: "%", createdAt: TestCalendar.date(2026, 10, 24, 11))
        context.insert(hba1c)
        hba1c.visit = visit
        let custom = LabResult(measuredAt: TestCalendar.date(2026, 10, 24), item: .custom, customName: "요산", value: 6.1, unit: "mg/dL", note: "참고치 3.5-7.2", createdAt: TestCalendar.date(2026, 10, 24, 11))
        context.insert(custom)
        let photo = ClinicPhoto(imageData: Data([1, 2, 3]))
        context.insert(photo)
        photo.visit = visit
        try context.save()

        let data = try ExportCodec.encode(ExportService.makeDocument(context: context, now: TestCalendar.date(2026, 10, 25, 9)), timeZone: TestCalendar.seoul.timeZone)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let labs = try #require(object["labResults"] as? [[String: Any]])
        #expect(labs.count == 2)
        #expect(labs.contains { $0["visitId"] is NSNull })
        #expect(object["clinicPhotos"] == nil)

        let document = try ExportCodec.decode(data)
        let result = try ExportService.apply(document, mode: .replace, context: context, calendar: TestCalendar.seoul)
        #expect(result.clinicVisits == ExportCodec.ImportResult.Count(imported: 1, skipped: 0))
        #expect(result.labResults == ExportCodec.ImportResult.Count(imported: 2, skipped: 0))
        let storedVisit = try #require(try context.fetch(FetchDescriptor<ClinicVisit>()).first)
        #expect(storedVisit.note == "다음 진료 4주 뒤")
        #expect(storedVisit.labResults?.map(\.item) == [.hba1c])
        #expect(storedVisit.photos?.first?.imageData == Data([1, 2, 3]))
        let storedCustom = try #require(try context.fetch(FetchDescriptor<LabResult>()).first { $0.item == .custom })
        #expect(storedCustom.customName == "요산")
        #expect(storedCustom.visit == nil)

        try ExportService.deleteAll(context: context)
        #expect(try context.fetch(FetchDescriptor<ClinicVisit>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<LabResult>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ClinicPhoto>()).isEmpty)
    }

    @Test func addImportTwiceSkipsEverythingTheSecondTime() throws {
        let fixture = try ExportFixture.document()
        _ = try ExportService.apply(fixture, mode: .add, context: context, calendar: TestCalendar.seoul)
        let second = try ExportService.apply(fixture, mode: .add, context: context, calendar: TestCalendar.seoul)

        #expect(second.prescriptions == ExportCodec.ImportResult.Count(imported: 0, skipped: 2))
        #expect(second.doses == ExportCodec.ImportResult.Count(imported: 0, skipped: 3))
        #expect(second.conditionChecks == ExportCodec.ImportResult.Count(imported: 0, skipped: 1))
        #expect(try context.fetch(FetchDescriptor<Dose>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<ConditionCheck>()).count == 1)
    }

    /// 규칙 7: 이 기기의 활성 처방과 파일의 활성 처방이 겹치면 늦게 시작한 쪽만 활성으로 남는다
    @Test func addImportResolvesTwoActivePrescriptions() throws {
        let local = Prescription(startDate: TestCalendar.date(2026, 10, 20, 9), penCount: 1, scheduledWeekday: 2, scheduledHour: 9)
        try Prescription.activate(local, in: context, calendar: TestCalendar.seoul)
        try context.save()

        let fixture = try ExportFixture.document()
        _ = try ExportService.apply(fixture, mode: .add, context: context, calendar: TestCalendar.seoul)

        let all = try context.fetch(FetchDescriptor<Prescription>())
        #expect(all.filter(\.isActive).map(\.id) == [local.id])
        let imported = try #require(all.first(where: { $0.id == fixture.prescriptions[1].id }))
        #expect(imported.endDate == TestCalendar.date(2026, 10, 19))
        // 가져온 투약은 파일의 처방에 붙는다
        #expect(imported.doses.count == 2)
    }

    @Test func deleteAllRemovesEverything() throws {
        try seed()
        try ExportService.deleteAll(context: context)
        #expect(try context.fetch(FetchDescriptor<Prescription>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Dose>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ConditionCheck>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WeightSample>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ClinicQuestion>()).isEmpty)
    }

    // N-I2: 검사지 사진을 날짜·순번 파일명으로. N-I3: 30일 안내 규칙
    @Test func clinicPhotoFilesAndBackupNotice() throws {
        let visit = ClinicVisit(visitedAt: TestCalendar.date(2026, 10, 24, 10))
        context.insert(visit)
        for index in 0..<2 {
            let photo = ClinicPhoto(imageData: Data([UInt8(index)]), createdAt: TestCalendar.date(2026, 10, 24, 11, index))
            context.insert(photo)
            photo.visit = visit
        }
        try context.save()
        let urls = try ExportService.writeClinicPhotoFiles(context: context, calendar: TestCalendar.seoul)
        defer { urls.forEach { try? FileManager.default.removeItem(at: $0) } }
        #expect(urls.map(\.lastPathComponent) == ["Masense_ClinicPhoto_2026-10-24_1.jpg", "Masense_ClinicPhoto_2026-10-24_2.jpg"])
        #expect(try Data(contentsOf: urls[1]) == Data([1]))

        let now = TestCalendar.date(2026, 10, 29, 9)
        #expect(!ExportService.backupNoticeNeeded(lastExport: nil, hasRecords: false, now: now, calendar: TestCalendar.seoul))
        #expect(ExportService.backupNoticeNeeded(lastExport: nil, hasRecords: true, now: now, calendar: TestCalendar.seoul))
        #expect(!ExportService.backupNoticeNeeded(lastExport: TestCalendar.date(2026, 10, 1), hasRecords: true, now: now, calendar: TestCalendar.seoul))
        #expect(ExportService.backupNoticeNeeded(lastExport: TestCalendar.date(2026, 9, 29), hasRecords: true, now: now, calendar: TestCalendar.seoul))
    }
}
