import Foundation
import Testing

@testable import Masense

// RULES.md R13
struct PrescriptionRulesTests {
    private let calendar = TestCalendar.seoul

    private func prescription(totalDoses: Int = 12) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, dosesPerPen: 4, totalDoses: totalDoses)
    }

    private func dose(_ month: Int, _ day: Int, isCancelled: Bool = false) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, 20)
        return DoseSnapshot(administeredAt: date, scheduledFor: date, site: .abdomenLowerLeft, sequence: 1, isCancelled: isCancelled)
    }

    @Test func remainingAndSequence() {
        let doses = [dose(10, 22), dose(10, 29), dose(11, 5, isCancelled: true)]
        #expect(PrescriptionRules.usedDoses(doses) == 2)
        #expect(PrescriptionRules.remainingDoses(p: prescription(), doses: doses) == 10)
        #expect(PrescriptionRules.nextSequence(doses: doses) == 3)
        #expect(PrescriptionRules.remainingDoses(p: prescription(totalDoses: 1), doses: doses) == 0)
    }

    @Test func penPosition() {
        #expect(PrescriptionRules.penPosition(sequence: 1, dosesPerPen: 4) == (pen: 1, position: 1))
        #expect(PrescriptionRules.penPosition(sequence: 4, dosesPerPen: 4) == (pen: 1, position: 4))
        #expect(PrescriptionRules.penPosition(sequence: 5, dosesPerPen: 4) == (pen: 2, position: 1))
        #expect(PrescriptionRules.penPosition(sequence: 3, dosesPerPen: 0) == (pen: 1, position: 3))
    }

    /// R13-1 (D7): 쓴 회차를 앞 펜부터 채운다. 취소는 세지 않는다
    @Test func penStatusFillsPensInOrder() {
        let p = PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, dosesPerPen: 4, totalDoses: 16)
        let doses = [dose(10, 22), dose(10, 29), dose(11, 5), dose(11, 12), dose(11, 19), dose(11, 26, isCancelled: true), dose(12, 3)]
        let status = PrescriptionRules.penStatus(p: p, doses: doses)
        #expect(status.usedPerPen == [4, 2, 0, 0])
        #expect(status.penCount == 4)
        #expect(status.remainingPens == 3)
        #expect(status.remainingDoses == 10)

        // 한 번 쓰는 키트 4개
        let kits = PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, dosesPerPen: 1, totalDoses: 4)
        let three = PrescriptionRules.penStatus(p: kits, doses: Array(doses.prefix(3)))
        #expect(three.usedPerPen == [1, 1, 1, 0])
        #expect(three.remainingPens == 1)
        // 처방보다 많이 기록해도 넘치지 않는다
        #expect(PrescriptionRules.penStatus(p: kits, doses: doses).usedPerPen == [1, 1, 1, 1])
        #expect(PrescriptionRules.penStatus(p: kits, doses: doses).remainingPens == 0)
    }

    /// 1회용 펜은 패키지(펜 4개, 약 한 달)로 묶고, 여러 회 쓰는 펜은 펜 하나가 묶음 하나
    @Test func packagesGroupSingleUsePensByFour() {
        let twoPackages = PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, dosesPerPen: 1, totalDoses: 8)
        let status = PrescriptionRules.penStatus(p: twoPackages, doses: [dose(10, 22), dose(10, 29), dose(11, 5), dose(11, 12), dose(11, 19)])
        #expect(status.isSingleUse)
        #expect(status.packages == [[1, 1, 1, 1], [1, 0, 0, 0]])
        #expect(status.remainingPens == 3)

        let multi = PrescriptionSnapshot(startDate: TestCalendar.date(2026, 10, 16, 9), scheduledWeekday: 5, scheduledHour: 20, dosesPerPen: 4, totalDoses: 8)
        #expect(PrescriptionRules.penStatus(p: multi, doses: [dose(10, 22)]).packages == [[1], [0]])

        #expect(PrescriptionRules.packagePosition(sequence: 1) == (package: 1, pen: 1))
        #expect(PrescriptionRules.packagePosition(sequence: 4) == (package: 1, pen: 4))
        #expect(PrescriptionRules.packagePosition(sequence: 6) == (package: 2, pen: 2))
    }

    /// R13-2 (D7): 처방 시작 순서대로 색 자리를 돌려 쓴다. 입력 순서와 무관
    @Test func colorSlotsFollowStartOrderAndWrap() {
        let dates = [
            TestCalendar.date(2026, 12, 1),
            TestCalendar.date(2026, 9, 1),
            TestCalendar.date(2027, 1, 1),
            TestCalendar.date(2026, 10, 1),
            TestCalendar.date(2026, 11, 1),
        ]
        #expect(PrescriptionRules.colorSlots(startDates: dates) == [3, 0, 0, 1, 2])
        #expect(PrescriptionRules.colorSlots(startDates: []).isEmpty)
    }

    @Test func exhaustionEstimateIsLastCycle() {
        let now = TestCalendar.date(2026, 10, 16, 9)
        #expect(PrescriptionRules.exhaustionEstimate(p: prescription(), doses: [], now: now, calendar: calendar) == TestCalendar.date(2027, 1, 7, 20))
    }

    @Test func exhaustionEstimateShiftsWithMissedCycles() {
        // 2회차, 두 마디 누락 뒤 → 11-05, 11-12에 쓰므로 소진 예상 11-12
        let now = TestCalendar.date(2026, 11, 5, 9)
        #expect(PrescriptionRules.exhaustionEstimate(p: prescription(totalDoses: 2), doses: [], now: now, calendar: calendar) == TestCalendar.date(2026, 11, 12, 20))
    }

    @Test func exhaustionEstimateIsNilWhenNothingRemains() {
        let now = TestCalendar.date(2026, 10, 23, 9)
        #expect(PrescriptionRules.exhaustionEstimate(p: prescription(totalDoses: 1), doses: [dose(10, 22)], now: now, calendar: calendar) == nil)
    }

    // MARK: 처방 전환 타임라인 (R13, main C)

    private func chain(_ startMonth: Int, _ startDay: Int, end: (Int, Int)? = nil, label: String? = nil) -> PrescriptionSnapshot {
        PrescriptionSnapshot(
            startDate: TestCalendar.date(2026, startMonth, startDay),
            scheduledWeekday: 5,
            scheduledHour: 20,
            totalDoses: 4,
            endDate: end.map { TestCalendar.date(2026, $0.0, $0.1) },
            doseLabel: label
        )
    }

    @Test func timelineMarksPrescriptionsOverlappingPeriod() {
        let all = [
            chain(10, 16, label: "세 번째"),
            chain(8, 1, end: (8, 31), label: "첫 번째"),
            chain(9, 1, end: (10, 15), label: "  "),
        ]
        let period = DateInterval(start: TestCalendar.date(2026, 9, 10), end: TestCalendar.date(2026, 11, 5))
        let markers = PrescriptionRules.prescriptionTimeline(all: all, in: period, calendar: calendar)
        // 8월 처방은 기간 전에 끝나 빠진다. 9월 처방은 기간 시작 전에 시작해 isFirstInPeriod
        #expect(markers == [
            PrescriptionMarker(startDate: TestCalendar.date(2026, 9, 1), label: nil, isFirstInPeriod: true),
            PrescriptionMarker(startDate: TestCalendar.date(2026, 10, 16), label: "세 번째", isFirstInPeriod: false),
        ])
        #expect(PrescriptionRules.transitionCount(markers) == 1)
    }

    @Test func timelineWithSinglePrescriptionStartingInsidePeriod() {
        let period = DateInterval(start: TestCalendar.date(2026, 10, 1), end: TestCalendar.date(2026, 11, 5))
        let markers = PrescriptionRules.prescriptionTimeline(all: [chain(10, 16)], in: period, calendar: calendar)
        #expect(markers == [PrescriptionMarker(startDate: TestCalendar.date(2026, 10, 16), label: nil, isFirstInPeriod: false)])
        // 처음 시작한 처방은 전환이 아니다
        #expect(PrescriptionRules.transitionCount(markers) == 0)
        #expect(PrescriptionRules.prescriptionTimeline(all: [], in: period, calendar: calendar).isEmpty)
        // 기간 뒤에 시작하는 처방은 빠진다
        #expect(PrescriptionRules.prescriptionTimeline(all: [chain(11, 20)], in: period, calendar: calendar).isEmpty)
    }

    // MARK: 활성 처방 하나로 맞추기 (EXPORT_FORMAT.md 가져오기 규칙 7)

    @Test func resolvingActiveKeepsLatestStartAndEndsOthersBeforeNext() {
        let archived = PrescriptionSpan(id: UUID(), startDate: TestCalendar.date(2026, 8, 7), endDate: TestCalendar.date(2026, 9, 3), isActive: false)
        let imported = PrescriptionSpan(id: UUID(), startDate: TestCalendar.date(2026, 9, 4), endDate: nil, isActive: true)
        let local = PrescriptionSpan(id: UUID(), startDate: TestCalendar.date(2026, 10, 1, 9), endDate: nil, isActive: true)

        let resolved = PrescriptionRules.resolvingActive([local, archived, imported], calendar: calendar)

        // 입력 순서 유지. 늦게 시작한 처방만 활성, 다른 활성 처방은 다음 처방 시작 전날로 끝난다
        #expect(resolved == [
            local,
            archived,
            PrescriptionSpan(id: imported.id, startDate: imported.startDate, endDate: TestCalendar.date(2026, 9, 30), isActive: false),
        ])
    }

    @Test func resolvingActiveWithSameDayStartsEndsOnOwnStart() {
        let morning = PrescriptionSpan(id: UUID(), startDate: TestCalendar.date(2026, 10, 1, 9), endDate: nil, isActive: true)
        let evening = PrescriptionSpan(id: UUID(), startDate: TestCalendar.date(2026, 10, 1, 21), endDate: nil, isActive: true)
        let resolved = PrescriptionRules.resolvingActive([morning, evening], calendar: calendar)
        #expect(resolved[0] == PrescriptionSpan(id: morning.id, startDate: morning.startDate, endDate: TestCalendar.date(2026, 10, 1), isActive: false))
        #expect(resolved[1] == evening)
    }

    @Test func resolvingActiveLeavesSingleActiveChainAlone() {
        let spans = [
            PrescriptionSpan(id: UUID(), startDate: TestCalendar.date(2026, 8, 7), endDate: TestCalendar.date(2026, 9, 3), isActive: false),
            PrescriptionSpan(id: UUID(), startDate: TestCalendar.date(2026, 9, 4), endDate: nil, isActive: true),
        ]
        #expect(PrescriptionRules.resolvingActive(spans, calendar: calendar) == spans)
        #expect(PrescriptionRules.resolvingActive([], calendar: calendar).isEmpty)
    }
}
