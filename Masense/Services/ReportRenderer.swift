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

    /// 내용이 A4 한 장에 들어가는지. 넘치면 폰트를 줄이지 않고 기간을 줄이라고 안내한다 (REPORT_SPEC.md 형식).
    /// 높이가 바뀌는 칸은 E 부작용 표와 G 메모뿐이라, 페이지 높이를 풀어 둔 `.measure` 레이아웃의 자연 높이를 A4 높이와 비교한다
    static func fitsOnePage(_ report: ClinicReport, calendar: Calendar = .current) -> Bool {
        naturalHeight(of: report, calendar: calendar) <= ReportPage.size.height + 0.5
    }

    static func naturalHeight(of report: ClinicReport, calendar: Calendar = .current) -> CGFloat {
        let renderer = ImageRenderer(content: ReportPage(report: report, calendar: calendar, layout: .measure))
        renderer.proposedSize = ProposedViewSize(width: ReportPage.size.width, height: nil)
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        return height
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
