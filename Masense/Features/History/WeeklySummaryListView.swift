import SwiftData
import SwiftUI

/// 주간 정리 목록 (R16, D8). 기록 탭과 오늘 카드의 "지난 정리 보기"에서 연다. 최근 구간부터 최대 12개, 숫자만
struct WeeklySummaryListView: View {
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Prescription> { $0.isActive }) private var activePrescriptions: [Prescription]
    @Query(sort: \Dose.administeredAt) private var doses: [Dose]
    @Query(sort: \ConditionCheck.checkedAt) private var checks: [ConditionCheck]
    @Query(sort: \WeightSample.measuredAt) private var weights: [WeightSample]
    @Query(sort: \ProteinEntry.date) private var proteins: [ProteinEntry]
    @Query(sort: \StrengthSession.startedAt) private var sessions: [StrengthSession]
    @Query private var settingsList: [UserSettings]

    var body: some View {
        // 화면을 그리는 시각이 now 주입 지점
        let summaries = makeSummaries(now: .now)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                if summaries.isEmpty {
                    Text("weekly.list.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                }
                ForEach(summaries) { summary in
                    FrostCard {
                        VStack(alignment: .leading, spacing: Spacing.s3) {
                            WeeklySummaryPeriodText(period: summary.period, calendar: calendar)
                            WeeklySummaryRows(summary: summary)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("weekly.list.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeSummaries(now: Date) -> [WeeklySummary] {
        guard let prescription = activePrescriptions.first else { return [] }
        let doseSnapshots = doses.map(\.snapshot)
        let checkSnapshots = checks.compactMap(\.snapshot)
        let weightSnapshots = weights.map(\.snapshot)
        let proteinSnapshots = proteins.map(\.snapshot)
        let sessionSnapshots = sessions.map(\.snapshot)
        return WeeklySummaryRules.finishedPeriods(prescription: prescription.snapshot, now: now, calendar: calendar).map { period in
            WeeklySummaryRules.summary(
                period: period,
                doses: doseSnapshots,
                checks: checkSnapshots,
                weights: weightSnapshots,
                proteins: proteinSnapshots,
                sessions: sessionSnapshots,
                proteinTarget: settingsList.first?.proteinTargetGrams,
                calendar: calendar
            )
        }
    }
}
