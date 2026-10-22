import SwiftUI

/// Frosted Glass 카드 (DESIGN_SYSTEM.md 5.1). 그림자 없이 위→아래 하이라이트 그라데이션 1px 테두리로 입체감.
/// 카드 안에 카드 중첩 금지. 내부 구획은 `BlueprintDivider`·`BlueprintSplit`.
/// 도면 셀로 꽉 채우는 카드는 `padding: 0`을 주고 셀이 각자 `Spacing.cellPadding`을 가진다.
struct FrostCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    init(padding: CGFloat = Spacing.cardPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(Color.frost)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.frostHighlightTop, Color.frostHighlightBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            // 등장: opacity 0→1 + offset 8→0, 0.25s easeOut. 동작 줄이기면 생략 (DESIGN_SYSTEM.md 6)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 8)
            .onAppear {
                guard !appeared else { return }
                withAnimation(.easeOut(duration: 0.25)) { appeared = true }
            }
    }
}

#Preview {
    VStack(spacing: Spacing.cardGap) {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("daily.title")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                Text("today.empty.noPrescription")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        FrostCard(padding: 0) {
            BlueprintSplit {
                BlueprintCell("weight.title") { DimensionValue("78.4", unit: "unit.kg") }
            } trailing: {
                BlueprintCell("settings.prescription.remaining") { DimensionValue("7", unit: "unit.ofTotal \(12)") }
            }
        }
    }
    .padding(.horizontal, Spacing.screenHorizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .midnightBackground()
    .preferredColorScheme(.dark)
}
