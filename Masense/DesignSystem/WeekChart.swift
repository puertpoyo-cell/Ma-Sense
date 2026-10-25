import Charts
import SwiftUI

/// 주 평균 라인 차트 (기록 탭·리포트용, DESIGN_SYSTEM.md 5.5). y축은 최소·최대 2개, x축은 주 시작일.
/// 샘플 없는 주는 선을 끊는다 (R7 보간 금지).
struct WeekChart: View {
    let points: [WeekPoint]
    /// 투약일 세로 눈금 (리포트 D)
    var tickDates: [Date] = []
    var lineColor: Color = .accent
    var gridColor: Color = .inkTertiary
    var labelColor: Color = .inkSecondary
    var labelFont: Font = .caption2
    /// y축에 최소·최대 2개 라벨만 (DESIGN_SYSTEM.md 5.5 기본)
    var minMaxYAxisOnly = true
    /// 하루 측정값 점 (D7 체중 확대 그래프). 주 평균 선 아래에 옅게
    var dailyPoints: [DailyWeight] = []
    var accessibilityKey: LocalizedStringKey = "weight.trend12.a11y"
    /// D11 추이 화면: 누르거나 끌면 가장 가까운 점의 날짜와 값을 보인다
    var selectable = false
    /// 선택 표시의 단위 ("kg", "%")
    var valueUnit = "kg"

    @State private var selectedDate: Date?

    /// 16주를 넘으면 x축 라벨을 달마다
    private var labelsMonthly: Bool { points.count > 16 }

    private struct Plotted: Identifiable {
        let weekStart: Date
        let kilograms: Double
        /// 연속 구간 번호. 빈 주를 만나면 바뀌어 선이 끊긴다
        let segment: Int
        var id: Date { weekStart }
    }

    private var plotted: [Plotted] {
        var segment = 0
        var result: [Plotted] = []
        for point in points {
            guard let kilograms = point.averageKg else {
                segment += 1
                continue
            }
            result.append(Plotted(weekStart: point.weekStart, kilograms: kilograms, segment: segment))
        }
        return result
    }

    /// 선택한 위치에서 가장 가까운 점. 하루 점이 있으면 하루 점, 없으면 주 평균 점
    private var selectedPoint: (date: Date, value: Double)? {
        guard selectable, let selectedDate else { return nil }
        let candidates: [(date: Date, value: Double)] = dailyPoints.isEmpty
            ? plotted.map { (date: $0.weekStart, value: $0.kilograms) }
            : dailyPoints.map { (date: $0.day, value: $0.kilograms) }
        return candidates.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var yValues: [Double] {
        let values = plotted.map(\.kilograms) + dailyPoints.map(\.kilograms)
        guard let low = values.min(), let high = values.max() else { return [] }
        return low == high ? [low] : [low, high]
    }

    var body: some View {
        Chart {
            ForEach(dailyPoints) { day in
                PointMark(
                    x: .value("day", day.day),
                    y: .value("kg", day.kilograms)
                )
                .foregroundStyle(labelColor.opacity(0.6))
                .symbolSize(12)
            }
            ForEach(plotted) { item in
                LineMark(
                    x: .value("week", item.weekStart),
                    y: .value("kg", item.kilograms),
                    series: .value("segment", item.segment)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("week", item.weekStart),
                    y: .value("kg", item.kilograms)
                )
                .foregroundStyle(lineColor)
                .symbolSize(24)
            }
            if let point = selectedPoint {
                RuleMark(x: .value("selected", point.date))
                    .foregroundStyle(labelColor.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        Text(verbatim: "\(point.date.formatted(.dateTime.month(.defaultDigits).day())) · \(point.value.formatted(.number.precision(.fractionLength(1)))) \(valueUnit)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, Spacing.s2)
                            .padding(.vertical, Spacing.s1)
                            .background(Color.midnightElevated, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.frostBorder, lineWidth: 1))
                    }
                PointMark(
                    x: .value("selected", point.date),
                    y: .value("kg", point.value)
                )
                .foregroundStyle(Color.ink)
                .symbolSize(48)
            }
        }
        .chartXSelection(value: selectable ? $selectedDate : .constant(nil))
        .chartYScale(domain: .automatic(includesZero: false), range: .plotDimension(padding: 6))
        // 라벨을 눈금 가운데에 두므로 처음·끝 날짜 라벨과 마지막 점이 가장자리에서 잘리지 않게 양쪽 여백
        .chartXScale(range: .plotDimension(startPadding: 26, endPadding: 28))
        .chartXAxis {
            if labelsMonthly {
                AxisMarks(values: .stride(by: .month, count: points.count > 60 ? 3 : 1)) { _ in
                    AxisGridLine().foregroundStyle(gridColor.opacity(0.5))
                    AxisValueLabel(format: .dateTime.month(.abbreviated), anchor: .top)
                        .font(labelFont)
                        .foregroundStyle(labelColor)
                }
            } else {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisGridLine().foregroundStyle(gridColor.opacity(0.5))
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), anchor: .top)
                        .font(labelFont)
                        .foregroundStyle(labelColor)
                }
            }
        }
        .chartYAxis {
            if minMaxYAxisOnly {
                AxisMarks(position: .leading, values: yValues) { _ in
                    AxisGridLine().foregroundStyle(gridColor.opacity(0.5))
                    AxisValueLabel().font(labelFont).foregroundStyle(labelColor)
                }
            } else {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(gridColor.opacity(0.5))
                    AxisValueLabel().font(labelFont).foregroundStyle(labelColor)
                }
            }
        }
        .chartOverlay { proxy in
            // 투약일마다 4pt 세로 눈금 (DESIGN_SYSTEM.md 5.5). 플롯 영역 아래 끝에 붙인다
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let frame = geometry[anchor]
                    ForEach(tickDates, id: \.self) { date in
                        if let x = proxy.position(forX: date) {
                            Rectangle()
                                .fill(labelColor)
                                .frame(width: 1, height: 4)
                                .position(x: frame.minX + x, y: frame.maxY - 2)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .accessibilityLabel(Text(accessibilityKey))
    }
}
