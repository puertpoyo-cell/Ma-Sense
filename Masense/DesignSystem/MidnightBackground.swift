import SwiftUI

/// Midnight 배경 + 상단 좌측의 아주 옅은 방사형 그라데이션 1개 (DESIGN_SYSTEM.md 4).
struct MidnightBackground: View {
    var body: some View {
        ZStack {
            Color.midnight
            RadialGradient(
                colors: [Color.accent.opacity(0.06), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func midnightBackground() -> some View {
        background(MidnightBackground())
    }
}

#Preview {
    Text("Midnight")
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .midnightBackground()
        .preferredColorScheme(.dark)
}
