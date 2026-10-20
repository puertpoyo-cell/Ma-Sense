import SwiftUI

/// Frosted Glass 카드 (DESIGN_SYSTEM.md 4). 그림자 없음, 카드 안에 카드 중첩 금지.
struct FrostCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.cardPadding)
            .background(.ultraThinMaterial)
            .background(Color.frost)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.frostBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// 카드 안 섹션 구분선. `inkTertiary` 1px.
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.inkTertiary)
            .frame(height: 1)
    }
}

#Preview {
    VStack(spacing: Spacing.cardGap) {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("카드 제목")
                    .font(Typography.title)
                    .foregroundStyle(Color.ink)
                Text("본문 텍스트가 여기에 들어갑니다.")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
                CardDivider()
                Text("3 / 12")
                    .font(Typography.mono)
                    .foregroundStyle(Color.ink)
            }
        }
    }
    .padding(.horizontal, Spacing.screenHorizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .midnightBackground()
    .preferredColorScheme(.dark)
}
