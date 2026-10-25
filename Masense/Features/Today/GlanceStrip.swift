import SwiftUI

/// 카운트다운 카드 안 "한눈에" 줄 (D14, D15에서 카드 하나로 합침).
/// 왼쪽 작은 바디맵(지난 부위만 빛남), 오른쪽 세 줄: 체중 · 남은 펜(회차) · 지난 부위. 숫자만, 판단·다음 부위 추천 없음 (R6)
struct GlanceStrip: View {
    let figure: BodyFigure
    let latestWeight: WeightSampleSnapshot?
    let latestBodyFat: MetricReading?
    let pens: PenStatus?
    let usedDoses: Int?
    let totalDoses: Int?
    let exhaustionDate: Date?
    let lastSite: SiteUse?
    var onOpenWeight: () -> Void = {}

    @Environment(\.calendar) private var calendar

    /// 바디맵 설계 좌표(240×420)를 줄인 비율
    private static let scale: CGFloat = 0.27

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

    private func pensValue(_ pens: PenStatus) -> Text {
        Text(verbatim: String(pens.isSingleUse ? pens.remainingPens : pens.remainingDoses))
            + Text(pens.isSingleUse ? "glance.unit.pens" : "unit.times").font(Typography.caption).foregroundColor(Color.inkSecondary)
    }

    /// "5/12회 · 소진 예상 12. 7."
    private var pensDetail: Text? {
        let sequence = (usedDoses.flatMap { used in totalDoses.map { Text("glance.sequence \(used) \($0)") } })
        let exhaustion = exhaustionDate.map { Text("glance.exhaustion \(shortDate($0))") }
        switch (sequence, exhaustion) {
        case let (s?, e?): return s + Text(verbatim: " · ") + e
        case let (s?, nil): return s
        case let (nil, e?): return e
        default: return nil
        }
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

    /// 바디맵과 같은 실루엣(거울 보기)을 작게. 지난 부위만 accent로 빛낸다
    private var figureView: some View {
        let size = CGSize(width: 240 * Self.scale, height: 420 * Self.scale)
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
            if let lastSite {
                let rect = BodyMapView.frame(for: lastSite.site, figure: figure)
                Capsule(style: .continuous)
                    .fill(Color.accent)
                    .shadow(color: Color.accent.opacity(0.7), radius: 4)
                    .frame(width: max(rect.width * Self.scale, 4), height: max(rect.height * Self.scale, 5))
                    .offset(x: rect.minX * Self.scale, y: rect.minY * Self.scale)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day())
    }
}
