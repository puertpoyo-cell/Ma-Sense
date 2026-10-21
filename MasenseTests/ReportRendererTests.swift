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
}
