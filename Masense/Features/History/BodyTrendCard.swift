import Charts
import SwiftUI

/// 기록 탭 맨 위 몸 추이 카드 (D24, D24-1 핀치로 가로 기간, 2026-10-30 사람 요청 "그래프로 보여 줘야지 추이가, 기록 탭에 제일 위에").
/// 체중·체지방률·제지방량 중 기록이 있는 것을 선으로 겹쳐 보인다. 측정값을 이은 선, 측정 없는 주에서 끊음 (R7).
/// 하나만 고르면 실제 눈금, 둘 이상이면 단위가 달라 선마다 자기 범위로 맞춰 모양만 겹친다 (`WeightRules.normalized`).
/// 목표선·판단 색 없음 (COMPLIANCE.md 2.1-3). 빨강·초록 금지라 강조·모래·세이지 토큰을 쓴다
struct BodyTrendCard: View {
    let samples: [WeightSampleSnapshot]
    let doses: [DoseSnapshot]
    let now: Date
    var openDetail: () -> Void

    @Environment(\.calendar) private var calendar
    /// 처음엔 기록이 있는 값 모두 (D24-1, 2026-10-30 사람 결정 "셋 다 켜지게")
    @State private var shown: Set<BodyMetric> = Set(BodyMetric.allCases)
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
        let visible = available.filter { shown.contains($0.metric) }
        let overlaid = visible.count > 1
        let points = plotted(visible, overlaid: overlaid)
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
                    chart(points, overlaid: overlaid, end: end, weeks: span)
                        .frame(height: 200)
                        .simultaneousGesture(pinch(maxWeeks: maxWeeks))
                        .sensoryFeedback(.selection, trigger: weeks)
                }
                if end < now {
                    Text("weight.sparkline.until \(end.formatted(.dateTime.month(.defaultDigits).day()))")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                Text(LocalizedStringKey(overlaid ? "history.bodyTrend.footnote.overlaid" : "history.bodyTrend.footnote"))
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

    private func plotted(_ visible: [Series], overlaid: Bool) -> [Plotted] {
        visible.flatMap { series in
            let ys = overlaid ? WeightRules.normalized(series.daily.map(\.kilograms)) : series.daily.map(\.kilograms)
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
        let isOn = shown.contains(series.metric)
        return Button {
            guard selectable else { return }
            // 마지막 하나는 끌 수 없다
            if isOn, shown.count > 1 {
                shown.remove(series.metric)
            } else {
                shown.insert(series.metric)
            }
        } label: {
            HStack(spacing: Spacing.s1 + 2) {
                Capsule()
                    .fill(Self.color(series.metric))
                    .frame(width: 14, height: 4)
                    .opacity(isOn ? 1 : 0.3)
                VStack(alignment: .leading, spacing: 0) {
                    Text(LocalizedStringKey("weight.trend.metric." + series.metric.rawValue))
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(isOn ? Color.ink : Color.inkTertiary)
                    if let first = series.daily.first, let last = series.daily.last {
                        Text(verbatim: "\(Self.format(first.kilograms)) → \(Self.format(last.kilograms)) \(Self.unit(series.metric))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(isOn ? Color.inkSecondary : Color.inkTertiary)
                    }
                }
            }
            .padding(.horizontal, Spacing.s2)
            .padding(.vertical, Spacing.s1 + 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(isOn && selectable ? Color.white.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(selectable ? Color.frostBorder : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .accessibilityAddTraits(isOn && selectable ? [.isSelected] : [])
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

    private func chart(_ points: [Plotted], overlaid: Bool, end: Date, weeks: Int) -> some View {
        let selected = selection(points)
        let ys = points.map(\.y)
        let yAxis: [Double] = overlaid ? [] : {
            guard let low = ys.min(), let high = ys.max() else { return [] }
            return low == high ? [low] : [low, high]
        }()
        return Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("day", point.day),
                    y: .value("value", point.y),
                    series: .value("series", "\(point.metric.rawValue)-\(point.segment)")
                )
                .foregroundStyle(Self.color(point.metric))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
                PointMark(x: .value("day", point.day), y: .value("value", point.y))
                    .foregroundStyle(Self.color(point.metric))
                    .symbolSize(18)
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
        .chartYScale(domain: .automatic(includesZero: false), range: .plotDimension(padding: 8))
        .chartXScale(range: .plotDimension(startPadding: 12, endPadding: 12))
        .chartXAxis {
            // 기간에 맞춘 눈금 간격: 2주는 3일, 4주는 주, 8~12주는 2·3주, 그 이상은 달
            if weeks > 16 {
                AxisMarks(values: .stride(by: .month, count: weeks > 60 ? 3 : (weeks > 30 ? 2 : 1))) { _ in
                    AxisGridLine().foregroundStyle(Color.inkTertiary.opacity(0.4))
                    AxisValueLabel(format: .dateTime.month(.abbreviated), anchor: .top)
                        .font(.caption2)
                        .foregroundStyle(Color.inkSecondary)
                }
            } else if weeks <= 2 {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.inkTertiary.opacity(0.4))
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), anchor: .top)
                        .font(.caption2)
                        .foregroundStyle(Color.inkSecondary)
                }
            } else {
                AxisMarks(values: .stride(by: .weekOfYear, count: weeks <= 4 ? 1 : (weeks <= 8 ? 2 : 3))) { _ in
                    AxisGridLine().foregroundStyle(Color.inkTertiary.opacity(0.4))
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), anchor: .top)
                        .font(.caption2)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxis) { _ in
                AxisGridLine().foregroundStyle(Color.inkTertiary.opacity(0.4))
                AxisValueLabel().font(.caption2).foregroundStyle(Color.inkSecondary)
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
