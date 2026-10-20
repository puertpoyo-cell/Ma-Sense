import SwiftUI

/// "기록했습니다." 토스트. 1.2초, 하단. 축하 애니메이션 없음 (DESIGN_SYSTEM.md 5, 6).
struct RecordedToast: View {
    var body: some View {
        Text("toast.recorded")
            .font(Typography.label)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Spacing.s5)
            .padding(.vertical, Spacing.s3)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.frostBorder, lineWidth: 1))
    }
}

private struct RecordedToastModifier: ViewModifier {
    @Binding var isPresented: Bool

    private static let visibleDuration: Duration = .milliseconds(1200)
    private static let fade = Animation.easeOut(duration: 0.25)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    RecordedToast()
                        .padding(.bottom, Spacing.s6)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .task {
                            try? await Task.sleep(for: Self.visibleDuration)
                            withAnimation(Self.fade) { isPresented = false }
                        }
                }
            }
            .animation(Self.fade, value: isPresented)
    }
}

extension View {
    /// `isPresented`를 `true`로 바꾸면 토스트가 1.2초 보였다가 스스로 `false`로 돌아간다.
    func recordedToast(isPresented: Binding<Bool>) -> some View {
        modifier(RecordedToastModifier(isPresented: isPresented))
    }
}

#Preview {
    struct Demo: View {
        @State private var shown = false
        var body: some View {
            VStack {
                PrimaryButton("action.logDose") { shown = true }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .midnightBackground()
            .recordedToast(isPresented: $shown)
            .preferredColorScheme(.dark)
        }
    }
    return Demo()
}
