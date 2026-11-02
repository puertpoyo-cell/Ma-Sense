import Charts
import SwiftUI

/// 기록 탭 맨 위 몸 추이 카드 (D24, D24-1 핀치로 가로 기간, 2026-10-30 사람 요청 "그래프로 보여 줘야지 추이가, 기록 탭에 제일 위에").
/// 체중·체지방률·제지방량 중 기록이 있는 것을 선으로 겹쳐 보인다. 측정값을 이은 선, 측정 없는 주에서 끊음 (R7).
/// D36 (2026-11-02 사람 요청 "직관적이지 못하네, 체중이나 숫자도 잘 안 보이고"): 기준 값 하나(처음엔 체중)를 골라
/// 맨 위에 최근 값을 크게, 그래프에 실제 눈금과 점마다 숫자를 붙인다. 나머지 값은 흐린 선으로 모양만 겹친다
/// (`WeightRules.rescaled`). 곡선 보간은 없던 굴곡을 만들어 직선으로 잇는다.
/// 목표선·판단 색 없음 (COMPLIANCE.md 2.1-3). 빨강·초록 금지라 강조·모래·세이지 토큰을 쓴다
struct BodyTrendCard: View {
    let samples: [WeightSampleSnapshot]
    let doses: [DoseSnapshot]
    let now: Date
    var openDetail: () -> Void

    @Environment(\.calendar) private var calendar
    /// D36 기준 값. 셋 다 보이되(D24-1 "셋 다 켜지게") 눈금·숫자는 기준 값만
    @State private var focus: BodyMetric = .weight
    @State private var selectedDate: Date?
    /// D24-1 핀치로 고른 가로 기간(주). 기기 화면 상태라 UserDefaults
    @AppStorage("bodyTrend.weeks") private var weeks = 12
    /// 핀치 시작 때 기간. 진행 중 배율은 이 값 기준
    @State private var pinchBase: Int?

    private struct Series: Identifiable {
        let metric: BodyMetric
        let daily: [DailyWeight]
        var id: BodyMetric { metric }
    }

    private struct Plotted: Identifiable {
        let metric: BodyMetric
        let day: Date
        let value: Double
        /// 겹쳐 그릴 때 값 (자기 범위 0...1) 또는 실제 값
        let y: Double
        let segment: Int
        var id: String { "\(metric.rawValue)-\(day.timeIntervalSince1970)" }
    }

    var body: some View {
        let maxWeeks = WeightRules.allWeeks(samples: samples, now: now, calendar: calendar)
        let span = min(weeks, maxWeeks)
        let end = WeightRules.seriesEnd(samples: samples, weeks: span, now: now, calendar: calendar)
        let available = series(end: end, weeks: span)
        let focused = available.first { $0.metric == focus } ?? available.first
        let overlaid = available.count > 1
        let points = plotted(available, focus: focused)
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("history.bodyTrend.title")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    // 지금 가로 기간. 핀치로 바뀐다
                    Text(spanLabel(span, maxWeeks: maxWeeks))
                        .font(Typography.caption.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                        .contentTransition(.numericText())
                    Button(action: openDetail) {
                        HStack(spacing: Spacing.s1) {
                            Text("history.bodyTrend.detail")
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .font(Typography.caption)
                        .foregroundStyle(Color.accent)
                    }
                    .buttonStyle(.plain)
                }
                if let focused, let latest = focused.daily.last {
                    headline(focused, latest: latest)
                }
                if available.count > 1 {
                    legend(available)
                } else if let only = available.first {
                    legendItem(only, selectable: false)
                }
                if points.isEmpty {
                    Text("weight.trend.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    chart(points, focus: focused?.metric ?? .weight, end: end)
                        .frame(height: 220)
                        .simultaneousGesture(pinch(maxWeeks: maxWeeks))
                        .sensoryFeedback(.selection, trigger: weeks)
                }
                if end < now {
                    Text("weight.sparkline.until \(end.formatted(.dateTime.month(.defaultDigits).day()))")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Text(LocalizedStringKey(overlaid ? "history.bodyTrend.footnote.focus" : "history.bodyTrend.footnote"))
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 데이터

    private func series(end: Date, weeks: Int) -> [Series] {
        BodyMetric.allCases.compactMap { metric in
            let metricSamples = WeightRules.metricSamples(samples, metric: metric)
            let trend = WeightRules.trend(samples: metricSamples, weeks: weeks, now: end, calendar: calendar)
            // 체중은 기록이 없어도 자리를 둔다. 체성분은 기록이 있을 때만
            guard metric == .weight || !trend.daily.isEmpty else { return nil }
            return Series(metric: metric, daily: trend.daily)
        }
    }

    /// 기준 값은 실제 값, 나머지는 기준 값의 눈금 범위에 모양만 겹친다
    private func plotted(_ available: [Series], focus: Series?) -> [Plotted] {
        let range = focus.flatMap { WeightRules.focusRange($0.daily.map(\.kilograms)) }
        // 기준 값을 맨 뒤에 그려 다른 선 위에 오게
        let ordered = available.filter { $0.metric != focus?.metric } + available.filter { $0.metric == focus?.metric }
        return ordered.flatMap { series in
            let values = series.daily.map(\.kilograms)
            let ys = series.metric == focus?.metric || range == nil ? values : WeightRules.rescaled(values, into: range!)
            let yByDay = Dictionary(uniqueKeysWithValues: zip(series.daily.map(\.day), ys))
            return WeightRules.lineSegments(series.daily, calendar: calendar).enumerated().flatMap { index, segment in
                segment.map {
                    Plotted(metric: series.metric, day: $0.day, value: $0.kilograms, y: yByDay[$0.day] ?? 0, segment: index)
                }
            }
        }
    }

    // MARK: 범례 (눌러서 켜고 끄기)

    private func legend(_ available: [Series]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s2) {
                ForEach(available) { legendItem($0, selectable: true) }
            }
            VStack(alignment: .leading, spacing: Spacing.s2) {
                ForEach(available) { legendItem($0, selectable: true) }
            }
        }
    }

    private func legendItem(_ series: Series, selectable: Bool) -> some View {
        let isOn = series.metric == focus || !selectable
        return Button {
            guard selectable else { return }
            selectedDate = nil
            withAnimation(.snappy(duration: 0.25)) { focus = series.metric }
        } label: {
            HStack(spacing: Spacing.s1 + 2) {
                Capsule()
                    .fill(Self.color(series.metric))
                    .frame(width: 14, height: 4)
                    .opacity(isOn ? 1 : 0.45)
                VStack(alignment: .leading, spacing: 0) {
                    Text(LocalizedStringKey("weight.trend.metric." + series.metric.rawValue))
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(isOn ? Color.ink : Color.inkSecondary)
                    if let first = series.daily.first, let last = series.daily.last {
                        Text(verbatim: "\(Self.format(first.kilograms)) → \(Self.format(last.kilograms)) \(Self.unit(series.metric))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .padding(.horizontal, Spacing.s2)
            .padding(.vertical, Spacing.s1 + 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(isOn && selectable ? Color.accentSoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(selectable ? (isOn ? Self.color(series.metric).opacity(0.7) : Color.frostBorder) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .accessibilityAddTraits(isOn && selectable ? [.isSelected] : [])
    }

    // MARK: 맨 위 최근 값 (D36)

    private func headline(_ series: Series, latest: DailyWeight) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: Spacing.s2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("weight.trend.metric." + series.metric.rawValue))
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(verbatim: Self.format(latest.kilograms))
                        .font(Font.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.ink)
                        .contentTransition(.numericText())
                    Text(verbatim: Self.unit(series.metric))
                        .font(Typography.label)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer()
            Text("history.bodyTrend.latestOn \(latest.day.formatted(.dateTime.month(.defaultDigits).day()))")
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 그래프

    // MARK: 핀치 (D24-1): 벌리면 짧은 기간, 오므리면 긴 기간. 단계(2·4·8·12·26·52주·전체)에 붙는다

    private func pinch(maxWeeks: Int) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? min(weeks, maxWeeks)
                if pinchBase == nil { pinchBase = base }
                let next = WeightRules.zoomedWeeks(from: base, magnification: value.magnification, maxWeeks: maxWeeks)
                if next != min(weeks, maxWeeks) {
                    selectedDate = nil
                    withAnimation(.snappy(duration: 0.25)) { weeks = next }
                }
            }
            .onEnded { _ in pinchBase = nil }
    }

    private func spanLabel(_ span: Int, maxWeeks: Int) -> String {
        if span >= maxWeeks, maxWeeks > WeightRules.zoomSteps.first ?? 0, !WeightRules.zoomSteps.contains(span) {
            return String(localized: "history.bodyTrend.span.all")
        }
        return String(localized: "history.bodyTrend.span.weeks \(span)")
    }

    private func chart(_ points: [Plotted], focus: BodyMetric, end: Date) -> some View {
        let selected = selection(points)
        let focusPoints = points.filter { $0.metric == focus }
        let labeled = WeightRules.labeledIndices(focusPoints.map(\.value))
        let labeledIDs = Set(labeled.map { focusPoints[$0].id })
        let yAxis: [Double] = {
            guard let range = WeightRules.focusRange(focusPoints.map(\.value)) else { return [] }
            let mid = (range.lowerBound + range.upperBound) / 2
            return [range.lowerBound, mid, range.upperBound]
        }()
        let unit = Self.unit(focus)
        return Chart {
            ForEach(points) { point in
                let isFocus = point.metric == focus
                LineMark(
                    x: .value("day", point.day),
                    y: .value("value", point.y),
                    series: .value("series", "\(point.metric.rawValue)-\(point.segment)")
                )
                .foregroundStyle(Self.color(point.metric).opacity(isFocus ? 1 : 0.4))
                .lineStyle(StrokeStyle(lineWidth: isFocus ? 3 : 1.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
                PointMark(x: .value("day", point.day), y: .value("value", point.y))
                    .foregroundStyle(Self.color(point.metric).opacity(isFocus ? 1 : 0.4))
                    .symbolSize(isFocus ? 36 : 12)
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        if isFocus, labeledIDs.contains(point.id), selected.isEmpty {
                            Text(verbatim: Self.format(point.value))
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Color.ink)
                        }
                    }
            }
            if let date = selected.first?.day {
                RuleMark(x: .value("selected", date))
                    .foregroundStyle(Color.inkSecondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        selectionLabel(selected, date: date)
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: .automatic(includesZero: false), range: .plotDimension(padding: 20))
        .chartXScale(range: .plotDimension(startPadding: 16, endPadding: 16))
        .chartXAxis {
            // D36: 처음·가운데·끝 날짜만 (겹치지 않게)
            AxisMarks(values: WeightRules.axisDays(focusPoints.map(\.day))) { _ in
                AxisGridLine().foregroundStyle(Color.inkTertiary.opacity(0.4))
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), anchor: .top)
                    .font(.caption2)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxis) { value in
                AxisGridLine().foregroundStyle(Color.inkTertiary.opacity(0.4))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(verbatim: "\(Self.format(number)) \(unit)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            // 투약일 4pt 눈금 (DESIGN_SYSTEM.md 5.5)
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame, let start = points.map(\.day).min() {
                    let frame = geometry[anchor]
                    ForEach(doses.filter { !$0.isCancelled && $0.administeredAt >= start && $0.administeredAt <= end }.map(\.administeredAt), id: \.self) { date in
                        if let x = proxy.position(forX: date) {
                            Rectangle()
                                .fill(Color.inkSecondary)
                                .frame(width: 1, height: 4)
                                .position(x: frame.minX + x, y: frame.maxY - 2)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .accessibilityLabel(Text("history.bodyTrend.a11y"))
    }

    /// 누른 날에 가장 가까운 측정일의 값들 (선마다)
    private func selection(_ points: [Plotted]) -> [Plotted] {
        guard let selectedDate,
              let nearest = points.min(by: { abs($0.day.timeIntervalSince(selectedDate)) < abs($1.day.timeIntervalSince(selectedDate)) })
        else { return [] }
        return points.filter { $0.day == nearest.day }
    }

    private func selectionLabel(_ selected: [Plotted], date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: date.formatted(.dateTime.month(.defaultDigits).day()))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            ForEach(selected) { point in
                HStack(spacing: Spacing.s1) {
                    Circle().fill(Self.color(point.metric)).frame(width: 6, height: 6)
                    Text(verbatim: "\(Self.format(point.value)) \(Self.unit(point.metric))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.ink)
                }
            }
        }
        .padding(.horizontal, Spacing.s2)
        .padding(.vertical, Spacing.s1)
        .background(Color.midnightElevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(Color.frostBorder, lineWidth: 1))
    }

    // MARK: 표시

    static func color(_ metric: BodyMetric) -> Color {
        switch metric {
        case .weight: return .accent
        case .bodyFat: return .accentSand
        case .leanMass: return .accentSage
        }
    }

    /// 단위 기호라 번역하지 않는다
    static func unit(_ metric: BodyMetric) -> String {
        metric == .bodyFat ? "%" : "kg"
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}
