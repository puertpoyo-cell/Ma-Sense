import SwiftUI

/// 정면 실루엣 위 8구역. 최근 4회 사용 부위에 날짜와 농도를 표시한다 (R6).
/// **추천 표시 없음.** 사용자가 보고 고른다. 실루엣은 성별 표현 없는 중성 아웃라인.
struct BodyMapView: View {
    @Binding var selection: BodySite?
    let history: [SiteUse]
    var calendar: Calendar = .current

    /// 설계 좌표계. 정면이므로 화면 왼쪽이 본인의 오른쪽이다
    private static let canvas = CGSize(width: 240, height: 340)

    var body: some View {
        VStack(spacing: Spacing.s2) {
            ZStack(alignment: .topLeading) {
                silhouette
                ForEach(BodySite.allCases) { site in
                    region(site)
                }
            }
            .frame(width: Self.canvas.width, height: Self.canvas.height)

            HStack {
                Text("bodymap.right")
                Spacer()
                Text("bodymap.left")
            }
            .font(Typography.caption)
            .foregroundStyle(Color.inkSecondary)
            .frame(width: Self.canvas.width)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 실루엣

    private var silhouette: some View {
        ZStack(alignment: .topLeading) {
            outline(Circle(), CGRect(x: 98, y: 8, width: 44, height: 44))
            outline(RoundedRectangle(cornerRadius: 18), CGRect(x: 78, y: 58, width: 84, height: 136))
            outline(RoundedRectangle(cornerRadius: 12), CGRect(x: 40, y: 62, width: 34, height: 140))
            outline(RoundedRectangle(cornerRadius: 12), CGRect(x: 166, y: 62, width: 34, height: 140))
            outline(RoundedRectangle(cornerRadius: 14), CGRect(x: 80, y: 196, width: 38, height: 140))
            outline(RoundedRectangle(cornerRadius: 14), CGRect(x: 122, y: 196, width: 38, height: 140))
        }
        .accessibilityHidden(true)
    }

    private func outline<S: Shape>(_ shape: S, _ rect: CGRect) -> some View {
        shape
            .stroke(Color.inkTertiary, lineWidth: 1)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    // MARK: 구역

    static func frame(for site: BodySite) -> CGRect {
        switch site {
        case .upperArmRight: return CGRect(x: 43, y: 70, width: 28, height: 56)
        case .upperArmLeft: return CGRect(x: 169, y: 70, width: 28, height: 56)
        case .abdomenUpperRight: return CGRect(x: 84, y: 112, width: 34, height: 36)
        case .abdomenUpperLeft: return CGRect(x: 122, y: 112, width: 34, height: 36)
        case .abdomenLowerRight: return CGRect(x: 84, y: 152, width: 34, height: 36)
        case .abdomenLowerLeft: return CGRect(x: 122, y: 152, width: 34, height: 36)
        case .thighRight: return CGRect(x: 83, y: 202, width: 32, height: 64)
        case .thighLeft: return CGRect(x: 125, y: 202, width: 32, height: 64)
        }
    }

    private func region(_ site: BodySite) -> some View {
        let rect = Self.frame(for: site)
        let rank = SiteRules.recencyRank(of: site, in: history)
        let lastUse = rank.map { history[$0] }
        let isSelected = selection == site
        // 진한 두 단계(1.0, 0.7) 위에서는 어두운 글자
        let darkText = rank.map { $0 < 2 } ?? false

        return Button {
            selection = site
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill(rank: rank, isSelected: isSelected))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.ink : Color.frostBorder, lineWidth: isSelected ? 2 : 1)
                VStack(spacing: 2) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                    }
                    if let lastUse {
                        Text(verbatim: shortDate(lastUse.date))
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(darkText ? Color.midnight : Color.ink)
            }
            .frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: rect.minX, y: rect.minY)
        .accessibilityLabel(accessibilityLabel(site: site, lastUse: lastUse))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func fill(rank: Int?, isSelected: Bool) -> Color {
        if let rank { return Color.siteRecent(rank: rank) }
        return isSelected ? Color.accentSoft : Color.frost
    }

    private func shortDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)/\(parts.day ?? 0)"
    }

    private func accessibilityLabel(site: BodySite, lastUse: SiteUse?) -> Text {
        guard let lastUse else { return Text(site.localizedName) }
        let date = lastUse.date.formatted(.dateTime.month(.wide).day())
        return Text("bodymap.usedOn \(site.localizedName) \(date)")
    }
}

#Preview {
    struct Demo: View {
        @State private var selection: BodySite? = .thighLeft
        var body: some View {
            let now = Date.now
            let history = [
                SiteUse(site: .abdomenUpperLeft, date: now.addingTimeInterval(-7 * 86_400)),
                SiteUse(site: .abdomenLowerRight, date: now.addingTimeInterval(-14 * 86_400)),
                SiteUse(site: .upperArmRight, date: now.addingTimeInterval(-21 * 86_400)),
                SiteUse(site: .thighRight, date: now.addingTimeInterval(-28 * 86_400)),
            ]
            BodyMapView(selection: $selection, history: history)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .midnightBackground()
        }
    }
    return Demo().preferredColorScheme(.dark)
}
