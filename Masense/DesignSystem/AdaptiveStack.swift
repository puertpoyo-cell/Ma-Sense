import SwiftUI

/// 접근성 글자 크기(AX1 이상)에서는 가로 배치를 세로로 바꾼다. Dynamic Type XXL 이상에서 잘림 방지 (PRD 9).
struct AdaptiveStack<Content: View>: View {
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat?
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: verticalAlignment, spacing: spacing) {
                content()
            }
        }
    }
}
