import SwiftUI

/// 주간 정리 한 장의 줄들 (R16, D8). 숫자만, 평가·비교 없음. 오늘 카드와 기록 탭 목록이 함께 쓴다
struct WeeklySummaryRows: View {
    let summary: WeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            if summary.isEmpty {
                Text("weekly.empty")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
            } else {
                row("weekly.row.dose") { Text("weekly.value.times \(summary.doseCount)") }
                row("weekly.row.condition") { Text("weekly.value.times \(summary.conditionCheckCount)") }
                if !summary.topSymptoms.isEmpty {
                    Text("weekly.symptoms \(symptomText)")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                row("weekly.row.weight") {
                    if let change = summary.weightChangeText {
                        Text("weekly.value.weightChange \(summary.weightCount) \(change)")
                    } else {
                        Text("weekly.value.times \(summary.weightCount)")
                    }
                }
                row("weekly.row.protein") {
                    if let met = summary.proteinMetDays {
                        Text("weekly.value.proteinMet \(summary.proteinDays) \(met)")
                    } else {
                        Text("weekly.value.days \(summary.proteinDays)")
                    }
                }
                row("weekly.row.exercise") {
                    Text("weekly.value.exercise \(summary.strengthCount) \(summary.lightActivityCount)")
                }
            }
        }
    }

    private var symptomText: String {
        summary.topSymptoms
            .map { String(format: L10n.string("weekly.symptomItem %@ %lld"), $0.symptom.localizedName, $0.count) }
            .joined(separator: ", ")
    }

    private func row<Value: View>(_ label: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: Spacing.s3)
            value()
                .font(Typography.label)
                .monospacedDigit()
                .foregroundStyle(Color.ink)
        }
    }
}

/// 기간 "10. 22. – 10. 28." (끝은 구간 마지막 날)
struct WeeklySummaryPeriodText: View {
    let period: DateInterval
    var calendar: Calendar = .current

    var body: some View {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: period.end) ?? period.end
        Text("weekly.period \(period.start.formatted(.dateTime.month(.defaultDigits).day())) \(lastDay.formatted(.dateTime.month(.defaultDigits).day()))")
            .font(Typography.caption)
            .monospacedDigit()
            .foregroundStyle(Color.inkSecondary)
    }
}

/// 오늘 1-1c "지난 마디 정리" 카드 (SCREENS.md, D8). 닫으면 그 구간은 다시 보이지 않는다
struct WeeklySummaryCard: View {
    let summary: WeeklySummary
    var onShowAll: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("weekly.title")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    WeeklySummaryPeriodText(period: summary.period)
                }
                WeeklySummaryRows(summary: summary)
                AdaptiveStack(spacing: Spacing.s2) {
                    GhostButton("weekly.list.open", action: onShowAll)
                    GhostButton("weekly.dismiss", action: onDismiss)
                }
            }
        }
    }
}
