import SwiftUI

/// 도면 분할선: `gridHairline` 1px + 교차점 `+` 마커 (DESIGN_SYSTEM.md 1, 5.1).
/// 세로 분할선과 만나는 가로 선은 `crosshair: .leading`으로 교차점에 마커를 둔다.
struct BlueprintDivider: View {
    enum Crosshair {
        case none, leading, center, trailing
    }

    var axis: Axis = .horizontal
    var crosshair: Crosshair = .center

    var body: some View {
        Rectangle()
            .fill(Color.gridHairline)
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
            .overlay(alignment: overlayAlignment) {
                if crosshair != .none {
                    marker
                }
            }
            .accessibilityHidden(true)
    }

    /// 마커의 가운데가 선의 끝·가운데에 정확히 오도록 정렬 기준을 마커 중심으로 옮긴다
    private var marker: some View {
        Text(verbatim: "+")
            .font(.system(size: 10, weight: .light, design: .monospaced))
            .foregroundStyle(Color.gridCrosshair)
            .fixedSize()
            .alignmentGuide(HorizontalAlignment.leading) { $0[HorizontalAlignment.center] }
            .alignmentGuide(HorizontalAlignment.trailing) { $0[HorizontalAlignment.center] }
            .alignmentGuide(VerticalAlignment.top) { $0[VerticalAlignment.center] }
            .alignmentGuide(VerticalAlignment.bottom) { $0[VerticalAlignment.center] }
    }

    private var overlayAlignment: Alignment {
        switch (axis, crosshair) {
        case (.horizontal, .leading): return .leading
        case (.horizontal, .trailing): return .trailing
        case (.vertical, .leading): return .top
        case (.vertical, .trailing): return .bottom
        default: return .center
        }
    }
}

/// 도면 셀: 라벨은 좌측 상단(`caption`, `inkSecondary`), 값은 우측 하단 (DESIGN_SYSTEM.md 1-2).
struct BlueprintCell<Value: View>: View {
    private let label: LocalizedStringKey
    private let valueAlignment: Alignment
    private let value: Value

    init(_ label: LocalizedStringKey, valueAlignment: Alignment = .trailing, @ViewBuilder value: () -> Value) {
        self.label = label
        self.valueAlignment = valueAlignment
        self.value = value()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 0)
            value
                .frame(maxWidth: .infinity, alignment: valueAlignment)
        }
        .padding(Spacing.cellPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 두 셀을 세로 분할선으로 나눈다. 높이는 큰 쪽에 맞춘다.
/// 접근성 글자 크기에서는 위아래로 쌓고 가로 분할선으로 나눈다 (Dynamic Type XXL 대응).
struct BlueprintSplit<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                leading
                BlueprintDivider(axis: .horizontal, crosshair: .none)
                trailing
            }
        } else {
            HStack(spacing: 0) {
                leading
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                BlueprintDivider(axis: .vertical, crosshair: .none)
                trailing
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 같은 크기 칸이 반복되는 격자(캘린더 등)의 도면 선: 칸 사이 `gridHairline` 1px와 안쪽 교차점 `+` 마커 (DESIGN_SYSTEM.md 1).
/// 칸을 간격 0으로 깔고 `.overlay`로 얹는다. 바깥 테두리는 카드·리스트 행 경계와 겹치지 않도록 그리지 않는다.
struct BlueprintGridLines: View {
    let rows: Int
    let columns: Int

    /// `+` 마커 한쪽 팔 길이
    private let arm: CGFloat = 3

    var body: some View {
        Canvas { context, size in
            guard rows > 0, columns > 0 else { return }
            let xs = (1..<columns).map { (size.width * CGFloat($0) / CGFloat(columns)).rounded() }
            let ys = (1..<rows).map { (size.height * CGFloat($0) / CGFloat(rows)).rounded() }

            var lines = Path()
            for x in xs {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in ys {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(.gridHairline), lineWidth: 1)

            var marks = Path()
            for x in xs {
                for y in ys {
                    marks.move(to: CGPoint(x: x - arm, y: y))
                    marks.addLine(to: CGPoint(x: x + arm, y: y))
                    marks.move(to: CGPoint(x: x, y: y - arm))
                    marks.addLine(to: CGPoint(x: x, y: y + arm))
                }
            }
            context.stroke(marks, with: .color(.gridCrosshair), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// List·Form 행을 도면 카드처럼: 배경 `frost`, 행 구분선 `gridHairline` (DESIGN_SYSTEM.md 5.1을 리스트에 옮긴 것)
    func frostRow() -> some View {
        listRowBackground(Color.frost)
            .listRowSeparatorTint(Color.gridHairline)
    }
}
