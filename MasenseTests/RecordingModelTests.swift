import Foundation
import SwiftData
import Testing

@testable import Masense

// S2 투약 기록, S3 컨디션 체크, 체중 입력 저장 규칙
@MainActor
struct RecordingModelTests {
    private let container: ModelContainer
    private let calendar = TestCalendar.seoul

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    private var context: ModelContext { container.mainContext }

    private func makePrescription() throws -> Prescription {
        let prescription = Prescription(
            startDate: TestCalendar.date(2026, 10, 16, 9),
            penCount: 2,
            dosesPerPen: 4,
            scheduledWeekday: 5,
            scheduledHour: 20
        )
        try Prescription.activate(prescription, in: context)
        return prescription
    }

    // MARK: S2

    @Test func doseLogDefaultsAndValidation() throws {
        let model = DoseLogModel(prescription: try makePrescription(), now: TestCalendar.date(2026, 10, 22, 20, 30), calendar: calendar)
        #expect(model.sequence == 1)
        #expect(model.site == nil)
        #expect(!model.canSave)
        #expect(model.history.isEmpty)
        // 처음 기록할 때는 지난 투약 안내가 없다
        #expect(model.lastDoseNote == nil)
        #expect(try model.save(in: context)?.id == nil)
    }

    @Test func doseLogSavesWithCycleScheduledDate() throws {
        let prescription = try makePrescription()
        let now = TestCalendar.date(2026, 10, 22, 20, 30)
        let model = DoseLogModel(prescription: prescription, now: now, calendar: calendar)
        model.site = .abdomenUpperRight
        model.note = "  "

        let dose = try #require(try model.save(in: context))
        #expect(dose.scheduledFor == TestCalendar.date(2026, 10, 22, 20))
        #expect(dose.sequence == 1)
        #expect(dose.note == nil)
        #expect(dose.prescription?.persistentModelID == prescription.persistentModelID)
        #expect(prescription.usedDoses == 1)

        let next = DoseLogModel(prescription: prescription, now: TestCalendar.date(2026, 10, 29, 20), calendar: calendar)
        #expect(next.sequence == 2)
        #expect(next.history.first?.site == .abdomenUpperRight)
    }

    /// R6: 부위는 몸 기준이라 새 처방에서도 이전 처방의 기록을 보여 준다. 지난 투약 안내는 사실만
    @Test func doseLogShowsSitesAcrossPrescriptions() throws {
        let old = try makePrescription()
        let administered = TestCalendar.date(2026, 10, 22, 20, 5)
        let dose = Dose(administeredAt: administered, scheduledFor: TestCalendar.date(2026, 10, 22, 20), site: .thighLeft, sequence: 1)
        context.insert(dose)
        dose.prescription = old
        let new = Prescription(startDate: TestCalendar.date(2026, 10, 27, 9), penCount: 1, scheduledWeekday: 5, scheduledHour: 20)
        try Prescription.activate(new, in: context, calendar: calendar)
        try context.save()

        let model = DoseLogModel(prescription: new, now: TestCalendar.date(2026, 10, 29, 19), calendar: calendar)
        #expect(model.sequence == 1)
        #expect(model.history.map(\.site) == [.thighLeft])
        #expect(model.lastUseBySite == [.thighLeft: administered])
        #expect(model.lastDoseNote == LastDoseNote(site: .thighLeft, date: administered, daysAgo: 7))
    }

    // D25: 기본 시각은 지금을 내림한 가장 최근 30분
    @Test func doseLogDefaultsToLatestHalfHour() throws {
        let model = DoseLogModel(prescription: try makePrescription(), now: TestCalendar.date(2026, 10, 22, 20, 47), calendar: calendar)
        #expect(model.administeredAt == TestCalendar.date(2026, 10, 22, 20, 30))
    }

    @Test func backdatedDoseClearsMissedCycle() throws {
        let prescription = try makePrescription()
        let now = TestCalendar.date(2026, 10, 30, 9)
        let model = DoseLogModel(prescription: prescription, now: now, calendar: calendar)
        model.site = .thighRight
        model.administeredAt = TestCalendar.date(2026, 10, 23, 8)

        let dose = try #require(try model.save(in: context))
        #expect(dose.scheduledFor == TestCalendar.date(2026, 10, 22, 20))

        let cycles = CycleRules.cycles(for: prescription.snapshot, doses: prescription.doseSnapshots, now: now, until: .distantFuture, calendar: calendar)
        #expect(CycleRules.missedCycles(cycles: cycles, doses: prescription.doseSnapshots, now: now).isEmpty)
    }

    @Test func penPositionFollowsSequence() throws {
        let model = DoseLogModel(prescription: try makePrescription(), now: TestCalendar.date(2026, 10, 22, 20), calendar: calendar)
        model.sequence = 5
        #expect(model.penPosition == (pen: 2, position: 1))
    }

    // MARK: S3

    @Test func conditionCheckKeepsOnlyNonZeroSymptoms() throws {
        let prescription = try makePrescription()
        let doseModel = DoseLogModel(prescription: prescription, now: TestCalendar.date(2026, 10, 22, 20, 30), calendar: calendar)
        doseModel.site = .thighLeft
        let dose = try #require(try doseModel.save(in: context))

        let model = ConditionCheckModel(dose: dose, window: .h24)
        model.setSeverity(2, for: .nausea)
        model.setSeverity(0, for: .fatigue)
        model.setSeverity(9, for: .headache)
        model.appetite = .reduced
        #expect(model.entries == [
            SymptomEntry(symptom: .nausea, severity: 2),
            SymptomEntry(symptom: .headache, severity: 3),
        ])
        #expect(model.hasSevereSymptom)

        let checkedAt = TestCalendar.date(2026, 10, 23, 12)
        let check = try model.save(in: context, now: checkedAt)
        #expect(check.dose?.persistentModelID == dose.persistentModelID)
        #expect(check.appetite == .reduced)
        #expect(check.hasSevereSymptom)

        // 응답한 창은 홈에서 닫힌다 (R5)
        let snapshots = [check].compactMap(\.snapshot)
        #expect(ConditionRules.openConditionWindows(dose: dose.snapshot, checks: snapshots, now: checkedAt).isEmpty)
    }

    // MARK: 체중

    @Test func weightParsing() {
        #expect(WeightEntryModel.parse("79.5") == 79.5)
        #expect(WeightEntryModel.parse("79,5") == 79.5)
        #expect(WeightEntryModel.parse(" 80 ") == 80)
        #expect(WeightEntryModel.parse("abc") == nil)
        #expect(WeightEntryModel.parse("10") == nil)
        #expect(WeightEntryModel.parse("") == nil)
    }

    @Test func weightSaveIsManual() throws {
        let model = WeightEntryModel(now: TestCalendar.date(2026, 10, 22, 8))
        model.text = "81.2"
        let sample = try #require(try model.save(in: context))
        #expect(sample.source == .manual)
        #expect(sample.kilograms == 81.2)
        #expect(sample.healthKitUUID == nil)
    }

    // MARK: 문자열

    @Test func runtimeKeysResolveToTranslations() {
        #expect(!BodySite.thighLeft.localizedName.hasPrefix("site."))
        #expect(!Symptom.nausea.localizedName.hasPrefix("symptom."))
        #expect(!SymptomChip.severityLabel(3).hasPrefix("severity."))
    }
}
