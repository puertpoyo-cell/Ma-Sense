import Foundation
import Testing

@testable import Masense

// REPORT_SPEC.md, RULES.md R12. 목요일 20:00, 7일 간격, 2026-10-16(금) 시작, 12회차
struct ReportBuilderTests {
    private let calendar = TestCalendar.seoul
    private let start = TestCalendar.date(2026, 10, 16, 9)

    private func prescription(start: Date? = nil, totalDoses: Int = 12) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: start ?? self.start, scheduledWeekday: 5, scheduledHour: 20, totalDoses: totalDoses)
    }

    private func dose(_ month: Int, _ day: Int, _ hour: Int = 20, site: BodySite = .thighLeft, sequence: Int = 1, note: String? = nil) -> DoseSnapshot {
        let date = TestCalendar.date(2026, month, day, hour)
        return DoseSnapshot(administeredAt: date, scheduledFor: date, site: site, sequence: sequence, note: note)
    }

    private func build(
        _ data: [ReportBuilder.PrescriptionData],
        checks: [ConditionCheckSnapshot] = [],
        weights: [WeightSampleSnapshot] = [],
        now: Date,
        period: DateInterval? = nil
    ) -> ClinicReport {
        let active = data.last { $0.isActive }?.prescription.startDate
        let interval = period ?? ReportBuilder.interval(for: .sinceClinic, activePrescriptionStart: active, now: now, calendar: calendar)
        return ReportBuilder.build(period: interval, prescriptions: data, checks: checks, weights: weights, now: now, calendar: calendar, appVersion: "1.0")
    }

    // MARK: R12 기간

    @Test func defaultPeriodDependsOnNextClinicDate() {
        #expect(ReportBuilder.defaultPeriod(hasNextClinicDate: true) == .sinceClinic)
        #expect(ReportBuilder.defaultPeriod(hasNextClinicDate: false) == .weeks(8))
    }

    /// 설정에 저장한 기본 기간 (2026-10-22 결정). 고를 수 없는 값이면 R12 기본값
    @Test func savedDefaultPeriodWinsWhenSelectable() {
        #expect(ReportBuilder.defaultPeriod(saved: .weeks(12), hasActivePrescription: true, hasNextClinicDate: true) == .weeks(12))
        #expect(ReportBuilder.defaultPeriod(saved: .sinceClinic, hasActivePrescription: true, hasNextClinicDate: false) == .sinceClinic)
        // 활성 처방이 없으면 "직전 진료 이후"를 고를 수 없다
        #expect(ReportBuilder.defaultPeriod(saved: .sinceClinic, hasActivePrescription: false, hasNextClinicDate: false) == .weeks(8))
        // 선택지에 없는 주 수
        #expect(ReportBuilder.defaultPeriod(saved: .weeks(5), hasActivePrescription: true, hasNextClinicDate: true) == .sinceClinic)
        // 저장 안 함 = 자동
        #expect(ReportBuilder.defaultPeriod(saved: nil, hasActivePrescription: true, hasNextClinicDate: true) == .sinceClinic)
        #expect(ReportBuilder.defaultPeriod(saved: nil, hasActivePrescription: true, hasNextClinicDate: false) == .weeks(8))
    }

    @Test func periodStorageValueRoundTrips() {
        let choices: [ReportPeriod] = [.sinceClinic] + ReportPeriod.weekChoices.map { .weeks($0) }
        for choice in choices {
            #expect(ReportPeriod(storageValue: choice.storageValue) == choice)
        }
        #expect(ReportPeriod.weeks(8).storageValue == "weeks8")
        #expect(ReportPeriod(storageValue: "weeks5") == nil)
        #expect(ReportPeriod(storageValue: "weeks") == nil)
        #expect(ReportPeriod(storageValue: "auto") == nil)
    }

    @Test func periodIntervals() {
        let now = TestCalendar.date(2026, 11, 12, 14)
        let since = ReportBuilder.interval(for: .sinceClinic, activePrescriptionStart: start, now: now, calendar: calendar)
        #expect(since.start == TestCalendar.date(2026, 10, 16))
        #expect(since.end == now)

        let fourWeeks = ReportBuilder.interval(for: .weeks(4), activePrescriptionStart: start, now: now, calendar: calendar)
        #expect(fourWeeks.start == TestCalendar.date(2026, 10, 16))
        #expect(ReportBuilder.weekCount(of: fourWeeks, calendar: calendar) == 4)

        // 처방이 없으면 최근 8주
        let fallback = ReportBuilder.interval(for: .sinceClinic, activePrescriptionStart: nil, now: now, calendar: calendar)
        #expect(fallback.start == TestCalendar.date(2026, 9, 18))
    }

    // MARK: B·C

    @Test func summaryAndTimeline() {
        // 10-22 기록, 10-29 누락, 11-07(+2일) 기록, 11-12 진행 중
        let data = ReportBuilder.PrescriptionData(
            prescription: prescription(),
            doses: [dose(10, 22, site: .abdomenUpperLeft, sequence: 1), dose(11, 7, site: .thighRight, sequence: 2)],
            isActive: true
        )
        let report = build([data], now: TestCalendar.date(2026, 11, 12, 21))

        #expect(report.summary.dosesTaken == 2)
        #expect(report.summary.dosesScheduled == 4)
        #expect(report.summary.missedCount == 1)
        #expect(report.summary.remainingDoses == 10)
        #expect(report.cycles.map(\.state) == [
            .recorded(date: TestCalendar.date(2026, 10, 22, 20), site: .abdomenUpperLeft, sequence: 1, offsetText: nil),
            .missed,
            .recorded(date: TestCalendar.date(2026, 11, 7, 20), site: .thighRight, sequence: 2, offsetText: "+2d"),
            .pending,
        ])
        #expect(report.quality == nil)
    }

    @Test func timelineKeepsLastTwelveCells() {
        let data = ReportBuilder.PrescriptionData(prescription: prescription(totalDoses: 20), doses: [], isActive: true)
        let now = TestCalendar.date(2027, 1, 30, 9)
        let period = DateInterval(start: start, end: now)
        let report = build([data], now: now, period: period)
        #expect(report.cycles.count == ReportBuilder.maxCells)
        #expect(report.summary.dosesScheduled > ReportBuilder.maxCells)
        #expect(report.cycles.last?.scheduledDate == TestCalendar.date(2027, 1, 28, 20))
    }

    @Test func conditionResponseCountsOnlyOpenedWindows() {
        let first = dose(10, 22)
        let second = dose(10, 29)
        let checks = [
            ConditionCheckSnapshot(doseID: first.id, window: .h24, checkedAt: TestCalendar.date(2026, 10, 23, 20)),
            ConditionCheckSnapshot(doseID: first.id, window: .h48, checkedAt: TestCalendar.date(2026, 10, 24, 20)),
        ]
        // 지금 10-30 10:00: second는 14시간 → h24만 열림. 분모 3, 응답 2
        let data = ReportBuilder.PrescriptionData(prescription: prescription(), doses: [first, second], isActive: true)
        let report = build([data], checks: checks, now: TestCalendar.date(2026, 10, 30, 10))
        #expect(report.summary.checksExpected == 3)
        #expect(report.summary.checksAnswered == 2)
    }

    // MARK: 체중

    @Test func weightChangeKeepsSignAndSource() {
        let weights = [
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 17, 8), kilograms: 82.44, source: .healthKit),
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 11, 10, 8), kilograms: 79.2, source: .manual),
        ]
        let data = ReportBuilder.PrescriptionData(prescription: prescription(), doses: [], isActive: true)
        let report = build([data], weights: weights, now: TestCalendar.date(2026, 11, 12, 9))
        #expect(report.summary.weightStartText == "82.4")
        #expect(report.summary.weightEndText == "79.2")
        #expect(report.summary.weightChangeText == "-3.2")
        #expect(report.weightSource == .mixed)
        #expect(report.weight.count == report.weeks)
    }

    @Test func kilogramFormatting() {
        #expect(ReportBuilder.signedKilograms(0.4) == "+0.4")
        #expect(ReportBuilder.signedKilograms(-3.24) == "-3.2")
        #expect(ReportBuilder.signedKilograms(-0.04) == "0.0")
        #expect(ReportBuilder.kilograms(80) == "80.0")
    }

    @Test func singleWeightSampleHasNoChange() {
        let weights = [WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 17, 8), kilograms: 82, source: .manual)]
        let data = ReportBuilder.PrescriptionData(prescription: prescription(), doses: [], isActive: true)
        let report = build([data], weights: weights, now: TestCalendar.date(2026, 11, 12, 9))
        #expect(report.summary.weightChangeText == nil)
        #expect(report.summary.weightStartText == "82.0")
        #expect(report.weightSource == .manual)
    }

    // MARK: E·G

    @Test func symptomRowsSortedAndHiddenWhenZero() {
        let first = dose(10, 22)
        let second = dose(10, 29)
        let checks = [
            ConditionCheckSnapshot(doseID: first.id, window: .h24, checkedAt: TestCalendar.date(2026, 10, 23, 20),
                                   symptoms: [SymptomEntry(symptom: .nausea, severity: 1), SymptomEntry(symptom: .fatigue, severity: 0)],
                                   appetite: .reduced),
            ConditionCheckSnapshot(doseID: first.id, window: .h48, checkedAt: TestCalendar.date(2026, 10, 24, 20),
                                   symptoms: [SymptomEntry(symptom: .nausea, severity: 3)]),
            ConditionCheckSnapshot(doseID: second.id, window: .h24, checkedAt: TestCalendar.date(2026, 10, 30, 20),
                                   symptoms: [SymptomEntry(symptom: .constipation, severity: 2), SymptomEntry(symptom: .nausea, severity: 1)],
                                   appetite: .veryReduced),
        ]
        let data = ReportBuilder.PrescriptionData(prescription: prescription(), doses: [first, second], isActive: true)
        let report = build([data], checks: checks, now: TestCalendar.date(2026, 11, 2, 9))

        #expect(report.symptoms == [
            ClinicReport.SymptomRow(symptom: .nausea, count: 3, maxSeverity: 3, timing: .h24),
            ClinicReport.SymptomRow(symptom: .constipation, count: 1, maxSeverity: 2, timing: .h24),
        ])
        #expect(report.symptoms.first?.isSevere == true)
        #expect(report.appetite == ClinicReport.AppetiteSummary(reduced: 1, veryReduced: 1))
    }

    @Test func notesAreRecentFiveAndTruncated() {
        let long = String(repeating: "가", count: 70)
        let doses = (0..<6).map { offset in
            dose(10, 22 + offset, note: offset == 5 ? long : "메모 \(offset)")
        }
        let data = ReportBuilder.PrescriptionData(prescription: prescription(), doses: doses, isActive: true)
        let report = build([data], now: TestCalendar.date(2026, 11, 2, 9))
        #expect(report.notes.count == ReportBuilder.maxNotes)
        #expect(report.notes.first?.text == String(repeating: "가", count: 60) + "…")
        #expect(report.notes.last?.text == "메모 1")
    }

    @Test func archivedPrescriptionDoesNotAddMissedCells() {
        let old = ReportBuilder.PrescriptionData(prescription: prescription(), doses: [dose(10, 22)], isActive: false)
        let new = ReportBuilder.PrescriptionData(
            prescription: prescription(start: TestCalendar.date(2026, 10, 27, 9)),
            doses: [dose(10, 29), dose(11, 5)],
            isActive: true
        )
        let now = TestCalendar.date(2026, 11, 6, 9)
        let report = build([old, new], now: now, period: DateInterval(start: start, end: now))
        #expect(report.summary.missedCount == 0)
        #expect(report.summary.dosesTaken == 3)
        #expect(report.cycles.count == 3)
    }

    /// REPORT_SPEC C·R13: 전환이 있을 때만 첫 칸에 "기간 시작 시 처방", 새 처방 첫 칸에 전환 표시
    @Test func prescriptionTransitionMarkers() {
        let old = ReportBuilder.PrescriptionData(
            prescription: PrescriptionSnapshot(startDate: start, scheduledWeekday: 5, scheduledHour: 20, totalDoses: 12,
                                               endDate: TestCalendar.date(2026, 10, 26), doseLabel: "첫 처방"),
            doses: [dose(10, 22)],
            isActive: false
        )
        let newStart = TestCalendar.date(2026, 10, 27, 9)
        let new = ReportBuilder.PrescriptionData(
            prescription: PrescriptionSnapshot(startDate: newStart, scheduledWeekday: 5, scheduledHour: 20, totalDoses: 12),
            doses: [dose(10, 29), dose(11, 5)],
            isActive: true
        )
        let now = TestCalendar.date(2026, 11, 6, 9)
        let report = build([old, new], now: now, period: DateInterval(start: start, end: now))
        #expect(report.summary.prescriptionTransitions == 1)
        #expect(report.cycles.map(\.marker) == [.periodStart(label: "첫 처방"), .change(label: nil, date: newStart), nil])

        // 처방이 하나뿐이면 아무 표시도 없다
        let single = build([new], now: now, period: DateInterval(start: start, end: now))
        #expect(single.summary.prescriptionTransitions == 0)
        #expect(single.cycles.allSatisfy { $0.marker == nil })
    }
}
