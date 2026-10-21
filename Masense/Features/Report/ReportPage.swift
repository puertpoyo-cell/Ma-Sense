import SwiftData
import SwiftUI

/// 진료 전 리포트 A4 한 장 (REPORT_SPEC.md 레이아웃). 미리보기와 PDF가 같은 뷰를 쓴다.
/// 인쇄 전제: 흰 배경, 검정·회색 중심. 테마는 강조색 하나만 바꾼다. 크기는 고정 (Dynamic Type 미적용).
struct ReportPage: View {
    let report: ClinicReport
    var accent: Color = .accent
    var calendar: Calendar = .current

    /// A4 210×297mm @72dpi
    static let size = CGSize(width: 595.28, height: 841.89)
    private static let mm: CGFloat = 72 / 25.4
    private let margin = 16 * ReportPage.mm
    private let gutter = 4 * ReportPage.mm

    private let ink = Color.inkOnPaper
    private let gray = Color(hex: 0x6B7280)
    private let rule = Color(hex: 0xD1D5DB)

    var body: some View {
        VStack(alignment: .leading, spacing: 3 * Self.mm) {
            header
            summary
            timeline
            HStack(alignment: .top, spacing: gutter) {
                weight
                symptoms
            }
            .frame(height: 60 * Self.mm, alignment: .top)
            if !report.notes.isEmpty {
                notes
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(margin)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(ink)
        .environment(\.colorScheme, .light)
    }

    // MARK: A. 헤더

    private var header: some View {
        VStack(spacing: 2 * Self.mm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("report.title")
                        .font(.system(size: 16, weight: .semibold))
                    Text("report.period \(dotDate(report.period.start)) \(dotDate(report.period.end)) \(report.weeks)")
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("report.wordmark")
                        .font(.system(size: 9, weight: .semibold))
                    Text("report.generatedOn \(dotDate(report.generatedAt))")
                        .font(.system(size: 7.5))
                        .monospacedDigit()
                        .foregroundStyle(gray)
                }
            }
            Rectangle().fill(accent).frame(height: 2)
        }
        .frame(height: 18 * Self.mm, alignment: .top)
    }

    // MARK: B. 요약 4칸

    private var summary: some View {
        let s = report.summary
        return HStack(alignment: .top, spacing: gutter) {
            summaryCell("report.summary.doses") {
                Text("report.summary.doses.value \(s.dosesTaken) \(s.dosesScheduled)")
            } detail: {
                if s.missedCount == 0 {
                    Text("report.summary.noMissed")
                } else {
                    Text("report.summary.missed \(s.missedCount)")
                }
            }
            summaryCell("report.summary.weight") {
                if let change = s.weightChangeText {
                    Text("report.kg \(change)")
                } else {
                    Text("report.summary.weight.none")
                }
            } detail: {
                if let start = s.weightStartText, let end = s.weightEndText {
                    Text("report.summary.weight.range \(start) \(end)")
                }
            }
            summaryCell("report.summary.condition") {
                Text("report.summary.condition.value \(s.checksAnswered) \(s.checksExpected)")
            } detail: {
                EmptyView()
            }
            summaryCell("report.summary.remaining") {
                Text("report.summary.remaining.value \(s.remainingDoses)")
            } detail: {
                if let date = s.exhaustionDate {
                    Text("report.summary.exhaustion \(dotDate(date))")
                }
            }
        }
        .frame(height: 22 * Self.mm, alignment: .top)
    }

    private func summaryCell<Value: View, Detail: View>(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder value: () -> Value,
        @ViewBuilder detail: () -> Detail
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey)
                .font(.system(size: 7.5, weight: .medium))
                .foregroundStyle(gray)
            value()
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
            detail()
                .font(.system(size: 7.5))
                .monospacedDigit()
                .foregroundStyle(gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2 * Self.mm)
        .overlay(alignment: .top) { Rectangle().fill(rule).frame(height: 0.5) }
    }

    // MARK: C. 투약 타임라인

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 2 * Self.mm) {
            sectionTitle("report.section.timeline")
            HStack(alignment: .top, spacing: 1.5 * Self.mm) {
                ForEach(report.cycles) { cell in
                    cycleCell(cell)
                }
                // 칸 수가 적어도 폭은 12칸 기준으로 고정
                ForEach(0..<max(0, ReportBuilder.maxCells - report.cycles.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 34 * Self.mm, alignment: .top)
    }

    private func cycleCell(_ cell: ClinicReport.CycleCell) -> some View {
        VStack(alignment: .leading, spacing: 1.5) {
            switch cell.state {
            case let .recorded(date, site, sequence, offsetText):
                HStack(spacing: 1) {
                    Text(verbatim: shortDate(date)).font(.system(size: 8, weight: .semibold))
                    if let offsetText {
                        Text(verbatim: "(\(offsetText))").font(.system(size: 6))
                    }
                }
                Text(L10n.string("site.short." + site.rawValue)).font(.system(size: 7.5))
                Text("report.cell.sequence \(sequence)").font(.system(size: 7)).foregroundStyle(gray)
            case .missed:
                Text(verbatim: shortDate(cell.scheduledDate)).font(.system(size: 8, weight: .semibold))
                Text("report.cell.missed").font(.system(size: 7))
            case .pending:
                Text(verbatim: shortDate(cell.scheduledDate)).font(.system(size: 8, weight: .semibold)).foregroundStyle(gray)
                Text("report.cell.pending").font(.system(size: 7)).foregroundStyle(gray)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 20 * Self.mm, alignment: .topLeading)
        .overlay {
            // 누락 마디는 점선 테두리 + "기록 없음" (색이 아니라 모양과 텍스트로)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(cell.state == .missed ? gray : rule, style: StrokeStyle(lineWidth: 0.75, dash: cell.state == .missed ? [2, 2] : []))
        }
    }

    // MARK: D. 체중 추이

    private var weight: some View {
        VStack(alignment: .leading, spacing: 2 * Self.mm) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("report.section.weight")
                Spacer()
                if let sourceKey {
                    Text(sourceKey).font(.system(size: 6.5)).foregroundStyle(gray)
                }
            }
            if report.weight.contains(where: { $0.averageKg != nil }) {
                WeekChart(
                    points: report.weight,
                    tickDates: report.weightDoseTicks,
                    lineColor: ink,
                    gridColor: rule,
                    labelColor: gray,
                    labelFont: .system(size: 6.5),
                    minMaxYAxisOnly: true
                )
            } else {
                Text("report.summary.weight.none").font(.system(size: 8)).foregroundStyle(gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sourceKey: LocalizedStringKey? {
        switch report.weightSource {
        case .none: return nil
        case .healthKit: return "report.weight.source.health"
        case .manual: return "report.weight.source.manual"
        case .mixed: return "report.weight.source.mixed"
        }
    }

    // MARK: E. 부작용 빈도

    private var symptoms: some View {
        VStack(alignment: .leading, spacing: 2 * Self.mm) {
            sectionTitle("report.section.symptoms")
            if report.symptoms.isEmpty {
                Text("report.symptoms.none").font(.system(size: 8)).foregroundStyle(gray)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 3) {
                    GridRow {
                        Text("report.symptoms.header.symptom")
                        Text("report.symptoms.header.count").gridColumnAlignment(.trailing)
                        Text("report.symptoms.header.max")
                        Text("report.symptoms.header.timing")
                    }
                    .font(.system(size: 6.5, weight: .medium))
                    .foregroundStyle(gray)
                    ForEach(report.symptoms) { row in
                        GridRow {
                            Text(row.symptom.localizedName)
                            Text("report.symptoms.count \(row.count)")
                            Text(SymptomChip.severityLabel(row.maxSeverity))
                            Text(LocalizedStringKey(timingKey(row.timing)))
                        }
                        .font(.system(size: 8, weight: row.isSevere ? .bold : .regular))
                        .monospacedDigit()
                    }
                }
            }
            if report.appetite.reduced + report.appetite.veryReduced > 0 {
                Text("report.appetite \(report.appetite.reduced) \(report.appetite.veryReduced)")
                    .font(.system(size: 7.5))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func timingKey(_ timing: ClinicReport.SymptomRow.Timing) -> String {
        switch timing {
        case .h24: return "report.timing.h24"
        case .h48: return "report.timing.h48"
        case .both: return "report.timing.both"
        }
    }

    // MARK: G. 메모 발췌

    private var notes: some View {
        VStack(alignment: .leading, spacing: 1.5 * Self.mm) {
            sectionTitle("report.section.notes")
            ForEach(report.notes) { line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: shortDate(line.date))
                        .font(.system(size: 7.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(gray)
                        .frame(width: 30, alignment: .leading)
                    Text(verbatim: line.text)
                        .font(.system(size: 8))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: H. 푸터

    private var footer: some View {
        HStack(alignment: .bottom, spacing: gutter) {
            Text("report.disclaimer")
                .font(.system(size: 6.5))
                .foregroundStyle(gray)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: gutter)
            Text("report.footer.generated \(dotDateTime(report.generatedAt)) \(report.appVersion)")
                .font(.system(size: 6.5))
                .monospacedDigit()
                .foregroundStyle(gray)
                .fixedSize()
        }
        .padding(.top, 2 * Self.mm)
        .overlay(alignment: .top) { Rectangle().fill(rule).frame(height: 0.5) }
        .frame(height: 12 * Self.mm, alignment: .bottom)
    }

    // MARK: 공용

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.system(size: 9, weight: .semibold))
    }

    private func shortDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)/\(parts.day ?? 0)"
    }

    private func dotDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d.%02d.%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func dotDateTime(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return dotDate(date) + String(format: " %02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

extension ReportPage {
    /// 리포트 테마는 강조색 하나만 바꾼다 (DESIGN_SYSTEM.md 1). 구매 후 선택은 M2
    static func accent(forTheme theme: String) -> Color {
        switch theme {
        case "sand": return .accentSand
        case "sage": return .accentSage
        default: return .accent
        }
    }
}

/// 화면 폭에 맞춰 A4 페이지를 축소해 보여 준다
struct ReportPreviewView: View {
    let report: ClinicReport
    var accent: Color = .accent

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / ReportPage.size.width
            ReportPage(report: report, accent: accent)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geometry.size.width, height: ReportPage.size.height * scale, alignment: .topLeading)
        }
        .aspectRatio(ReportPage.size.width / ReportPage.size.height, contentMode: .fit)
        .overlay(Rectangle().stroke(Color.frostBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("report.preview.a11y"))
    }
}
