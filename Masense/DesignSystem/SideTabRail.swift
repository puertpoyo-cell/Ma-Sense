import SwiftUI

/// 접힌 화면(상태 표시줄이 옆 기둥)에서 아래 탭 바 대신 옆에 세로로 놓는 탭 레일 (D23-1, UnfoldRules.tabRailEdge).
/// 시스템 탭 바와 같은 네 탭을 아이콘·이름으로 세로 나열. 글래스 알약 모양, 고른 탭은 강조색
struct SideTabRail<Tab: Hashable>: View {
    struct Item: Identifiable {
        let tag: Tab
        let title: LocalizedStringKey
        let systemImage: String
        var id: Tab { tag }
    }

    let items: [Item]
    @Binding var selection: Tab

    static var width: CGFloat { 64 }

    var body: some View {
        VStack(spacing: Spacing.s2) {
            ForEach(items) { item in
                Button {
                    selection = item.tag
                } label: {
                    VStack(spacing: Spacing.s1) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 20, weight: .medium))
                        Text(item.title)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selection == item.tag ? Color.accent : Color.inkSecondary)
                    .frame(width: Self.width - Spacing.s3, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .fill(selection == item.tag ? Color.accentSoft : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item.tag ? [.isSelected] : [])
            }
        }
        .padding(.vertical, Spacing.s3)
        .padding(.horizontal, Spacing.s1 + Spacing.s1 / 2)
        .background(.ultraThinMaterial)
        .background(Color.frost)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.frostBorder, lineWidth: 1)
        )
        .padding(.horizontal, Spacing.s2)
        .frame(maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("tab.rail.a11y"))
    }
}
