import SwiftUI

/// 정면 1장 고정 실루엣 위 8구역 (DESIGN_SYSTEM.md 5.3, R6). 거울 보기, 맑은 유리 실루엣.
/// D13: 여/남 그림 두 가지(건강 앱 성별 → 없으면 남성, 설정에서 바꿈), 구역은 알약 모양, 팔은 날짜를 바깥에.
/// 직전 1회는 `accent`로 채우고 아래 "① 마지막" 칩, 이전 2~4회는 은은한 채움·얇은 테두리.
/// 구역마다 그 부위를 마지막으로 쓴 날짜를 적고, 아래에 부위별 마지막 사용 표를 둔다 (D5).
/// **추천 표시 없음.** 화살표·"다음은" 같은 제안 없이 사용자가 보고 고른다. 체형 단계 없이 평균 체형 두 가지만 (COMPLIANCE.md 2.2).
struct BodyMapView: View {
    @Binding var selection: BodySite?
    let history: [SiteUse]
    /// 부위별 마지막 사용 시각 (`SiteRules.lastUseBySite`). 쓴 적 없는 부위는 키가 없다
    var lastUseBySite: [BodySite: Date] = [:]
    var calendar: Calendar = .current
    /// 설정의 바디맵 그림 선택과 건강 앱에서 읽은 성별 (D13). 기기 화면 상태라 UserDefaults
    @AppStorage("bodyMap.figure") private var preferenceRaw = BodyFigurePreference.automatic.rawValue
    @AppStorage("health.bodyFigure") private var healthFigureRaw = ""

    private var figure: BodyFigure {
        #if DEBUG
        if ScreenshotRoute.current == .doseSheetFemale { return .female }
        #endif
        return BodyFigureRules.figure(
            preference: BodyFigurePreference(rawValue: preferenceRaw) ?? .automatic,
            healthFigure: BodyFigure(rawValue: healthFigureRaw)
        )
    }

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

    /// 맑은 유리 (D13 시안 A): 위가 밝은 반투명 채움 + 왼쪽 위에서 빛을 받는 테두리, 발밑 옅은 빛, 배꼽 점
    private var silhouette: some View {
        let shape = BodySilhouette(figure: figure)
        let navel = Self.navel(for: figure)
        return ZStack(alignment: .topLeading) {
            Ellipse()
                .fill(RadialGradient(colors: [Color.accent.opacity(0.18), Color.accent.opacity(0)], center: .center, startRadius: 0, endRadius: 46))
                .frame(width: 92, height: 10)
                .offset(x: 74, y: 411)
            shape
                .fill(LinearGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.40), Color.white.opacity(0.14), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 1.1, lineJoin: .round)
                    )
                )
                .frame(width: Self.canvas.width, height: Self.canvas.height)
            // 복부 네 구역의 기준점 (배꼽)
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 4, height: 4)
                .offset(x: navel.x - 2, y: navel.y - 2)
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    static func navel(for figure: BodyFigure) -> CGPoint {
        figure == .female ? CGPoint(x: 120, y: 172) : CGPoint(x: 120, y: 170)
    }

    // MARK: 구역

    /// 실루엣 안쪽에 들어가게 맞춘 구역 (거울 보기: 본인의 왼쪽 부위가 화면 왼쪽). 팔은 팔 가운데 선에 맞춰 기울인다
    static func frame(for site: BodySite, figure: BodyFigure) -> CGRect {
        switch (figure, site) {
        case (.female, .upperArmLeft): return CGRect(x: 66, y: 122, width: 11, height: 34)
        case (.female, .upperArmRight): return CGRect(x: 163, y: 122, width: 11, height: 34)
        case (.female, .abdomenUpperLeft): return CGRect(x: 93, y: 130, width: 25, height: 28)
        case (.female, .abdomenUpperRight): return CGRect(x: 122, y: 130, width: 25, height: 28)
        case (.female, .abdomenLowerLeft): return CGRect(x: 93, y: 184, width: 25, height: 28)
        case (.female, .abdomenLowerRight): return CGRect(x: 122, y: 184, width: 25, height: 28)
        case (.female, .thighLeft): return CGRect(x: 87, y: 252, width: 24, height: 52)
        case (.female, .thighRight): return CGRect(x: 129, y: 252, width: 24, height: 52)
        case (.male, .upperArmLeft): return CGRect(x: 52, y: 122, width: 14, height: 38)
        case (.male, .upperArmRight): return CGRect(x: 174, y: 122, width: 14, height: 38)
        case (.male, .abdomenUpperLeft): return CGRect(x: 92, y: 128, width: 26, height: 30)
        case (.male, .abdomenUpperRight): return CGRect(x: 122, y: 128, width: 26, height: 30)
        case (.male, .abdomenLowerLeft): return CGRect(x: 92, y: 182, width: 26, height: 30)
        case (.male, .abdomenLowerRight): return CGRect(x: 122, y: 182, width: 26, height: 30)
        case (.male, .thighLeft): return CGRect(x: 87, y: 250, width: 25, height: 54)
        case (.male, .thighRight): return CGRect(x: 128, y: 250, width: 25, height: 54)
        }
    }

    /// 팔 구역 기울기 (도). 화면 오른쪽 팔은 아래가 바깥으로, 왼쪽은 거울
    private static func tilt(for site: BodySite, figure: BodyFigure) -> Double {
        let degrees: Double = figure == .female ? 5 : 6
        switch site {
        case .upperArmRight: return -degrees
        case .upperArmLeft: return degrees
        default: return 0
        }
    }

    private static func isArm(_ site: BodySite) -> Bool {
        site == .upperArmLeft || site == .upperArmRight
    }

    /// 누르기 쉬운 최소 크기
    private static let minimumTapSize: CGFloat = 30

    @ViewBuilder
    private func region(_ site: BodySite) -> some View {
        let rect = Self.frame(for: site, figure: figure)
        let rank = SiteRules.recencyRank(of: site, in: history)
        let lastDate = lastUseBySite[site] ?? rank.map { history[$0].date }
        let isSelected = selection == site
        let isArm = Self.isArm(site)
        let tapSize = CGSize(width: max(rect.width, Self.minimumTapSize), height: max(rect.height, Self.minimumTapSize))

        Button {
            selection = site
        } label: {
            ZStack {
                Capsule(style: .continuous)
                    .fill(fill(rank: rank, isSelected: isSelected))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(border(rank: rank, isSelected: isSelected), lineWidth: isSelected ? 1.5 : 0.8)
                    )
                    // 직전 1회·선택은 은은하게 빛난다
                    .shadow(color: (isSelected || rank == 0) ? Color.accent.opacity(0.55) : .clear, radius: 5)
                    .frame(width: rect.width, height: rect.height)
                    .rotationEffect(.degrees(Self.tilt(for: site, figure: figure)))
                if isSelected {
                    // 색만으로 선택을 알리지 않도록 체크 아이콘
                    Image(systemName: "checkmark")
                        .font(.system(size: isArm ? 8 : 11, weight: .bold))
                        .foregroundStyle(Color.midnight)
                } else if let lastDate, !isArm {
                    // 그 부위를 마지막으로 쓴 날. 구역 크기가 고정이라 글자도 고정 크기
                    Text(verbatim: shortDate(lastDate))
                        .font(.system(size: 8.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(rank == 0 ? Color.midnight : Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: rect.width - 2)
                }
            }
            .frame(width: tapSize.width, height: tapSize.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: rect.midX - tapSize.width / 2, y: rect.midY - tapSize.height / 2)
        .accessibilityLabel(accessibilityLabel(site: site, lastDate: lastDate))
        .accessibilityAddTraits(isSelected ? .isSelected : [])

        // 팔은 가늘어 날짜를 팔 바깥에 적는다
        if isArm, !isSelected, let lastDate {
            let isScreenRight = rect.midX > Self.canvas.width / 2
            Text(verbatim: shortDate(lastDate))
                .font(.system(size: 8.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(rank == 0 ? Color.accent : Color.inkSecondary)
                .lineLimit(1)
                .frame(width: Self.armLabelWidth, alignment: isScreenRight ? .leading : .trailing)
                .offset(
                    x: isScreenRight ? rect.maxX + 5 : rect.minX - 5 - Self.armLabelWidth,
                    y: rect.midY - 6
                )
                .accessibilityHidden(true)
        }
    }

    private static let armLabelWidth: CGFloat = 30

    /// 선택: accent 채움. 직전 1회: accent 1.0. 이전 2~4회: 0.45 → 0.25. 나머지: 옅은 유리
    private func fill(rank: Int?, isSelected: Bool) -> Color {
        if isSelected { return Color.accent }
        if let rank { return Color.siteRecent(rank: rank) }
        return Color.white.opacity(0.07)
    }

    /// 선택: ink 1.5px. 이전 2~4회: 얇은 accent 테두리. 나머지: 옅은 흰 테두리
    private func border(rank: Int?, isSelected: Bool) -> Color {
        if isSelected { return Color.ink }
        if let rank, rank > 0 { return Color.accent.opacity(0.6) }
        if rank == 0 { return Color.accent }
        return Color.white.opacity(0.18)
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

/// 여/남 실루엣 한 줄 윤곽 (D13). 설계 좌표 240×420, 좌우 대칭이라 오른쪽 절반을 그리고 거꾸로 거울.
/// 체형 단계를 바꾸지 않는 평균 체형 두 가지 (COMPLIANCE.md 2.2). 참고 이미지를 쓰지 않고 직접 그린 곡선
struct BodySilhouette: Shape {
    var figure: BodyFigure = .male

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 240
        let scaleY = rect.height / 420
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }
        switch figure {
        case .female: return femalePath(p)
        case .male: return malePath(p)
        }
    }
}

/// 여성: 단발 머리, 좁고 둥근 어깨, 가는 팔, 허리·골반 곡선 (설계 좌표 240×420, 오른쪽 절반 → 거울)
private func femalePath(_ p: (CGFloat, CGFloat) -> CGPoint) -> Path {
    var path = Path()
    path.move(to: p(120, 6))
    path.addCurve(to: p(149, 36), control1: p(137, 6), control2: p(149, 18))
    path.addCurve(to: p(142, 64), control1: p(149, 50), control2: p(148, 60))
    path.addCurve(to: p(130, 61), control1: p(138, 66), control2: p(133, 64))
    path.addLine(to: p(128, 74))
    path.addCurve(to: p(159, 84), control1: p(136, 79), control2: p(150, 81))
    path.addCurve(to: p(175, 108), control1: p(169, 87), control2: p(174, 96))
    path.addCurve(to: p(178, 166), control1: p(176, 126), control2: p(178, 146))
    path.addCurve(to: p(184, 226), control1: p(179, 186), control2: p(182, 208))
    path.addCurve(to: p(181, 254), control1: p(186, 238), control2: p(186, 250))
    path.addCurve(to: p(171, 244), control1: p(176, 257), control2: p(171, 252))
    path.addCurve(to: p(172, 226), control1: p(171, 238), control2: p(172, 232))
    path.addCurve(to: p(164, 170), control1: p(170, 208), control2: p(166, 188))
    path.addCurve(to: p(157, 112), control1: p(162, 150), control2: p(160, 128))
    path.addCurve(to: p(157, 143), control1: p(160, 122), control2: p(161, 132))
    path.addCurve(to: p(151, 173), control1: p(153, 153), control2: p(151, 163))
    path.addCurve(to: p(164, 216), control1: p(151, 187), control2: p(160, 200))
    path.addCurve(to: p(165, 252), control1: p(167, 228), control2: p(167, 240))
    path.addCurve(to: p(153, 320), control1: p(163, 276), control2: p(156, 300))
    path.addCurve(to: p(154, 368), control1: p(152, 334), control2: p(156, 350))
    path.addCurve(to: p(147, 400), control1: p(153, 382), control2: p(149, 394))
    path.addCurve(to: p(145, 414), control1: p(149, 406), control2: p(150, 412))
    path.addLine(to: p(133, 414))
    path.addCurve(to: p(130, 402), control1: p(129, 414), control2: p(128, 408))
    path.addCurve(to: p(127, 352), control1: p(128, 390), control2: p(126, 370))
    path.addCurve(to: p(126, 320), control1: p(128, 340), control2: p(127, 330))
    path.addCurve(to: p(122, 250), control1: p(124, 296), control2: p(123, 268))
    path.addCurve(to: p(120, 242), control1: p(121, 244), control2: p(120.5, 242))
    // 왼쪽 절반: 같은 선을 거꾸로 거울
    path.addCurve(to: p(118, 250), control1: p(119.5, 242), control2: p(119, 244))
    path.addCurve(to: p(114, 320), control1: p(117, 268), control2: p(116, 296))
    path.addCurve(to: p(113, 352), control1: p(113, 330), control2: p(112, 340))
    path.addCurve(to: p(110, 402), control1: p(114, 370), control2: p(112, 390))
    path.addCurve(to: p(107, 414), control1: p(112, 408), control2: p(111, 414))
    path.addLine(to: p(95, 414))
    path.addCurve(to: p(93, 400), control1: p(90, 412), control2: p(91, 406))
    path.addCurve(to: p(86, 368), control1: p(91, 394), control2: p(87, 382))
    path.addCurve(to: p(87, 320), control1: p(84, 350), control2: p(88, 334))
    path.addCurve(to: p(75, 252), control1: p(84, 300), control2: p(77, 276))
    path.addCurve(to: p(76, 216), control1: p(73, 240), control2: p(73, 228))
    path.addCurve(to: p(89, 173), control1: p(80, 200), control2: p(89, 187))
    path.addCurve(to: p(83, 143), control1: p(89, 163), control2: p(87, 153))
    path.addCurve(to: p(83, 112), control1: p(79, 132), control2: p(80, 122))
    path.addCurve(to: p(76, 170), control1: p(80, 128), control2: p(78, 150))
    path.addCurve(to: p(68, 226), control1: p(74, 188), control2: p(70, 208))
    path.addCurve(to: p(69, 244), control1: p(68, 232), control2: p(69, 238))
    path.addCurve(to: p(59, 254), control1: p(69, 252), control2: p(64, 257))
    path.addCurve(to: p(56, 226), control1: p(54, 250), control2: p(54, 238))
    path.addCurve(to: p(62, 166), control1: p(58, 208), control2: p(61, 186))
    path.addCurve(to: p(65, 108), control1: p(62, 146), control2: p(64, 126))
    path.addCurve(to: p(81, 84), control1: p(66, 96), control2: p(71, 87))
    path.addCurve(to: p(112, 74), control1: p(90, 81), control2: p(104, 79))
    path.addLine(to: p(110, 61))
    path.addCurve(to: p(98, 64), control1: p(107, 64), control2: p(102, 66))
    path.addCurve(to: p(91, 36), control1: p(92, 60), control2: p(91, 50))
    path.addCurve(to: p(120, 6), control1: p(91, 18), control2: p(103, 6))
    path.closeSubpath()
    return path
}

/// 남성: 짧은 머리, 넓은 어깨와 삼각근, 위가 넓은 몸통, 좁은 골반 (설계 좌표 240×420, 오른쪽 절반 → 거울)
private func malePath(_ p: (CGFloat, CGFloat) -> CGPoint) -> Path {
    var path = Path()
    path.move(to: p(120, 8))
    path.addCurve(to: p(144, 34), control1: p(135, 8), control2: p(144, 19))
    path.addCurve(to: p(131, 62), control1: p(144, 48), control2: p(138, 58))
    path.addLine(to: p(133, 74))
    path.addCurve(to: p(170, 84), control1: p(145, 79), control2: p(160, 80))
    path.addCurve(to: p(190, 116), control1: p(184, 88), control2: p(191, 100))
    path.addCurve(to: p(192, 168), control1: p(190, 132), control2: p(194, 150))
    path.addCurve(to: p(196, 222), control1: p(192, 184), control2: p(196, 204))
    path.addCurve(to: p(194, 240), control1: p(196, 230), control2: p(195, 236))
    path.addCurve(to: p(189, 265), control1: p(196, 252), control2: p(195, 262))
    path.addCurve(to: p(180, 254), control1: p(184, 267), control2: p(180, 262))
    path.addCurve(to: p(181, 240), control1: p(180, 248), control2: p(181, 243))
    path.addCurve(to: p(177, 190), control1: p(180, 222), control2: p(178, 204))
    path.addCurve(to: p(174, 170), control1: p(176, 182), control2: p(175, 176))
    path.addCurve(to: p(165, 112), control1: p(172, 150), control2: p(170, 128))
    path.addCurve(to: p(160, 160), control1: p(166, 126), control2: p(164, 144))
    path.addCurve(to: p(156, 190), control1: p(158, 170), control2: p(156, 180))
    path.addCurve(to: p(161, 224), control1: p(156, 202), control2: p(160, 212))
    path.addCurve(to: p(156, 318), control1: p(163, 256), control2: p(160, 290))
    path.addCurve(to: p(159, 366), control1: p(155, 330), control2: p(161, 348))
    path.addCurve(to: p(151, 398), control1: p(158, 380), control2: p(153, 392))
    path.addCurve(to: p(148, 414), control1: p(153, 405), control2: p(154, 412))
    path.addLine(to: p(134, 414))
    path.addCurve(to: p(131, 402), control1: p(130, 414), control2: p(129, 408))
    path.addCurve(to: p(128, 352), control1: p(129, 390), control2: p(127, 370))
    path.addCurve(to: p(127, 320), control1: p(129, 340), control2: p(128, 330))
    path.addCurve(to: p(122, 248), control1: p(125, 296), control2: p(123, 264))
    path.addCurve(to: p(120, 240), control1: p(121, 242), control2: p(120.5, 240))
    // 왼쪽 절반: 같은 선을 거꾸로 거울
    path.addCurve(to: p(118, 248), control1: p(119.5, 240), control2: p(119, 242))
    path.addCurve(to: p(113, 320), control1: p(117, 264), control2: p(115, 296))
    path.addCurve(to: p(112, 352), control1: p(112, 330), control2: p(111, 340))
    path.addCurve(to: p(109, 402), control1: p(113, 370), control2: p(111, 390))
    path.addCurve(to: p(106, 414), control1: p(111, 408), control2: p(110, 414))
    path.addLine(to: p(92, 414))
    path.addCurve(to: p(89, 398), control1: p(86, 412), control2: p(87, 405))
    path.addCurve(to: p(81, 366), control1: p(87, 392), control2: p(82, 380))
    path.addCurve(to: p(84, 318), control1: p(79, 348), control2: p(85, 330))
    path.addCurve(to: p(79, 224), control1: p(80, 290), control2: p(77, 256))
    path.addCurve(to: p(84, 190), control1: p(80, 212), control2: p(84, 202))
    path.addCurve(to: p(80, 160), control1: p(84, 180), control2: p(82, 170))
    path.addCurve(to: p(75, 112), control1: p(76, 144), control2: p(74, 126))
    path.addCurve(to: p(66, 170), control1: p(70, 128), control2: p(68, 150))
    path.addCurve(to: p(63, 190), control1: p(65, 176), control2: p(64, 182))
    path.addCurve(to: p(59, 240), control1: p(62, 204), control2: p(60, 222))
    path.addCurve(to: p(60, 254), control1: p(59, 243), control2: p(60, 248))
    path.addCurve(to: p(51, 265), control1: p(60, 262), control2: p(56, 267))
    path.addCurve(to: p(46, 240), control1: p(45, 262), control2: p(44, 252))
    path.addCurve(to: p(44, 222), control1: p(45, 236), control2: p(44, 230))
    path.addCurve(to: p(48, 168), control1: p(44, 204), control2: p(48, 184))
    path.addCurve(to: p(50, 116), control1: p(46, 150), control2: p(50, 132))
    path.addCurve(to: p(70, 84), control1: p(49, 100), control2: p(56, 88))
    path.addCurve(to: p(107, 74), control1: p(80, 80), control2: p(95, 79))
    path.addLine(to: p(109, 62))
    path.addCurve(to: p(96, 34), control1: p(102, 58), control2: p(96, 48))
    path.addCurve(to: p(120, 8), control1: p(96, 19), control2: p(105, 8))
    path.closeSubpath()
    return path
}
