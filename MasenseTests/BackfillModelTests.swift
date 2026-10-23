import Foundation
import SwiftData
import Testing

@testable import Masense

// 지난 투약 한꺼번에 입력 (D6, RULES.md R3-1)
@MainActor
struct BackfillModelTests {
    private let container: ModelContainer
    private let calendar = TestCalendar.seoul
    /// 2026-10-23(금) 10:00
    private let now = TestCalendar.date(2026, 10, 23, 10)

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    private var context: ModelContext { container.mainContext }

    /// 목요일 20:00, 2026-09-24 시작, 1펜 4회. 9-24, 10-1, 10-8, 10-15 마디가 비어 있다
    private func makePrescription(penCount: Int = 1) throws -> Prescription {
        let prescription = Prescription(
            startDate: TestCalendar.date(2026, 9, 24, 9),
            penCount: penCount,
            dosesPerPen: 4,
            scheduledWeekday: 5,
            scheduledHour: 20
        )
        try Prescription.activate(prescription, in: context, calendar: calendar)
        return prescription
    }

    @Test func savesSelectedWeeksWithUnknownSitesAndShiftsLaterRecords() throws {
        let prescription = try makePrescription(penCount: 2)
        let today = Dose(administeredAt: TestCalendar.date(2026, 10, 22, 20, 10), scheduledFor: TestCalendar.date(2026, 10, 22, 20), site: .thighLeft, sequence: 1)
        context.insert(today)
        today.prescription = prescription
        try context.save()

        let model = BackfillModel(prescription: prescription, now: now, calendar: calendar)
        #expect(model.rows.map(\.cycle.scheduledDate) == [
            TestCalendar.date(2026, 9, 24, 20),
            TestCalendar.date(2026, 10, 1, 20),
            TestCalendar.date(2026, 10, 8, 20),
            TestCalendar.date(2026, 10, 15, 20),
        ])
        // 남은 회차(7)가 넉넉하면 모두 켜고 부위는 비워 둔다
        #expect(model.rows.allSatisfy { $0.isIncluded && $0.site == nil })
        try #require(model.rows.count == 4)
        model.rows[0].isIncluded = false
        model.rows[2].site = .abdomenLowerRight
        #expect(model.renumberedCount == 1)

        #expect(try model.save(in: context) == 3)
        let doses = prescription.doses.sorted { $0.administeredAt < $1.administeredAt }
        try #require(doses.count == 4)
        #expect(doses.map(\.administeredAt) == [
            TestCalendar.date(2026, 10, 1, 20),
            TestCalendar.date(2026, 10, 8, 20),
            TestCalendar.date(2026, 10, 15, 20),
            TestCalendar.date(2026, 10, 22, 20, 10),
        ])
        #expect(doses.map(\.sequence) == [1, 2, 3, 4])
        #expect(doses.map(\.site) == [nil, .abdomenLowerRight, nil, .thighLeft])
        #expect(doses[0].siteRaw == Dose.unknownSiteRaw)
        #expect(doses.map(\.scheduledFor).prefix(3) == doses.map(\.administeredAt).prefix(3))
    }

    @Test func cannotTurnOnMoreWeeksThanRemainingDoses() throws {
        let prescription = try makePrescription(penCount: 1)
        let model = BackfillModel(prescription: prescription, now: now, calendar: calendar)
        // 1펜 4회, 기록 없음: 남은 회차 4, 비어 있는 주도 4개라 모두 켠다
        #expect(model.remaining == 4)
        #expect(model.selectedCount == 4)

        let small = Prescription(startDate: TestCalendar.date(2026, 9, 24, 9), penCount: 1, dosesPerPen: 2, scheduledWeekday: 5, scheduledHour: 20)
        try Prescription.activate(small, in: context, calendar: calendar)
        let capped = BackfillModel(prescription: small, now: now, calendar: calendar)
        #expect(capped.remaining == 2)
        // 최근 두 주만 켜 두고, 꺼진 주는 더 켤 수 없다
        #expect(capped.rows.map(\.isIncluded) == [false, false, true, true])
        try #require(capped.rows.count == 4)
        #expect(!capped.canToggle(capped.rows[0]))
        #expect(capped.canToggle(capped.rows[3]))
        #expect(capped.canSave)
    }
}
