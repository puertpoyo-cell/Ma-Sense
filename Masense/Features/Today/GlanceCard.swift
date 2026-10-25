import SwiftUI

/// 오늘 1-0a "한눈에" 카드 (D14, 2026-10-25 사람 요청). 카운트다운 바로 아래.
/// 왼쪽 작은 바디맵 그림에 지난 부위만 표시하고, 오른쪽에 체중·남은 펜·지난 부위를 숫자로.
/// 자세한 내용은 아래 체중·남은 펜 카드에 있다. 판단·추천 없음 (다음 부위를 권하지 않는다, R6)
struct GlanceCard: View {
    let figure: BodyFigure
    let latestWeight: WeightSampleSnapshot?
    let latestBodyFat: MetricReading?
    let pens: PenStatus?
    let exhaustionDate: Date?
    let lastSite: SiteUse?
    var onOpenWeight: () -> Void = {}

    @Environment(\.calendar) private var calendar

    /// 바디맵 설계 좌표(240×420)를 줄인 비율
    private static let scale: CGFloat = 0.36

    var body: some View {
        FrostCard {
            HStack(alignment: .center, spacing: Spacing.s4) {
                figureView
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Button(action: onOpenWeight) {
                        row("glance.weight") {
                            if let latestWeight {
                                DimensionValue(
                                    latestWeight.kilograms.formatted(.number.precision(.fractionLength(1))),
                                    unit: "unit.kg",
                                    valueFont: Typography.title.monospacedDigit(),
                                    unitFont: Typography.caption
                                )
                            } else {
                                noneText
                            }
                        } detail: {
                            if let latestWeight {
                                if let fat = latestBodyFat, calendar.isDate(fat.measuredAt, inSameDayAs: latestWeight.measuredAt) {
                                    Text("glance.weight.detailFat \(shortDate(latestWeight.measuredAt)) \(fat.value.formatted(.number.precision(.fractionLength(1))))")
                                } else {
                                    Text(verbatim: shortDate(latestWeight.measuredAt))
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if let pens {
                        row(pens.isSingleUse ? "glance.pens" : "glance.doses") {
                            DimensionValue(
                                String(pens.isSingleUse ? pens.remainingPens : pens.remainingDoses),
                                unit: pens.isSingleUse ? "glance.unit.pens" : "unit.times",
                                valueFont: Typography.title.monospacedDigit(),
                                unitFont: Typography.caption
                            )
                        } detail: {
                            if let exhaustionDate {
                                Text("glance.exhaustion \(shortDate(exhaustionDate))")
                            }
                        }
                    }

                    row("glance.lastSite") {
                        if let lastSite {
                            Text(verbatim: lastSite.site.localizedName)
                                .font(Typography.body.weight(.semibold))
                                .foregroundStyle(Color.ink)
                        } else {
                            noneText
                        }
                    } detail: {
                        if let lastSite {
                            Text(verbatim: shortDate(lastSite.date))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
                    .frame(width: max(rect.width * Self.scale, 5), height: max(rect.height * Self.scale, 6))
                    .offset(x: rect.minX * Self.scale, y: rect.minY * Self.scale)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    // MARK: 행

    private func row<Value: View, Detail: View>(
        _ label: LocalizedStringKey,
        @ViewBuilder value: () -> Value,
        @ViewBuilder detail: () -> Detail
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            value()
            detail()
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Color.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var noneText: some View {
        Text("glance.none")
            .font(Typography.body)
            .foregroundStyle(Color.inkSecondary)
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day())
    }
}
