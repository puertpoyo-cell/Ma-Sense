import SwiftUI

/// 리포트 PDF 렌더: SwiftUI `ReportPage` → `ImageRenderer` → PDF 한 장 (REPORT_SPEC.md 형식).
@MainActor
enum ReportRenderer {
    enum RenderError: Error {
        case contextUnavailable
    }

    /// 파일명 `Masense_Report_2026-10-27.pdf`
    static func fileName(for date: Date, calendar: Calendar) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "Masense_Report_%04d-%02d-%02d.pdf", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    /// 임시 폴더에 PDF를 쓰고 URL을 돌려준다. 같은 날 다시 만들면 덮어쓴다.
    static func writePDF(report: ClinicReport, accent: Color, calendar: Calendar = .current) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: report.generatedAt, calendar: calendar))
        let page = ReportPage(report: report, accent: accent, calendar: calendar)
        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(ReportPage.size)

        var failure: Error?
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
                failure = RenderError.contextUnavailable
                return
            }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        if let failure { throw failure }
        return url
    }
}
