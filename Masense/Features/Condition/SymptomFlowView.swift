import SwiftData
import SwiftUI

/// S12 증상 흐름 (R19, D9). 최근 8주 증상 기록을 증상별로 나란히 놓는다.
/// 강도는 사용자가 고른 그대로이고 색으로 판단하지 않는다. "물어볼 것에 넣기"는 사실 문장만 채워
/// 진료 때 물어볼 것(R15) 시트를 열고, 질문은 사용자가 이어 적는다
struct SymptomFlowView: View {
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Prescription> { $0.isActive }) private var activePrescriptions: [Prescription]
    @Query(sort: \ConditionCheck.checkedAt) private var checks: [ConditionCheck]
    @State private var questionDraft: QuestionDraft?

    private struct QuestionDraft: Identifiable {
        let id = UUID()
        let text: String
    }

    var body: some View {
        // 화면을 그리는 시각이 now 주입 지점
        let periods = activePrescriptions.first.map {
            SymptomFlowRules.recentPeriods(prescription: $0.snapshot, now: .now, calendar: calendar)
        } ?? []
        let flows = SymptomFlowRules.flows(periods: periods, checks: checks.compactMap(\.snapshot))
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                if flows.isEmpty {
                    Text("symptom.flow.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("symptom.flow.caption \(periods.count)")
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(flows) { flow in
                        card(flow, periods: periods)
                    }
                }
                NoticeLine("symptom.severe")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("symptom.flow.title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $questionDraft) { draft in
            ClinicQuestionsSheet(draft: draft.text)
        }
    }

    private func card(_ flow: SymptomFlow, periods: [DateInterval]) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text(verbatim: flow.symptom.localizedName)
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    SeverityStrip(severities: flow.severities)
                    if let first = periods.first {
                        HStack {
                            Text(first.start.formatted(.dateTime.month(.defaultDigits).day()))
                            Spacer()
                            Text("symptom.flow.thisWeek")
                        }
                        .font(Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkTertiary)
                    }
                    Text(summaryText(flow, periodCount: periods.count))
                        .font(Typography.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(flow.symptom.localizedName), \(summaryText(flow, periodCount: periods.count))"))

                GhostButton("symptom.flow.addQuestion") {
                    questionDraft = QuestionDraft(text: questionText(flow, periodCount: periods.count))
                }
            }
        }
    }

    /// "8주 중 3주 기록 · 가장 강하게 기록한 정도 보통"
    private func summaryText(_ flow: SymptomFlow, periodCount: Int) -> String {
        String(
            format: L10n.string("symptom.flow.summary %lld %lld %@"),
            periodCount, flow.recordedPeriods, SymptomChip.severityLabel(flow.maxSeverity)
        )
    }

    /// 물어볼 것에 채울 사실 문장. 질문은 사용자가 덧붙인다
    private func questionText(_ flow: SymptomFlow, periodCount: Int) -> String {
        String(
            format: L10n.string("symptom.flow.question %@ %lld %lld %@"),
            flow.symptom.localizedName, periodCount, flow.recordedPeriods, SymptomChip.severityLabel(flow.maxSeverity)
        )
    }
}

/// 주마다 막대 하나, 칸 세 개(약함·보통·심함)를 아래부터 기록한 강도만큼 채운다. 기록 없는 주는 빈 칸.
/// 강도는 높이로만 보이고 색은 한 가지 (DESIGN_SYSTEM.md 5.4 판단 색 금지)
struct SeverityStrip: View {
    let severities: [Int]

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.s2) {
            ForEach(Array(severities.enumerated()), id: \.offset) { _, severity in
                VStack(spacing: 2) {
                    ForEach([3, 2, 1], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(level <= severity ? Color.accent : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(level <= severity ? Color.accent : Color.gridHairline, lineWidth: 1)
                            )
                            .frame(height: 10)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        SymptomFlowView()
    }
    .modelContainer(ModelContainer.previewWithSampleData)
    .preferredColorScheme(.dark)
}
