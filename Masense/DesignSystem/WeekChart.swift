import Charts
import SwiftUI

/// 주 평균 라인 차트, 축 포함 (기록 탭·리포트용, DESIGN_SYSTEM.md 5).
/// 샘플 없는 주는 선을 끊는다 (R7 보간 금지).
struct WeekChart: View {
    let points: [WeekPoint]
    var lineColor: Color = .accent
    var gridColor: Color = .inkTertiary
    var labelColor: Color = .inkSecondary

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

    var body: some View {
        Chart(plotted) { item in
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
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                AxisGridLine().foregroundStyle(gridColor.opacity(0.5))
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    .foregroundStyle(labelColor)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(gridColor.opacity(0.5))
                AxisValueLabel().foregroundStyle(labelColor)
            }
        }
        .accessibilityLabel(Text("weight.trend12.a11y"))
    }
}
