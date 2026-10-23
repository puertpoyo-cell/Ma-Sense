import SwiftData
import SwiftUI

/// 진료 전 리포트 A4 한 장 (REPORT_SPEC.md 레이아웃). 미리보기와 PDF가 같은 뷰를 쓴다.
/// 인쇄 전제: 흰 배경, 검정·회색 중심. 테마는 강조색 하나만 바꾼다. 크기는 고정 (Dynamic Type 미적용).
struct ReportPage: View {
    /// `.print`는 A4 한 장 고정. `.measure`는 페이지 높이를 풀어 내용의 자연 높이를 잰다 (넘침 판단, `ReportRenderer.fitsOnePage`).
    /// 두 레이아웃은 페이지 높이만 다르므로 자연 높이가 A4 안이면 인쇄본에서 칸이 겹치지 않는다
    enum Layout {
        case print, measure
    }

    let report: ClinicReport
    var accent: Color = .paperAccent
    var calendar: Calendar = .current
    var layout: Layout = .print

    /// A4 210×297mm @72dpi
    static let size = CGSize(width: 595.28, height: 841.89)
    private static let mm: CGFloat = 72 / 25.4
    private let margin = 16 * ReportPage.mm
    private let gutter = 4 * ReportPage.mm

    // 리포트 라이트 토큰 (DESIGN_SYSTEM.md 2 오른쪽 열)
    private let ink = Color.paperInk
    private let gray = Color.paperInkSecondary
    /// 칸 테두리
    private let rule = Color.paperBorder
    /// 섹션 분할선·차트 격자
    private let hairline = Color.paperHairline

    var body: some View {
        VStack(alignment: .leading, spacing: 3 * Self.mm) {
            header
            summary
            timeline
            // D·E 한 줄: 60mm 이상, 부작용 표가 길면 표 높이를 따른다. 차트는 정해진 줄 높이에 맞춰 왼쪽 반에 그린다
            HStack(alignment: .top, spacing: gutter) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                symptoms
            }
            .frame(minHeight: 60 * Self.mm, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .overlay {
                HStack(alignment: .top, spacing: gutter) {
                    weight
                    Color.clear
                }
            }
            if let quality = report.quality {
                qualityRow(quality)
            }
            if !report.questions.isEmpty {
                questions
            }
            if !report.notes.isEmpty {
                notes
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(margin)
        .frame(width: Self.size.width, height: layout == .print ? Self.size.height : nil, alignment: .topLeading)
        .background(Color.paperBackground)
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
                VStack(alignment: .leading, spacing: 1) {
                    if s.missedCount == 0 {
                        Text("report.summary.noMissed")
                    } else {
                        Text("report.summary.missed \(s.missedCount)")
                    }
                    if s.prescriptionTransitions > 0 {
                        Text("report.summary.transitions \(s.prescriptionTransitions)")
                    }
                }
            }
            summaryCell("report.summary.weight") {
                if let change = s.weightChangeText {
                    Text("report.kg \(change)")
                } else {
                    Text("report.summary.weight.none")
                }
            } detail: {
                VStack(alignment: .leading, spacing: 1) {
                    if let start = s.weightStartText, let end = s.weightEndText {
                        Text("report.summary.weight.range \(start) \(end)")
                    }
                    // R14: 키를 입력했을 때만 숫자로. 구간 이름 없음
                    if let start = s.bmiStartText, let end = s.bmiEndText {
                        Text("report.summary.bmi.range \(start) \(end)")
                    }
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
        .overlay(alignment: .top) { Rectangle().fill(hairline).frame(height: 0.5) }
    }

    // MARK: C. 투약 타임라인

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 2 * Self.mm) {
            sectionTitle("report.section.timeline")
            VStack(alignment: .leading, spacing: 1) {
                if report.cycles.contains(where: { $0.marker != nil }) {
                    // 처방 전환 라벨 줄 (R13): 표시된 칸 위에 메모 그대로. 길면 오른쪽 칸 위로 이어진다
                    cellRow { cell in markerLabel(cell.marker) }
                }
                cellRow { cell in cycleCell(cell) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 34 * Self.mm, alignment: .top)
    }

    /// 마디 칸 폭에 맞춘 한 줄. 칸 수가 적어도 폭은 12칸 기준으로 고정
    private func cellRow<Content: View>(@ViewBuilder _ content: @escaping (ClinicReport.CycleCell) -> Content) -> some View {
        HStack(alignment: .top, spacing: 1.5 * Self.mm) {
            ForEach(report.cycles) { cell in
                content(cell).frame(maxWidth: .infinity, alignment: .topLeading)
            }
            ForEach(0..<max(0, ReportBuilder.maxCells - report.cycles.count), id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
            }
        }
    }

    @ViewBuilder
    private func markerLabel(_ marker: ClinicReport.CycleCell.Marker?) -> some View {
        Group {
            switch marker {
            case let .periodStart(label)?:
                if let label {
                    Text("report.marker.periodStart \(label)")
                } else {
                    Text("report.marker.periodStart.noLabel")
                }
            case let .change(label, date)?:
                HStack(spacing: 2) {
                    if let label {
                        Text(verbatim: label)
                    } else {
                        Text("report.marker.change")
                    }
                    Text(verbatim: shortDate(date)).monospacedDigit()
                }
            case nil:
                Color.clear.frame(height: 0)
            }
        }
        .font(.system(size: 6.5, weight: .semibold))
        .lineLimit(1)
        .fixedSize()
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
                Text(L10n.string("site.short." + (site?.rawValue ?? "unknown"))).font(.system(size: 7.5))
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
        .overlay(alignment: .leading) {
            if cell.marker != nil {
                // 처방 전환 세로 실선 1px, 칸 사이 간격 가운데 (REPORT_SPEC C)
                Rectangle().fill(ink).frame(width: 1).offset(x: -0.75 * Self.mm)
            }
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
                    gridColor: hairline,
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

    // MARK: F. 감량의 질 (M2, 데이터 있을 때만)

    private func qualityRow(_ quality: ClinicReport.QualitySection) -> some View {
        VStack(alignment: .leading, spacing: 2 * Self.mm) {
            sectionTitle("report.section.quality")
            HStack(alignment: .top, spacing: gutter) {
                summaryCell("report.quality.protein") {
                    switch quality.protein {
                    case let .target(daysMet, totalDays)?:
                        Text("report.quality.protein.target \(daysMet) \(totalDays)")
                    case let .noTarget(recordedDays, averageGrams)?:
                        Text("report.quality.protein.noTarget \(recordedDays) \(averageGrams)")
                    case nil:
                        Text("report.summary.weight.none")
                    }
                } detail: {
                    EmptyView()
                }
                summaryCell("report.quality.strength") {
                    Text("report.quality.strength.count \(quality.strengthCount)")
                } detail: {
                    EmptyView()
                }
                summaryCell("report.quality.leanMass") {
                    if let start = quality.leanMassStartText, let end = quality.leanMassEndText {
                        Text("report.summary.weight.range \(start) \(end)")
                    } else {
                        Text("report.summary.weight.none")
                    }
                } detail: {
                    EmptyView()
                }
            }
        }
        .frame(height: 36 * Self.mm, alignment: .top)
    }

    // MARK: G. 진료 때 물어볼 것 (D6)

    private var questions: some View {
        VStack(alignment: .leading, spacing: 1.5 * Self.mm) {
            sectionTitle("report.section.questions")
            ForEach(Array(report.questions.enumerated()), id: \.element.id) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(index + 1).")
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
        .overlay(alignment: .top) { Rectangle().fill(hairline).frame(height: 0.5) }
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
    /// 리포트 테마는 강조색 하나만 바꾼다 (DESIGN_SYSTEM.md 2). 흰 종이용 값
    static func accent(forTheme theme: String) -> Color {
        (ReportTheme(rawValue: theme) ?? .midnight).paperAccent
    }
}

/// 리포트 테마 3종. 구매 후 설정에서 고른다 (PRD F18)
enum ReportTheme: String, CaseIterable, Identifiable {
    case midnight, sand, sage

    var id: String { rawValue }
    var titleKey: String { "theme." + rawValue }

    var accent: Color {
        switch self {
        case .midnight: return .accent
        case .sand: return .accentSand
        case .sage: return .accentSage
        }
    }

    /// 리포트(흰 종이)에서 쓰는 값. 기본 테마는 인쇄용으로 더 진한 파랑, sand·sage는 헤더 선에만 쓰므로 같은 값
    var paperAccent: Color {
        switch self {
        case .midnight: return .paperAccent
        case .sand: return .accentSand
        case .sage: return .accentSage
        }
    }
}

/// 화면 폭에 맞춰 A4 페이지를 축소해 보여 준다
struct ReportPreviewView: View {
    let report: ClinicReport
    var accent: Color = .paperAccent

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
