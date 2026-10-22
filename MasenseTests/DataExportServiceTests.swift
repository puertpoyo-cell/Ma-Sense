import Foundation
import SwiftData
import Testing

@testable import Masense

// 설정 > 데이터: 내보내기·전체 삭제
@MainActor
struct DataExportServiceTests {
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
        _ = try UserSettings.current(in: context)
        try context.save()
    }

    @Test func exportRoundTripsThroughJSON() throws {
        try seed()
        let export = try DataExportService.makeExport(context: context, now: TestCalendar.date(2026, 10, 24, 9))
        #expect(export.prescriptions.count == 1)
        #expect(export.prescriptions[0].memo == "메모")
        #expect(export.prescriptions[0].doses.count == 1)
        #expect(export.prescriptions[0].doses[0].note == "왼쪽")
        #expect(export.prescriptions[0].doses[0].conditionChecks.first?.symptoms == [SymptomEntry(symptom: .nausea, severity: 1)])
        #expect(export.weights.map(\.kilograms) == [80.4])

        let decoded = try DataExportService.decode(DataExportService.encode(export))
        #expect(decoded == export)
    }

    @Test func exportFileNameUsesDate() throws {
        try seed()
        let url = try DataExportService.writeExportFile(context: context, now: TestCalendar.date(2026, 10, 24, 9), calendar: TestCalendar.seoul)
        #expect(url.lastPathComponent == "Masense_Export_2026-10-24.json")
        #expect(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    @Test func deleteAllRemovesEverything() throws {
        try seed()
        try DataExportService.deleteAll(context: context)
        #expect(try context.fetch(FetchDescriptor<Prescription>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Dose>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ConditionCheck>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WeightSample>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).isEmpty)
    }
}
