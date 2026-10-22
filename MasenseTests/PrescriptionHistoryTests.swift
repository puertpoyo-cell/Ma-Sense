import Foundation
import SwiftData
import Testing

@testable import Masense

// SCREENS.md S6 설정 > 처방 > 이전 처방 목록
@MainActor
struct PrescriptionHistoryTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    @Test func listsArchivedPrescriptionsNewestFirst() throws {
        let context = container.mainContext
        let first = Prescription(startDate: TestCalendar.date(2026, 7, 3), penCount: 1, scheduledWeekday: 5, scheduledHour: 20, doseLabel: "  ")
        let second = Prescription(startDate: TestCalendar.date(2026, 8, 7), penCount: 2, scheduledWeekday: 5, scheduledHour: 20, doseLabel: " 두 번째 ")
        let current = Prescription(startDate: TestCalendar.date(2026, 9, 4), penCount: 1, scheduledWeekday: 5, scheduledHour: 20)
        for prescription in [first, second, current] {
            try Prescription.activate(prescription, in: context, calendar: TestCalendar.seoul)
        }
        let administered = TestCalendar.date(2026, 8, 13, 20)
        for cancelled in [false, false, true] {
            let dose = Dose(administeredAt: administered, scheduledFor: administered, site: .thighLeft, sequence: 1, isCancelled: cancelled)
            context.insert(dose)
            dose.prescription = second
        }
        try context.save()

        let rows = PrescriptionHistory.rows(try context.fetch(FetchDescriptor<Prescription>()))

        // 현재 처방은 빠지고, 최근 시작 순
        #expect(rows.map(\.id) == [second.id, first.id])
        #expect(rows[0].endDate == TestCalendar.date(2026, 9, 3))
        #expect(rows[0].memo == "두 번째")
        // 취소한 기록은 세지 않는다
        #expect(rows[0].recordedDoses == 2)
        #expect(rows[0].totalDoses == 8)
        #expect(rows[1].endDate == TestCalendar.date(2026, 8, 6))
        #expect(rows[1].memo == nil)
        #expect(rows[1].recordedDoses == 0)
    }

    @Test func emptyWithOnlyActivePrescription() throws {
        let context = container.mainContext
        let current = Prescription(startDate: TestCalendar.date(2026, 9, 4), penCount: 1, scheduledWeekday: 5, scheduledHour: 20)
        try Prescription.activate(current, in: context, calendar: TestCalendar.seoul)
        try context.save()
        #expect(PrescriptionHistory.rows(try context.fetch(FetchDescriptor<Prescription>())).isEmpty)
    }
}
