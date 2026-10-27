import SwiftUI

/// 접히는 기기에서 펼칠 때 접힌 배치를 잠시 두었다가 넓은 배치로 (D21, UnfoldRules).
/// - 폭이 접힌 폭 → 펼친 폭으로 늘면 콘텐츠를 접힌 폭 그대로 오른쪽에 붙여 둔다 (접힌 화면은 펼친 화면의 오른쪽 부분)
/// - 앱이 앞에 있을 때부터 1초를 센 뒤 0.8초 한 번에(느리게 시작해 꼬리가 길고 오버슈트 없음) 폭을 풀어 넓은 배치로
/// - 접을 때·회전·동작 줄이기는 유지 없이 바로
/// `container`는 화면(스크롤 뷰) 크기이고, `content`는 지금 보여 줄 크기를 받아 단 수 등을 정한다
/// (유지 중에는 접힌 크기라 접힌 배치가 그대로 남는다)
struct UnfoldLayout<Content: View>: View {
    let container: CGSize
    @ViewBuilder var content: (CGSize) -> Content

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 유지 중인 접힌 크기. nil이면 컨테이너 크기 그대로
    @State private var held: CGSize?
    /// 보이는 폭. 유지 중엔 접힌 폭, 풀 때 펼친 폭으로 애니메이션, 끝나면 nil(자유)
    @State private var shownWidth: CGFloat?
    @State private var holdTask: Task<Void, Never>?

    /// 느리게 시작해 길게 끝나는 곡선, 오버슈트 없음
    static let unfoldAnimation = Animation.timingCurve(0.2, 0, 0, 1, duration: UnfoldRules.unfoldSeconds)

    private var shown: CGSize { held ?? container }

    var body: some View {
        content(shown)
            .frame(width: shownWidth)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onChange(of: container) { old, new in sizeChanged(from: old, to: new) }
            .onChange(of: scenePhase) { _, phase in
                // 펼치는 동안 앱이 뒤에 있었으면 앞에 온 때부터 센다
                if phase == .active, held != nil, holdTask == nil { startHold() }
            }
    }

    private func sizeChanged(from previous: CGSize, to size: CGSize) {
        guard !reduceMotion, UnfoldRules.isUnfold(from: held ?? previous, to: size) else {
            // 접기·회전·처음: 바로
            holdTask?.cancel()
            holdTask = nil
            held = nil
            shownWidth = nil
            return
        }
        held = held ?? previous
        shownWidth = held?.width
        if scenePhase == .active { startHold() }
    }

    private func startHold() {
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(UnfoldRules.holdSeconds))
            guard !Task.isCancelled else { return }
            holdTask = nil
            withAnimation(Self.unfoldAnimation) {
                held = nil
                shownWidth = container.width
            } completion: {
                shownWidth = nil
            }
        }
    }
}
