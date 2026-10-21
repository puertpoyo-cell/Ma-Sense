import Foundation
import SwiftData
import Testing

@testable import Masense

// S9 처방 입력 폼 저장 규칙
@MainActor
struct PrescriptionFormModelTests {
    private let container: ModelContainer
    private let calendar = TestCalendar.seoul
    /// 목요일
    private let now = TestCalendar.date(2026, 10, 22, 9)

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    @Test func newPrescriptionDefaults() {
        let model = PrescriptionFormModel(now: now, calendar: calendar)
        #expect(!model.isEditing)
        #expect(model.startDate == TestCalendar.date(2026, 10, 22))
        #expect(model.scheduledWeekday == 5)
        #expect(calendar.component(.hour, from: model.scheduledTime) == 20)
        #expect(model.totalDoses == 4)
        #expect(!model.hasNextClinicDate)
        #expect(model.isValid)
    }

    @Test func saveCreatesActivePrescriptionAndTrimsMemo() throws {
        let model = PrescriptionFormModel(now: now, calendar: calendar)
        model.penCount = 3
        model.scheduledTime = TestCalendar.date(2026, 10, 22, 8, 30)
        model.doseLabel = "  두 번째 단계  "

        let saved = try model.save(in: container.mainContext)
        #expect(saved.isActive)
        #expect(saved.totalDoses == 12)
        #expect(saved.scheduledHour == 8)
        #expect(saved.scheduledMinute == 30)
        #expect(saved.doseLabel == "두 번째 단계")
        #expect(saved.nextClinicDate == nil)
    }

    @Test func emptyMemoIsStoredAsNil() throws {
        let model = PrescriptionFormModel(now: now, calendar: calendar)
        model.doseLabel = "   "
        #expect(try model.save(in: container.mainContext).doseLabel == nil)
    }

    @Test func newPrescriptionArchivesPrevious() throws {
        let context = container.mainContext
        let first = try PrescriptionFormModel(now: now, calendar: calendar).save(in: context)
        let second = try PrescriptionFormModel(now: now, calendar: calendar).save(in: context)
        #expect(!first.isActive)
        #expect(second.isActive)
        #expect(try Prescription.active(in: context)?.persistentModelID == second.persistentModelID)
    }

    @Test func editingUpdatesInPlace() throws {
        let context = container.mainContext
        let original = try PrescriptionFormModel(now: now, calendar: calendar).save(in: context)

        let edit = PrescriptionFormModel(editing: original, now: now, calendar: calendar)
        #expect(edit.isEditing)
        #expect(edit.penCount == 1)
        edit.penCount = 2
        edit.hasNextClinicDate = true
        edit.nextClinicDate = TestCalendar.date(2026, 11, 19)
        let saved = try edit.save(in: context)

        #expect(saved.persistentModelID == original.persistentModelID)
        #expect(saved.isActive)
        #expect(saved.totalDoses == 8)
        #expect(saved.nextClinicDate == TestCalendar.date(2026, 11, 19))
        #expect(try context.fetch(FetchDescriptor<Prescription>()).count == 1)
    }

    @Test func invalidCountsAreRejected() {
        let model = PrescriptionFormModel(now: now, calendar: calendar)
        model.penCount = 0
        #expect(!model.isValid)
    }
}
