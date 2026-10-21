import SwiftUI

/// 도면 치수 표기: 숫자는 `ink` + 큰 폰트, 단위·분모는 한 단계 작은 폰트 + `inkSecondary` (DESIGN_SYSTEM.md 1-2, 5.7).
/// 숫자 포맷(소수 1자리 등)은 부르는 쪽에서 끝내고 문자열로 넘긴다. 단위는 문자열 카탈로그 키 (`unit.kg` 등).
struct DimensionValue: View {
    private let value: String
    private let unit: LocalizedStringKey?
    private let valueFont: Font
    private let unitFont: Font

    init(
        _ value: String,
        unit: LocalizedStringKey? = nil,
        valueFont: Font = Typography.metricLarge,
        unitFont: Font = Typography.label
    ) {
        self.value = value
        self.unit = unit
        self.valueFont = valueFont
        self.unitFont = unitFont
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
            Text(verbatim: value)
                .font(valueFont)
                .monospacedDigit()
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText())
            if let unit {
                Text(unit)
                    .font(unitFont)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.s4) {
        DimensionValue("78.4", unit: "unit.kg")
        DimensionValue("7", unit: "unit.ofTotal \(12)")
        DimensionValue("65", unit: "unit.g", valueFont: Typography.body, unitFont: Typography.caption)
    }
    .padding(Spacing.s5)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .midnightBackground()
    .preferredColorScheme(.dark)
}
