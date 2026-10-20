import SwiftUI

/// `notice` 색 텍스트 한 줄 + `info.circle`. 경고 아이콘 금지 (DESIGN_SYSTEM.md 5).
struct NoticeLine: View {
    private let textKey: LocalizedStringKey

    init(_ textKey: LocalizedStringKey) {
        self.textKey = textKey
    }

    var body: some View {
        Label {
            Text(textKey)
                .font(Typography.caption)
                .foregroundStyle(Color.notice)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.notice)
        }
        .labelStyle(.titleAndIcon)
    }
}

#Preview {
    FrostCard {
        NoticeLine("symptom.severe")
    }
    .padding(.horizontal, Spacing.screenHorizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .midnightBackground()
    .preferredColorScheme(.dark)
}
