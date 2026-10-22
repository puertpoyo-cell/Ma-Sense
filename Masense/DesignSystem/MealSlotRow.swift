import SwiftUI

/// 끼니 4칸 (아침·점심·저녁·간식). 8×8pt 도트. 기록한 끼니는 `accent` 채운 점, 아니면 빈 원 (모양으로도 구분, DESIGN_SYSTEM.md 5.6).
/// 비어 있는 끼니를 "건너뜀"이라 부르지 않는다. 비어 있을 뿐 (R10).
struct MealSlotRow: View {
    let filled: Set<MealSlot>

    var body: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(MealSlot.allCases) { meal in
                let isFilled = filled.contains(meal)
                VStack(spacing: Spacing.s1) {
                    Circle()
                        .strokeBorder(isFilled ? Color.accent : Color.inkTertiary, lineWidth: 1)
                        .background(Circle().fill(isFilled ? Color.accent : Color.clear))
                        .frame(width: 8, height: 8)
                    Text(LocalizedStringKey(meal.titleKey))
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    isFilled
                        ? Text("meal.recorded.a11y \(L10n.string(meal.titleKey))")
                        : Text("meal.empty.a11y \(L10n.string(meal.titleKey))")
                )
            }
        }
    }
}
