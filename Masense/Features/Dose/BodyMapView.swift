import SwiftUI

/// 정면 1장 고정 실루엣 위 8구역 (DESIGN_SYSTEM.md 5.3, R6). 거울 보기, 유리 실루엣 (D10).
/// 직전 1회는 `accent`로 채우고 아래 "① 마지막" 칩, 이전 2~4회는 은은한 채움·얇은 테두리.
/// 구역마다 그 부위를 마지막으로 쓴 날짜를 적고, 아래에 부위별 마지막 사용 표를 둔다 (D5).
/// **추천 표시 없음.** 화살표·"다음은" 같은 제안 없이 사용자가 보고 고른다. 실루엣은 성별 표현 없는 중성 아웃라인.
struct BodyMapView: View {
    @Binding var selection: BodySite?
    let history: [SiteUse]
    /// 부위별 마지막 사용 시각 (`SiteRules.lastUseBySite`). 쓴 적 없는 부위는 키가 없다
    var lastUseBySite: [BodySite: Date] = [:]
    var calendar: Calendar = .current

    /// 설계 좌표계. 거울처럼 보이게 화면 왼쪽이 본인의 왼쪽이다 (2026-10-24 사람 결정)
    private static let canvas = CGSize(width: 240, height: 340)

    var body: some View {
        VStack(spacing: Spacing.s2) {
            ZStack(alignment: .topLeading) {
                silhouette
                ForEach(BodySite.allCases) { site in
                    region(site)
                }
            }
            // 좌표계 원점을 캔버스 좌상단에 고정한다. 정렬을 빼면 묶음이 가운데로 밀려 실루엣과 구역이 어긋난다
            .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)

            HStack {
                Text("bodymap.left")
                Spacer()
                Text("bodymap.right")
            }
            .font(Typography.caption)
            .foregroundStyle(Color.inkSecondary)
            .frame(width: Self.canvas.width)
            .accessibilityHidden(true)

            historyRows
                .padding(.top, Spacing.s2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 이력 행

    /// 그림과 같은 방향으로 두 칸씩: 화면 왼쪽이 본인의 왼쪽 (거울)
    private static let siteRows: [(BodySite, BodySite)] = [
        (.upperArmLeft, .upperArmRight),
        (.abdomenUpperLeft, .abdomenUpperRight),
        (.abdomenLowerLeft, .abdomenLowerRight),
        (.thighLeft, .thighRight),
    ]

    @ViewBuilder
    private var historyRows: some View {
        if let last = history.first {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("bodymap.last \(last.site.localizedName) \(shortDate(last.date))")
                    .font(Typography.label)
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Spacing.s3)
                    .padding(.vertical, Spacing.s2)
                    .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                if !lastUseBySite.isEmpty {
                    siteTable
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 부위별 마지막 사용. 쓴 적 없는 부위는 "—"
    private var siteTable: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("bodymap.bySite")
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            Grid(alignment: .leading, horizontalSpacing: Spacing.s4, verticalSpacing: Spacing.s1) {
                ForEach(Self.siteRows.indices, id: \.self) { index in
                    GridRow {
                        siteCell(Self.siteRows[index].0)
                        siteCell(Self.siteRows[index].1)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.s3)
    }

    private func siteCell(_ site: BodySite) -> some View {
        HStack(spacing: Spacing.s2) {
            Text(site.localizedName)
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: Spacing.s1)
            if let date = lastUseBySite[site] {
                Text(verbatim: shortDate(date))
                    .foregroundStyle(Color.ink)
            } else {
                Text(verbatim: "—")
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .font(Typography.caption)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: 실루엣

    /// 유리 실루엣 (D10): 반투명 채움 + 위가 밝은 테두리. FrostCard와 같은 계열
    private var silhouette: some View {
        BodySilhouette()
            .fill(LinearGradient(colors: [Color.frostHighlightBottom, Color.frost.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            .overlay(
                BodySilhouette()
                    .stroke(
                        LinearGradient(colors: [Color.frostHighlightTop, Color.frostHighlightBottom], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 1, lineJoin: .round)
                    )
            )
            .frame(width: Self.canvas.width, height: Self.canvas.height)
            .accessibilityHidden(true)
    }

    // MARK: 구역

    static func frame(for site: BodySite) -> CGRect {
        switch site {
        // 거울 보기: 본인의 왼쪽 부위가 화면 왼쪽. 실루엣(BodySilhouette) 안쪽에 들어가게 맞춘 값
        case .upperArmLeft: return CGRect(x: 48, y: 104, width: 22, height: 48)
        case .upperArmRight: return CGRect(x: 170, y: 104, width: 22, height: 48)
        case .abdomenUpperLeft: return CGRect(x: 90, y: 112, width: 28, height: 32)
        case .abdomenUpperRight: return CGRect(x: 122, y: 112, width: 28, height: 32)
        case .abdomenLowerLeft: return CGRect(x: 90, y: 148, width: 28, height: 32)
        case .abdomenLowerRight: return CGRect(x: 122, y: 148, width: 28, height: 32)
        case .thighLeft: return CGRect(x: 85, y: 212, width: 27, height: 62)
        case .thighRight: return CGRect(x: 128, y: 212, width: 27, height: 62)
        }
    }

    private func region(_ site: BodySite) -> some View {
        let rect = Self.frame(for: site)
        let rank = SiteRules.recencyRank(of: site, in: history)
        let lastDate = lastUseBySite[site] ?? rank.map { history[$0].date }
        let isSelected = selection == site

        return Button {
            selection = site
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill(rank: rank, isSelected: isSelected))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(border(rank: rank, isSelected: isSelected), lineWidth: isSelected ? 1.5 : (rank.map { $0 > 0 } == true ? 0.75 : 1))
                if isSelected {
                    // 색만으로 선택을 알리지 않도록 체크 아이콘
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.midnight)
                } else if let lastDate {
                    // 그 부위를 마지막으로 쓴 날. 구역 크기가 고정이라 글자도 고정 크기
                    Text(verbatim: shortDate(lastDate))
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundStyle(rank == 0 ? Color.midnight : Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 2)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: rect.minX, y: rect.minY)
        .accessibilityLabel(accessibilityLabel(site: site, lastDate: lastDate))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 선택: accent 채움. 직전 1회: accent 1.0. 이전 2~4회: 0.45 → 0.25. 나머지: frost
    private func fill(rank: Int?, isSelected: Bool) -> Color {
        if isSelected { return Color.accent }
        if let rank { return Color.siteRecent(rank: rank) }
        return Color.frost
    }

    /// 선택: ink 1.5px. 이전 2~4회: 얇은 accent 테두리. 나머지: frostBorder
    private func border(rank: Int?, isSelected: Bool) -> Color {
        if isSelected { return Color.ink }
        if let rank, rank > 0 { return Color.accent.opacity(0.6) }
        if rank == 0 { return Color.accent }
        return Color.frostBorder
    }

    private func shortDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)/\(parts.day ?? 0)"
    }

    private func accessibilityLabel(site: BodySite, lastDate: Date?) -> Text {
        guard let lastDate else { return Text(site.localizedName) }
        let date = lastDate.formatted(.dateTime.month(.wide).day())
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
            BodyMapView(
                selection: $selection,
                history: history,
                lastUseBySite: Dictionary(history.map { ($0.site, $0.date) }, uniquingKeysWith: { max($0, $1) })
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .midnightBackground()
        }
    }
    return Demo().preferredColorScheme(.dark)
}

/// 성별 표현 없는 중성 실루엣 한 줄 윤곽 (D10). 설계 좌표 240×340, 좌우 대칭이라 오른쪽 절반을 그리고 거꾸로 거울
struct BodySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 240
        let scaleY = rect.height / 340
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }
        var path = Path()
        path.move(to: p(120, 8))
        path.addCurve(to: p(142, 31), control1: p(133, 8), control2: p(142, 18))
        path.addCurve(to: p(127, 54), control1: p(142, 43), control2: p(135, 51))
        path.addLine(to: p(127, 60))
        path.addCurve(to: p(164, 69), control1: p(131, 64), control2: p(151, 65))
        path.addCurve(to: p(193, 101), control1: p(182, 73), control2: p(193, 84))
        path.addCurve(to: p(197, 161), control1: p(194, 121), control2: p(196, 141))
        path.addCurve(to: p(197, 212), control1: p(198, 181), control2: p(198, 197))
        path.addCurve(to: p(185, 234), control1: p(197, 226), control2: p(191, 234))
        path.addCurve(to: p(174, 218), control1: p(179, 234), control2: p(174, 228))
        path.addCurve(to: p(169, 166), control1: p(173, 200), control2: p(171, 182))
        path.addCurve(to: p(162, 106), control1: p(167, 142), control2: p(165, 120))
        path.addCurve(to: p(156, 105), control1: p(161, 100), control2: p(157, 99))
        path.addCurve(to: p(155, 162), control1: p(154, 124), control2: p(155, 146))
        path.addCurve(to: p(161, 206), control1: p(155, 178), control2: p(161, 190))
        path.addCurve(to: p(154, 330), control1: p(161, 240), control2: p(157, 290))
        path.addCurve(to: p(141, 338), control1: p(154, 336), control2: p(148, 338))
        path.addCurve(to: p(129, 330), control1: p(134, 338), control2: p(129, 336))
        path.addCurve(to: p(123, 226), control1: p(128, 290), control2: p(125, 250))
        path.addCurve(to: p(120, 215), control1: p(122, 219), control2: p(121, 216))
        // 왼쪽 절반: 같은 선을 거꾸로 거울
        path.addCurve(to: p(117, 226), control1: p(119, 216), control2: p(118, 219))
        path.addCurve(to: p(111, 330), control1: p(115, 250), control2: p(112, 290))
        path.addCurve(to: p(99, 338), control1: p(111, 336), control2: p(106, 338))
        path.addCurve(to: p(86, 330), control1: p(92, 338), control2: p(86, 336))
        path.addCurve(to: p(79, 206), control1: p(83, 290), control2: p(79, 240))
        path.addCurve(to: p(85, 162), control1: p(79, 190), control2: p(85, 178))
        path.addCurve(to: p(84, 105), control1: p(85, 146), control2: p(86, 124))
        path.addCurve(to: p(78, 106), control1: p(83, 99), control2: p(79, 100))
        path.addCurve(to: p(71, 166), control1: p(75, 120), control2: p(73, 142))
        path.addCurve(to: p(66, 218), control1: p(69, 182), control2: p(67, 200))
        path.addCurve(to: p(55, 234), control1: p(66, 228), control2: p(61, 234))
        path.addCurve(to: p(43, 212), control1: p(49, 234), control2: p(43, 226))
        path.addCurve(to: p(43, 161), control1: p(42, 197), control2: p(42, 181))
        path.addCurve(to: p(47, 101), control1: p(44, 141), control2: p(46, 121))
        path.addCurve(to: p(76, 69), control1: p(47, 84), control2: p(58, 73))
        path.addCurve(to: p(113, 60), control1: p(89, 65), control2: p(109, 64))
        path.addLine(to: p(113, 54))
        path.addCurve(to: p(98, 31), control1: p(105, 51), control2: p(98, 43))
        path.addCurve(to: p(120, 8), control1: p(98, 18), control2: p(107, 8))
        path.closeSubpath()
        return path
    }
}
