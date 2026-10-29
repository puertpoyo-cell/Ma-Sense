import Foundation
import PDFKit
import SwiftUI
import Testing

@testable import Masense

// M1-d 리포트 PDF: A4 한 장, 파일명 규칙
@MainActor
struct ReportRendererTests {
    private let calendar = TestCalendar.seoul

    private func sampleReport() -> ClinicReport {
        let start = TestCalendar.date(2026, 10, 16, 9)
        let doses = [
            DoseSnapshot(administeredAt: TestCalendar.date(2026, 10, 22, 20), scheduledFor: TestCalendar.date(2026, 10, 22, 20),
                         site: .abdomenUpperLeft, sequence: 1, note: "왼쪽 복부"),
            DoseSnapshot(administeredAt: TestCalendar.date(2026, 11, 7, 20), scheduledFor: TestCalendar.date(2026, 11, 5, 20),
                         site: .thighRight, sequence: 2),
        ]
        let checks = [
            ConditionCheckSnapshot(doseID: doses[0].id, window: .h24, checkedAt: TestCalendar.date(2026, 10, 23, 20),
                                   symptoms: [SymptomEntry(symptom: .nausea, severity: 3)], appetite: .reduced, note: "저녁에 메스꺼움"),
        ]
        let weights = [
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 17, 8), kilograms: 82.4, source: .healthKit),
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 11, 10, 8), kilograms: 80.1, source: .manual),
        ]
        let now = TestCalendar.date(2026, 11, 12, 14, 2)
        return ReportBuilder.build(
            period: ReportBuilder.interval(for: .sinceClinic, activePrescriptionStart: start, now: now, calendar: calendar),
            prescriptions: [ReportBuilder.PrescriptionData(
                prescription: PrescriptionSnapshot(startDate: start, scheduledWeekday: 5, scheduledHour: 20, totalDoses: 12),
                doses: doses,
                isActive: true
            )],
            checks: checks,
            weights: weights,
            now: now,
            calendar: calendar,
            appVersion: "1.0"
        )
    }

    /// 칸마다 상한(타임라인 12칸, 증상 10개, 물어볼 것·메모 합쳐 8줄 60자)까지 채운 12주 리포트. 기간과 무관하게 이보다 길어지지 않는다
    private func fullReport(
        questionCount: Int = ReportBuilder.maxQuestions,
        noteCount: Int = ReportBuilder.maxQuestionAndNoteLines - ReportBuilder.maxQuestions,
        labCount: Int = 0
    ) -> ClinicReport {
        let start = TestCalendar.date(2026, 8, 6, 20)
        let week: TimeInterval = 7 * 86_400
        let cycles = (0..<ReportBuilder.maxCells).map { index in
            let scheduled = start.addingTimeInterval(Double(index) * week)
            // 처방 전환 표시까지 있는 리포트 (R13): 첫 칸 기간 시작 처방, 7번째 칸 전환
            let marker: ClinicReport.CycleCell.Marker? = switch index {
            case 0: .periodStart(label: "첫 번째 처방 메모")
            case 6: .change(label: "두 번째 처방 메모", date: scheduled)
            default: nil
            }
            return ClinicReport.CycleCell(
                id: "cycle.\(index)",
                scheduledDate: scheduled,
                state: .recorded(date: scheduled.addingTimeInterval(2 * 86_400), site: BodySite.allCases[index % BodySite.allCases.count],
                                 sequence: index + 1, offsetText: "+2d"),
                marker: marker
            )
        }
        let longNote = String(repeating: "메모", count: ReportBuilder.noteLength / 2) + "…"
        return ClinicReport(
            period: DateInterval(start: start, duration: 12 * week),
            weeks: 12,
            summary: ClinicReport.Summary(
                dosesTaken: 12, dosesScheduled: 12, missedCount: 0,
                weightChangeText: "-6.6", weightStartText: "92.4", weightEndText: "85.8",
                checksAnswered: 24, checksExpected: 24, remainingDoses: 0, exhaustionDate: nil,
                prescriptionTransitions: 1, bmiStartText: "32.0", bmiEndText: "29.7"
            ),
            cycles: cycles,
            weight: (0..<12).map { WeekPoint(weekStart: start.addingTimeInterval(Double($0) * week), averageKg: 92.4 - Double($0) * 0.6, sampleCount: 7) },
            weightDoseTicks: cycles.map(\.scheduledDate),
            weightSource: .mixed,
            symptoms: Symptom.allCases.map { ClinicReport.SymptomRow(symptom: $0, count: 12, maxSeverity: 3, timing: .both) },
            appetite: ClinicReport.AppetiteSummary(reduced: 6, veryReduced: 3),
            quality: ClinicReport.QualitySection(protein: .target(daysMet: 61, totalDays: 84), strengthCount: 24,
                                                 leanMassStartText: "58.2", leanMassEndText: "57.9"),
            notes: (0..<noteCount).map { ClinicReport.NoteLine(id: "note.\($0)", date: start.addingTimeInterval(Double($0) * week), text: longNote) },
            generatedAt: start.addingTimeInterval(12 * week),
            appVersion: "1.0",
            questions: (0..<questionCount).map { _ in ClinicReport.QuestionLine(id: UUID(), text: longNote) },
            labs: (0..<labCount).map { index in
                ClinicReport.LabLine(id: UUID(), item: LabItem.allCases[index % 15], customName: nil, valueText: "123.4", unit: "mg/dL", date: start)
            }
        )
    }

    @Test func fileNameUsesGenerationDate() {
        #expect(ReportRenderer.fileName(for: TestCalendar.date(2026, 10, 27, 14), calendar: calendar) == "Masense_Report_2026-10-27.pdf")
    }

    @Test func rendersSingleA4Page() throws {
        let url = try ReportRenderer.writePDF(report: sampleReport(), accent: .accent, calendar: calendar)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount == 1)
        let bounds = try #require(document.page(at: 0)).bounds(for: .mediaBox)
        #expect(abs(bounds.width - ReportPage.size.width) < 1)
        #expect(abs(bounds.height - ReportPage.size.height) < 1)
    }

    // REPORT_SPEC.md 형식: 넘치면 폰트를 줄이지 않고 기간을 줄이라고 안내

    @Test func sampleReportFitsOnePage() {
        #expect(ReportRenderer.fitsOnePage(sampleReport(), calendar: calendar))
    }

    /// REPORT_SPEC.md 수용 기준 "12주 데이터로 A4 1장 안에 들어감"
    @Test func fullTwelveWeekReportFitsOnePage() {
        let full = ReportRenderer.naturalHeight(of: fullReport(), calendar: calendar)
        // 물어볼 것이 없으면 메모 5줄. 이 경우도 한 장
        let notesOnly = ReportRenderer.naturalHeight(of: fullReport(questionCount: 0, noteCount: ReportBuilder.maxNotes), calendar: calendar)
        #expect(notesOnly <= ReportPage.size.height, "자연 높이 \(notesOnly)pt, A4 \(ReportPage.size.height)pt")
        #expect(full > ReportRenderer.naturalHeight(of: sampleReport(), calendar: calendar))
        #expect(full <= ReportPage.size.height, "자연 높이 \(full)pt, A4 \(ReportPage.size.height)pt")
    }

    /// N-B1: 최근 검사 6개가 들어가면 물어볼 것·메모 줄이 그만큼 줄어 여전히 한 장
    @Test func fullReportWithLabsFitsOnePage() {
        let budget = ReportBuilder.maxQuestionAndNoteLines - ReportBuilder.labLineBudget(ReportBuilder.maxLabs)
        #expect(ReportBuilder.labLineBudget(ReportBuilder.maxLabs) == 4)
        #expect(ReportBuilder.labLineBudget(0) == 0)
        let withLabs = ReportRenderer.naturalHeight(of: fullReport(questionCount: budget, noteCount: 0, labCount: ReportBuilder.maxLabs), calendar: calendar)
        #expect(withLabs <= ReportPage.size.height, "자연 높이 \(withLabs)pt, A4 \(ReportPage.size.height)pt")
    }

    /// 상한을 넘는 내용(빌더는 만들지 않음)으로 넘침 판단이 실제 높이를 재는지 확인
    @Test func overflowIsDetected() {
        #expect(!ReportRenderer.fitsOnePage(fullReport(noteCount: 40), calendar: calendar))
    }
}
