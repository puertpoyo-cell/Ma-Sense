import SwiftUI

/// 탭 화면 본문을 펼친 가로 화면에서 2단으로 (D23, UnfoldRules.columns). 접힌 폭·세로 펼침은 leading 아래 trailing 한 단.
/// `UnfoldLayout`을 거치므로 펼칠 때 접힌 배치를 1초 두었다가 넓은 배치로 바뀐다 (D21).
/// `footer`는 단 아래 전체 폭에 놓인다 (안내 줄 등)
struct UnfoldColumns<Leading: View, Trailing: View, Footer: View>: View {
    let container: CGSize
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        UnfoldLayout(container: container) { shown in
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                if UnfoldRules.columns(for: shown) == 2 {
                    HStack(alignment: .top, spacing: Spacing.cardGap) {
                        VStack(alignment: .leading, spacing: Spacing.cardGap) { leading() }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        VStack(alignment: .leading, spacing: Spacing.cardGap) { trailing() }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                } else {
                    leading()
                    trailing()
                }
                footer()
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
            // 팝업이 마지막 카드를 가리지 않게 아래 여유
            .padding(.bottom, Spacing.s6)
        }
    }
}

extension UnfoldColumns where Footer == EmptyView {
    init(container: CGSize, @ViewBuilder leading: @escaping () -> Leading, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(container: container, leading: leading, trailing: trailing, footer: { EmptyView() })
    }
}

extension View {
    /// 스크롤 화면 크기를 `UnfoldLayout`에 넘기기 위해 읽는다
    func readsViewportSize(into size: Binding<CGSize>) -> some View {
        onGeometryChange(for: CGSize.self) { $0.size } action: { size.wrappedValue = $0 }
    }
}
