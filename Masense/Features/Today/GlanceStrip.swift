import SwiftUI

/// 카운트다운 카드 안 "한눈에" 줄 (D14, D15에서 카드 하나로 합침).
/// 왼쪽 바디맵(최근 부위만 빛남, D21: 세 줄 높이의 90%, 최근 4회를 뒤로 갈수록 흐리게), 오른쪽 세 줄: 체중 · 남은 펜(회차) · 지난 부위.
/// 숫자만, 판단·다음 부위 추천 없음 (R6)
struct GlanceStrip: View {
    let figure: BodyFigure
    let latestWeight: WeightSampleSnapshot?
    let latestBodyFat: MetricReading?
    let pens: PenStatus?
    let usedDoses: Int?
    let totalDoses: Int?
    let exhaustionDate: Date?
    /// 최근 순. 첫 번째가 지난 부위
    var recentSites: [SiteUse] = []
    var onOpenWeight: () -> Void = {}

    @Environment(\.calendar) private var calendar
    /// 오른쪽 세 줄의 높이. 그림은 이 높이의 90%
    @State private var rowsHeight: CGFloat = 0

    /// 바디맵 설계 좌표 크기
    private static let designSize = CGSize(width: 240, height: 420)
    /// 그림 높이 = 세 줄 높이 × 이 비율
    private static let figureHeightRatio: CGFloat = 0.9
    /// 그림 폭 상한 (칸 폭). 세로로 긴 그림이라 보통 높이에서 정해진다
    private static let maxFigureWidth: CGFloat = 120
    /// 처음 그릴 때(줄 높이를 아직 모를 때) 쓰는 비율
    private static let fallbackScale: CGFloat = 0.36
    /// 이전 부위 점의 불투명도 (최근 순, 첫 번째는 지난 부위라 1)
    private static let siteOpacities: [Double] = [1, 0.3, 0.25, 0.2]
    /// 이전 부위 점은 한 단계 작게
    private static let olderSiteScale: CGFloat = 0.75

    private var lastSite: SiteUse? { recentSites.first }

    /// 세 줄 높이에 맞춘 비율. 폭 상한을 넘지 않는다
    private var scale: CGFloat {
        guard rowsHeight > 0 else { return Self.fallbackScale }
        let byHeight = rowsHeight * Self.figureHeightRatio / Self.designSize.height
        let byWidth = Self.maxFigureWidth / Self.designSize.width
        return min(byHeight, byWidth)
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s4) {
            figureView
            VStack(spacing: Spacing.s3) {
                Button(action: onOpenWeight) {
                    row("glance.weight", value: weightValue, detail: weightDetail)
                }
                .buttonStyle(.plain)
                BlueprintDivider(crosshair: .none)
                if let pens {
                    row(pens.isSingleUse ? "glance.pens" : "glance.doses", value: pensValue(pens), detail: pensDetail)
                    BlueprintDivider(crosshair: .none)
                }
                row("glance.lastSite", value: siteValue, detail: lastSite.map { Text(verbatim: shortDate($0.date)) })
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
        }
        .padding(Spacing.cellPadding)
    }

    // MARK: 값

    private var weightValue: Text {
        guard let latestWeight else { return Text("glance.none") }
        return Text(verbatim: latestWeight.kilograms.formatted(.number.precision(.fractionLength(1))))
            + Text(verbatim: " kg").font(Typography.caption).foregroundColor(Color.inkSecondary)
    }

    private var weightDetail: Text? {
        guard let latestWeight else { return nil }
        if let fat = latestBodyFat, calendar.isDate(fat.measuredAt, inSameDayAs: latestWeight.measuredAt) {
            return Text("glance.weight.detailFat \(shortDate(latestWeight.measuredAt)) \(fat.value.formatted(.number.precision(.fractionLength(1))))")
        }
        return Text(verbatim: shortDate(latestWeight.measuredAt))
    }

    /// "1/4개" (1회용 펜: 패키지 전체 중 남은 펜), "5/12회" (여러 회 쓰는 펜: 남은 회차). D21-1: 쓴 수가 아니라 남은 수를 전체와 함께
    private func pensValue(_ pens: PenStatus) -> Text {
        let remaining = pens.isSingleUse ? pens.remainingPens : pens.remainingDoses
        let total = pens.isSingleUse ? pens.penCount : pens.penCount * pens.dosesPerPen
        return Text(verbatim: "\(remaining)/\(total)")
            + Text(pens.isSingleUse ? "glance.unit.pens" : "unit.times").font(Typography.caption).foregroundColor(Color.inkSecondary)
    }

    /// "소진 예상 12. 7."
    private var pensDetail: Text? {
        exhaustionDate.map { Text("glance.exhaustion \(shortDate($0))") }
    }

    private var siteValue: Text {
        guard let lastSite else { return Text("glance.none") }
        return Text(verbatim: lastSite.site.localizedName)
    }

    // MARK: 줄

    /// 왼쪽 라벨, 오른쪽 값(크게)과 그 아래 작은 설명
    private func row(_ label: LocalizedStringKey, value: Text, detail: Text?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
                .fixedSize()
            Spacer(minLength: Spacing.s2)
            VStack(alignment: .trailing, spacing: 2) {
                value
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let detail {
                    detail
                        .font(Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: 그림

    /// 바디맵과 같은 실루엣(거울 보기). 지난 부위는 또렷하게, 그 전 부위는 오래될수록 흐리고 작게 (D21). 순서·추천 표시 없음
    private var figureView: some View {
        let scale = scale
        let size = CGSize(width: Self.designSize.width * scale, height: Self.designSize.height * scale)
        return ZStack(alignment: .topLeading) {
            BodySilhouette(figure: figure)
                .fill(LinearGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    BodySilhouette(figure: figure)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.40), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 0.8, lineJoin: .round)
                        )
                )
                .frame(width: size.width, height: size.height)
            // 오래된 것을 먼저 그려 지난 부위가 맨 위에 오게
            ForEach(Array(recentSites.prefix(Self.siteOpacities.count).enumerated().reversed()), id: \.offset) { rank, use in
                siteDot(use.site, rank: rank, scale: scale)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func siteDot(_ site: BodySite, rank: Int, scale: CGFloat) -> some View {
        let rect = BodyMapView.frame(for: site, figure: figure)
        let isLast = rank == 0
        let dotScale = scale * (isLast ? 1 : Self.olderSiteScale)
        let width = max(rect.width * dotScale, isLast ? 5 : 4)
        let height = max(rect.height * dotScale, isLast ? 6 : 5)
        return Capsule(style: .continuous)
            .fill(Color.accent.opacity(Self.siteOpacities[rank]))
            .shadow(color: Color.accent.opacity(isLast ? 0.7 : 0), radius: 4)
            .frame(width: width, height: height)
            // 가운데를 맞춰 작아지게
            .offset(x: rect.midX * scale - width / 2, y: rect.midY * scale - height / 2)
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day())
    }
}
