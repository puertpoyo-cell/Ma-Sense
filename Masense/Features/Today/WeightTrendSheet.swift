import SwiftData
import SwiftUI

/// S10 체중 추이 (D7). 오늘 체중 카드에서 연다. 측정값 점 + 주 평균 선, 투약일 눈금, 시작 대비 변화 숫자.
/// 목표선·판단 색 없음 (COMPLIANCE.md 2.1-3). BMI는 키가 있을 때 숫자만 (R14)
struct WeightTrendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Query(sort: \WeightSample.measuredAt) private var weights: [WeightSample]
    @Query(sort: \Dose.administeredAt) private var doses: [Dose]
    @Query private var settingsList: [UserSettings]
    @State private var range: WeightTrendRange = .weeks12
    @State private var showsEntry = false
    @State private var showsToast = false

    var body: some View {
        // 시트를 그리는 시각이 now 주입 지점
        let now = Date.now
        let trend = WeightRules.trend(samples: weights.map(\.snapshot), range: range, now: now, calendar: calendar)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    Picker("weight.trend.range", selection: $range) {
                        ForEach(WeightTrendRange.allCases, id: \.self) { item in
                            Text(LocalizedStringKey("weight.trend.range." + item.rawValue)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    FrostCard(padding: 0) {
                        VStack(spacing: 0) {
                            summary(trend)
                            BlueprintDivider()
                            chart(trend, now: now)
                        }
                    }

                    GhostButton("weight.manualEntry") { showsEntry = true }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
            }
            .background(Color.midnightElevated)
            .navigationTitle("weight.trend.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showsEntry) {
                WeightEntrySheet { showsToast = true }
            }
            .recordedToast(isPresented: $showsToast)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    // MARK: 시작 대비 | 처음 → 마지막

    private func summary(_ trend: WeightTrend) -> some View {
        BlueprintSplit {
            BlueprintCell("weight.trend.change") {
                if let change = trend.changeText {
                    DimensionValue(change, unit: "unit.kg")
                } else {
                    Text(verbatim: "—")
                        .font(Typography.label)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        } trailing: {
            BlueprintCell("weight.trend.firstLast") {
                VStack(alignment: .trailing, spacing: Spacing.s1) {
                    if let first = trend.first, let last = trend.last {
                        Text("weight.trend.range.value \(ReportBuilder.kilograms(first.kilograms)) \(ReportBuilder.kilograms(last.kilograms))")
                            .font(Typography.label)
                            .monospacedDigit()
                            .foregroundStyle(Color.ink)
                        Text("weight.trend.dates \(first.day.formatted(.dateTime.month(.defaultDigits).day())) \(last.day.formatted(.dateTime.month(.defaultDigits).day()))")
                            .font(Typography.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color.inkSecondary)
                        // R14: 키가 있을 때만 숫자로
                        if let height = settingsList.first?.heightCm,
                           let startBMI = WeightRules.bmi(kilograms: first.kilograms, heightCm: height),
                           let endBMI = WeightRules.bmi(kilograms: last.kilograms, heightCm: height) {
                            Text("weight.trend.bmi \(ReportBuilder.kilograms(startBMI)) \(ReportBuilder.kilograms(endBMI))")
                                .font(Typography.caption)
                                .monospacedDigit()
                                .foregroundStyle(Color.inkSecondary)
                        }
                    } else {
                        Text(verbatim: "—")
                            .font(Typography.label)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
    }

    // MARK: 그래프

    @ViewBuilder
    private func chart(_ trend: WeightTrend, now: Date) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            if trend.daily.isEmpty {
                Text("weight.trend.empty")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                WeekChart(
                    points: trend.weeks,
                    tickDates: WeightRules.doseTicks(doses: doses.map(\.snapshot), series: trend.weeks, now: now),
                    dailyPoints: trend.daily,
                    accessibilityKey: "weight.trend.a11y"
                )
                .frame(height: 240)
            }
            Text("weight.trend.footnote")
                .font(Typography.caption)
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(Spacing.cellPadding)
    }
}

#Preview {
    Color.midnight
        .sheet(isPresented: .constant(true)) {
            WeightTrendSheet()
        }
        .modelContainer(ModelContainer.previewWithSampleData)
}
