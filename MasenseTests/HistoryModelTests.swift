import Foundation
import Testing

@testable import Masense

// S4 기록 탭 목록. 목요일 20:00, 7일 간격
struct HistoryModelTests {
    private let calendar = TestCalendar.seoul

    private func prescription(start: Date, totalDoses: Int = 12) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: start, scheduledWeekday: 5, scheduledHour: 20, totalDoses: totalDoses)
    }

    private func dose(_ month: Int, _ day: Int, note: String? = nil, isCancelled: Bool = false, createdAt: Date? = nil) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, 20)
        return DoseSnapshot(
            administeredAt: date, scheduledFor: date, site: .thighLeft, sequence: 1,
            isCancelled: isCancelled, note: note, createdAt: createdAt
        )
    }

    @Test func monthsAreNewestFirstWithMissedRows() {
        // 10-22 기록, 10-29 누락, 11-05 기록, 지금 11-12 09:00 (11-12 마디는 진행 중이라 누락 아님)
        let history = HistoryModel.PrescriptionHistory(
            prescription: prescription(start: TestCalendar.date(2026, 10, 16, 9)),
            doses: [dose(10, 22), dose(11, 5, note: "메모")],
            isActive: true
        )
        let months = HistoryModel.doseMonths([history], now: TestCalendar.date(2026, 11, 12, 9), calendar: calendar)

        #expect(months.map(\.start) == [TestCalendar.date(2026, 11, 1), TestCalendar.date(2026, 10, 1)])
        #expect(months[0].rows.count == 1)
        guard case let .dose(_, _, _, hasNote, _) = months[0].rows[0].kind else {
            Issue.record("expected dose row")
            return
        }
        #expect(hasNote)
        #expect(months[1].rows.map(\.date) == [TestCalendar.date(2026, 10, 29, 20), TestCalendar.date(2026, 10, 22, 20)])
        #expect(months[1].rows[0].kind == .missed(scheduled: TestCalendar.date(2026, 10, 29, 20), canAddDose: true))
    }

    @Test func archivedPrescriptionStopsAtNextStart() {
        // 이전 처방: 10-22 기록 뒤 10-27에 새 처방 시작. 이전 처방에서 10-29 이후 누락이 생기면 안 된다
        let old = HistoryModel.PrescriptionHistory(
            prescription: prescription(start: TestCalendar.date(2026, 10, 16, 9)),
            doses: [dose(10, 22)],
            isActive: false
        )
        let new = HistoryModel.PrescriptionHistory(
            prescription: prescription(start: TestCalendar.date(2026, 10, 27, 9)),
            doses: [dose(10, 29)],
            isActive: true
        )
        let months = HistoryModel.doseMonths([new, old], now: TestCalendar.date(2026, 11, 20, 9), calendar: calendar)
        let missed = months.flatMap(\.rows).filter {
            if case .missed = $0.kind { return true } else { return false }
        }
        // 새 처방의 11-05, 11-12만 누락 (11-19 마디는 아직 진행 중)
        #expect(missed.map(\.date) == [TestCalendar.date(2026, 11, 12, 20), TestCalendar.date(2026, 11, 5, 20)])
        #expect(missed.allSatisfy { $0.kind == .missed(scheduled: $0.date, canAddDose: true) })
    }

    /// R13: 두 번째 처방부터 시작일에 "처방 변경" 구분 행. 라벨은 메모 그대로
    @Test func prescriptionChangeRowAtEachLaterStart() {
        let old = HistoryModel.PrescriptionHistory(
            prescription: PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20,
                                               totalDoses: 12, endDate: TestCalendar.date(2026, 10, 26), doseLabel: "첫 처방"),
            doses: [dose(10, 22)],
            isActive: false
        )
        let new = HistoryModel.PrescriptionHistory(
            prescription: PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 27, 9), scheduledWeekday: 5, scheduledHour: 20,
                                               totalDoses: 12, doseLabel: " 두 번째 "),
            doses: [dose(10, 29)],
            isActive: true
        )
        let rows = HistoryModel.doseMonths([new, old], now: TestCalendar.date(2026, 10, 30, 9), calendar: calendar).flatMap(\.rows)
        let changes = rows.filter { if case .prescriptionChange = $0.kind { return true } else { return false } }
        #expect(changes.map(\.date) == [TestCalendar.date(2026, 10, 27, 9)])
        #expect(changes.first?.kind == .prescriptionChange(label: "두 번째"))
        // 최근 순: 새 처방의 투약 → 처방 변경 → 이전 처방의 투약
        #expect(rows.map(\.date) == [TestCalendar.date(2026, 10, 29, 20), TestCalendar.date(2026, 10, 27, 9), TestCalendar.date(2026, 10, 22, 20)])
    }

    @Test func cancelledDoseStaysVisibleAndLeavesCycleMissed() {
        let history = HistoryModel.PrescriptionHistory(
            prescription: prescription(start: TestCalendar.date(2026, 10, 16, 9)),
            doses: [dose(10, 22, isCancelled: true)],
            isActive: true
        )
        let rows = HistoryModel.doseMonths([history], now: TestCalendar.date(2026, 10, 30, 9), calendar: calendar).flatMap(\.rows)
        #expect(rows.count == 2)
        #expect(rows.contains { $0.kind == .missed(scheduled: TestCalendar.date(2026, 10, 22, 20), canAddDose: true) })
        #expect(rows.contains {
            if case let .dose(_, _, _, _, isCancelled) = $0.kind { return isCancelled } else { return false }
        })
    }

    @Test func conditionGroupsSummarizeAndHideUnopenedWindows() {
        let first = dose(10, 22)
        let second = dose(10, 29)
        let checks = [
            ConditionCheckSnapshot(
                doseID: first.id,
                window: .h24,
                checkedAt: TestCalendar.date(2026, 10, 23, 20),
                symptoms: [SymptomEntry(symptom: .nausea, severity: 2), SymptomEntry(symptom: .fatigue, severity: 3)],
                appetite: .reduced
            ),
        ]
        // 지금 10-30 10:00: second는 투약 후 14시간 → h24만 열림
        let groups = HistoryModel.conditionGroups(doses: [first, second], checks: checks, now: TestCalendar.date(2026, 10, 30, 10))

        #expect(groups.map(\.doseID) == [second.id, first.id])
        #expect(groups[0].slots == [HistoryModel.ConditionSlot(window: .h24, state: .missing)])
        #expect(groups[1].slots == [
            HistoryModel.ConditionSlot(window: .h24, state: .recorded(symptomCount: 2, maxSeverity: 3, appetite: .reduced)),
            HistoryModel.ConditionSlot(window: .h48, state: .missing),
        ])
    }

    @Test func conditionGroupsSkipCancelledAndTooRecentDoses() {
        let cancelled = dose(10, 22, isCancelled: true)
        let recent = dose(10, 29)
        let groups = HistoryModel.conditionGroups(doses: [cancelled, recent], checks: [], now: TestCalendar.date(2026, 10, 29, 21))
        #expect(groups.isEmpty)
    }

    /// D6: 컨디션 창(투약 후 96시간)이 닫힌 뒤에 만든 기록은 체크가 없으면 빈칸을 만들지 않는다 (지난 투약 한꺼번에 입력)
    @Test func conditionGroupsSkipDosesRecordedAfterTheWindows() {
        let now = TestCalendar.date(2026, 10, 30, 10)
        let backfilled = dose(10, 8, createdAt: now)
        let backfilledChecked = dose(10, 15, createdAt: now)
        let onTime = dose(10, 22, createdAt: TestCalendar.date(2026, 10, 22, 20, 5))
        let check = ConditionCheckSnapshot(doseID: backfilledChecked.id, window: .h24, checkedAt: now)
        let groups = HistoryModel.conditionGroups(doses: [backfilled, backfilledChecked, onTime], checks: [check], now: now)
        #expect(groups.map(\.doseID) == [onTime.id, backfilledChecked.id])
    }
}
