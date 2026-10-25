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
    private static let canvas = CGSize(width: 240, height: 420)

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
            .overlay(alignment: .topLeading) {
                // 복부 네 구역의 기준점 (배꼽)
                Circle()
                    .fill(Color.frostHighlightTop)
                    .frame(width: 4, height: 4)
                    .offset(x: 118, y: 169)
            }
            .frame(width: Self.canvas.width, height: Self.canvas.height)
            .accessibilityHidden(true)
    }

    // MARK: 구역

    static func frame(for site: BodySite) -> CGRect {
        switch site {
        // 거울 보기: 본인의 왼쪽 부위가 화면 왼쪽. 실루엣(BodySilhouette) 안쪽에 들어가게 맞춘 값
        case .upperArmLeft: return CGRect(x: 53, y: 124, width: 18, height: 40)
        case .upperArmRight: return CGRect(x: 169, y: 124, width: 18, height: 40)
        case .abdomenUpperLeft: return CGRect(x: 92, y: 128, width: 26, height: 30)
        case .abdomenUpperRight: return CGRect(x: 122, y: 128, width: 26, height: 30)
        case .abdomenLowerLeft: return CGRect(x: 92, y: 184, width: 26, height: 30)
        case .abdomenLowerRight: return CGRect(x: 122, y: 184, width: 26, height: 30)
        case .thighLeft: return CGRect(x: 85, y: 248, width: 26, height: 56)
        case .thighRight: return CGRect(x: 129, y: 248, width: 26, height: 56)
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

/// 성별 표현 없는 중성 실루엣 한 줄 윤곽 (D10, D12에서 머리부터 발까지 실제 비율로 다시 그림). 설계 좌표 240×420,
/// 좌우 대칭이라 오른쪽 절반을 그리고 거꾸로 거울. 체형 단계를 바꾸지 않는 한 가지 평균 체형 (COMPLIANCE.md 2.2)
struct BodySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 240
        let scaleY = rect.height / 420
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }
        var path = Path()
        path.move(to: p(120, 8))
        path.addCurve(to: p(143, 33), control1: p(134, 8), control2: p(143, 19))
        path.addCurve(to: p(128, 61), control1: p(143, 47), control2: p(136, 57))
        path.addLine(to: p(129, 72))
        path.addCurve(to: p(165, 82), control1: p(138, 77), control2: p(154, 78))
        path.addCurve(to: p(189, 112), control1: p(180, 86), control2: p(188, 96))
        path.addCurve(to: p(188, 166), control1: p(189, 126), control2: p(190, 146))
        path.addCurve(to: p(192, 214), control1: p(188, 180), control2: p(191, 200))
        path.addCurve(to: p(191, 238), control1: p(193, 224), control2: p(192, 232))
        path.addCurve(to: p(187, 266), control1: p(193, 250), control2: p(193, 262))
        path.addCurve(to: p(177, 256), control1: p(182, 269), control2: p(177, 264))
        path.addCurve(to: p(178, 238), control1: p(177, 248), control2: p(178, 242))
        path.addCurve(to: p(173, 190), control1: p(177, 222), control2: p(174, 204))
        path.addCurve(to: p(170, 168), control1: p(172, 182), control2: p(171, 176))
        path.addCurve(to: p(161, 108), control1: p(168, 148), control2: p(166, 126))
        path.addCurve(to: p(155, 172), control1: p(158, 124), control2: p(155, 146))
        path.addCurve(to: p(164, 222), control1: p(155, 190), control2: p(163, 204))
        path.addCurve(to: p(156, 318), control1: p(165, 250), control2: p(160, 290))
        path.addCurve(to: p(158, 366), control1: p(155, 330), control2: p(160, 348))
        path.addCurve(to: p(150, 398), control1: p(157, 380), control2: p(152, 392))
        path.addCurve(to: p(147, 414), control1: p(152, 405), control2: p(153, 412))
        path.addLine(to: p(134, 414))
        path.addCurve(to: p(130, 402), control1: p(129, 414), control2: p(128, 408))
        path.addCurve(to: p(128, 352), control1: p(129, 390), control2: p(127, 370))
        path.addCurve(to: p(128, 320), control1: p(129, 340), control2: p(128, 330))
        path.addCurve(to: p(123, 246), control1: p(127, 296), control2: p(125, 262))
        path.addCurve(to: p(120, 238), control1: p(122, 240), control2: p(121, 238))
        // 왼쪽 절반: 같은 선을 거꾸로 거울
        path.addCurve(to: p(117, 246), control1: p(119, 238), control2: p(118, 240))
        path.addCurve(to: p(112, 320), control1: p(115, 262), control2: p(113, 296))
        path.addCurve(to: p(112, 352), control1: p(112, 330), control2: p(111, 340))
        path.addCurve(to: p(110, 402), control1: p(113, 370), control2: p(111, 390))
        path.addCurve(to: p(106, 414), control1: p(112, 408), control2: p(111, 414))
        path.addLine(to: p(93, 414))
        path.addCurve(to: p(90, 398), control1: p(87, 412), control2: p(88, 405))
        path.addCurve(to: p(82, 366), control1: p(88, 392), control2: p(83, 380))
        path.addCurve(to: p(84, 318), control1: p(80, 348), control2: p(85, 330))
        path.addCurve(to: p(76, 222), control1: p(80, 290), control2: p(75, 250))
        path.addCurve(to: p(85, 172), control1: p(77, 204), control2: p(85, 190))
        path.addCurve(to: p(79, 108), control1: p(85, 146), control2: p(82, 124))
        path.addCurve(to: p(70, 168), control1: p(74, 126), control2: p(72, 148))
        path.addCurve(to: p(67, 190), control1: p(69, 176), control2: p(68, 182))
        path.addCurve(to: p(62, 238), control1: p(66, 204), control2: p(63, 222))
        path.addCurve(to: p(63, 256), control1: p(62, 242), control2: p(63, 248))
        path.addCurve(to: p(53, 266), control1: p(63, 264), control2: p(58, 269))
        path.addCurve(to: p(49, 238), control1: p(47, 262), control2: p(47, 250))
        path.addCurve(to: p(48, 214), control1: p(48, 232), control2: p(47, 224))
        path.addCurve(to: p(52, 166), control1: p(49, 200), control2: p(52, 180))
        path.addCurve(to: p(51, 112), control1: p(50, 146), control2: p(51, 126))
        path.addCurve(to: p(75, 82), control1: p(52, 96), control2: p(60, 86))
        path.addCurve(to: p(111, 72), control1: p(86, 78), control2: p(102, 77))
        path.addLine(to: p(112, 61))
        path.addCurve(to: p(97, 33), control1: p(104, 57), control2: p(97, 47))
        path.addCurve(to: p(120, 8), control1: p(97, 19), control2: p(106, 8))
        path.closeSubpath()
        return path
    }
}
