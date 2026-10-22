import SwiftUI

/// 주 평균 라인. 샘플 없는 주는 선을 끊고(보간 금지), 투약일은 아래 4pt 눈금. 축 라벨 없음 (홈용, DESIGN_SYSTEM.md 5.5).
struct WeekSparkline: View {
    let points: [WeekPoint]
    var tickDates: [Date] = []

    private let verticalInset: CGFloat = 4
    private let tickHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                ticks(in: size)
                    .stroke(Color.inkTertiary, lineWidth: 1)
                line(in: size)
                    .stroke(Color.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                isolatedDots(in: size)
                    .fill(Color.accent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("weight.trend.a11y"))
    }

    private var values: [Double] { points.compactMap(\.averageKg) }

    private func x(at index: Int, width: CGFloat) -> CGFloat {
        guard points.count > 1 else { return width / 2 }
        return width * CGFloat(index) / CGFloat(points.count - 1)
    }

    private func y(for value: Double, height: CGFloat) -> CGFloat {
        let drawable = height - verticalInset * 2 - tickHeight
        guard let low = values.min(), let high = values.max(), high > low else {
            return verticalInset + drawable / 2
        }
        return verticalInset + drawable * CGFloat(1 - (value - low) / (high - low))
    }

    private func line(in size: CGSize) -> Path {
        var path = Path()
        var previousHadValue = false
        for (index, point) in points.enumerated() {
            guard let value = point.averageKg else {
                previousHadValue = false
                continue
            }
            let location = CGPoint(x: x(at: index, width: size.width), y: y(for: value, height: size.height))
            if previousHadValue {
                path.addLine(to: location)
            } else {
                path.move(to: location)
            }
            previousHadValue = true
        }
        return path
    }

    /// 양옆이 비어 선으로 이어지지 않는 주는 점으로 보인다
    private func isolatedDots(in size: CGSize) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            guard let value = point.averageKg else { continue }
            let hasLeft = index > 0 && points[index - 1].averageKg != nil
            let hasRight = index < points.count - 1 && points[index + 1].averageKg != nil
            guard !hasLeft && !hasRight else { continue }
            let center = CGPoint(x: x(at: index, width: size.width), y: y(for: value, height: size.height))
            path.addEllipse(in: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5))
        }
        return path
    }

    private func ticks(in size: CGSize) -> Path {
        var path = Path()
        guard let start = points.first?.weekStart, let lastStart = points.last?.weekStart else { return path }
        // 마지막 주의 끝까지를 가로 범위로 본다
        let end = lastStart.addingTimeInterval(7 * 24 * 3_600)
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return path }
        for date in tickDates {
            let fraction = date.timeIntervalSince(start) / span
            guard (0...1).contains(fraction) else { continue }
            let tickX = size.width * CGFloat(fraction)
            path.move(to: CGPoint(x: tickX, y: size.height - tickHeight))
            path.addLine(to: CGPoint(x: tickX, y: size.height))
        }
        return path
    }
}

#Preview {
    let start = Date.now.addingTimeInterval(-7 * 7 * 24 * 3_600)
    let values: [Double?] = [82.4, 81.9, nil, 81.0, 80.6, nil, nil, 79.8]
    let points = values.enumerated().map { index, value in
        WeekPoint(weekStart: start.addingTimeInterval(Double(index) * 7 * 24 * 3_600), averageKg: value, sampleCount: value == nil ? 0 : 1)
    }
    return FrostCard {
        WeekSparkline(points: points, tickDates: [start.addingTimeInterval(3 * 24 * 3_600)])
            .frame(height: 48)
    }
    .padding(.horizontal, Spacing.screenHorizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .midnightBackground()
    .preferredColorScheme(.dark)
}
