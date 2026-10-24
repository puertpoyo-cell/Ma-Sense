import SwiftUI

/// 정면 1장 고정 실루엣 위 8구역 (DESIGN_SYSTEM.md 5.3, R6).
/// 직전 1회는 `accent`로 채우고 아래 "① 마지막" 칩, 이전 2~4회는 은은한 채움·얇은 테두리.
/// 구역마다 그 부위를 마지막으로 쓴 날짜를 적고, 아래에 부위별 마지막 사용 표를 둔다 (D5).
/// **추천 표시 없음.** 화살표·"다음은" 같은 제안 없이 사용자가 보고 고른다. 실루엣은 성별 표현 없는 중성 아웃라인.
struct BodyMapView: View {
    @Binding var selection: BodySite?
    let history: [SiteUse]
    /// 부위별 마지막 사용 시각 (`SiteRules.lastUseBySite`). 쓴 적 없는 부위는 키가 없다
    var lastUseBySite: [BodySite: Date] = [:]
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
            // 좌표계 원점을 캔버스 좌상단에 고정한다. 정렬을 빼면 묶음이 가운데로 밀려 실루엣과 구역이 어긋난다
            .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)

            HStack {
                Text("bodymap.right")
                Spacer()
                Text("bodymap.left")
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

    /// 그림과 같은 방향으로 두 칸씩: 화면 왼쪽이 본인의 오른쪽
    private static let siteRows: [(BodySite, BodySite)] = [
        (.upperArmRight, .upperArmLeft),
        (.abdomenUpperRight, .abdomenUpperLeft),
        (.abdomenLowerRight, .abdomenLowerLeft),
        (.thighRight, .thighLeft),
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

    private var silhouette: some View {
        ZStack(alignment: .topLeading) {
            outline(Circle(), CGRect(x: 98, y: 8, width: 44, height: 44))
            outline(RoundedRectangle(cornerRadius: 18), CGRect(x: 78, y: 58, width: 84, height: 136))
            outline(RoundedRectangle(cornerRadius: 12), CGRect(x: 40, y: 62, width: 34, height: 140))
            outline(RoundedRectangle(cornerRadius: 12), CGRect(x: 166, y: 62, width: 34, height: 140))
            outline(RoundedRectangle(cornerRadius: 14), CGRect(x: 80, y: 196, width: 38, height: 140))
            outline(RoundedRectangle(cornerRadius: 14), CGRect(x: 122, y: 196, width: 38, height: 140))
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
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
