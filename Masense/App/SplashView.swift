import SwiftUI

/// 앱을 처음 열 때 1초 정도 머무는 전환 화면. midnight 바탕 + 아이콘의 M 마크 + 이름과 한 줄 원칙.
/// 담담하게: 크기·회전 애니메이션 없이 나타났다가 흐려지며 사라진다 (RootView). 성공·축하 표현 없음
struct SplashView: View {
    /// 머무는 시간
    static let duration: Duration = .seconds(1)

    var body: some View {
        VStack(spacing: Spacing.s5) {
            Image("SplashMark")
                .resizable()
                .scaledToFit()
                .frame(width: 112)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.s2) {
                Text("app.name")
                    .font(Typography.title)
                    .foregroundStyle(Color.ink)
                Text("splash.tagline")
                    .font(Typography.label)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.midnight.ignoresSafeArea())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SplashView()
        .preferredColorScheme(.dark)
}
