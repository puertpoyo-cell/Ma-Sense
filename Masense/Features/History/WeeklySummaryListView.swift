import SwiftData
import SwiftUI

/// S11 지난 정리 (R16 D8, R18 D9). 기록 탭과 오늘 카드의 "지난 정리 보기"에서 연다.
/// 주(최근 12구간)와 패키지(4회씩) 두 묶음, 숫자만
struct WeeklySummaryListView: View {
    enum Segment: String, CaseIterable, Hashable {
        case weeks, packages
    }

    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Prescription> { $0.isActive }) private var activePrescriptions: [Prescription]
    @Query(sort: \Dose.administeredAt) private var doses: [Dose]
    @Query(sort: \ConditionCheck.checkedAt) private var checks: [ConditionCheck]
    @Query(sort: \WeightSample.measuredAt) private var weights: [WeightSample]
    @Query(sort: \ProteinEntry.date) private var proteins: [ProteinEntry]
    @Query(sort: \StrengthSession.startedAt) private var sessions: [StrengthSession]
    @Query private var settingsList: [UserSettings]
    @State private var segment: Segment

    init(initialSegment: Segment = .weeks) {
        _segment = State(initialValue: initialSegment)
    }

    private var isSingleUsePen: Bool { (activePrescriptions.first?.dosesPerPen ?? 1) == 1 }

    var body: some View {
        // 화면을 그리는 시각이 now 주입 지점
        let now = Date.now
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                Picker("summary.segment", selection: $segment) {
                    Text("summary.segment.weeks").tag(Segment.weeks)
                    Text(isSingleUsePen ? "summary.segment.packages" : "summary.segment.doses").tag(Segment.packages)
                }
                .pickerStyle(.segmented)

                switch segment {
                case .weeks: weekCards(now: now)
                case .packages: packageCards(now: now)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("weekly.list.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func weekCards(now: Date) -> some View {
        let summaries = makeWeekSummaries(now: now)
        if summaries.isEmpty {
            emptyText("weekly.list.empty")
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

    @ViewBuilder
    private func packageCards(now: Date) -> some View {
        let summaries = makePackageSummaries(now: now)
        if summaries.isEmpty {
            emptyText(isSingleUsePen ? "package.list.empty" : "package.list.empty.doses")
        }
        ForEach(summaries) { summary in
            FrostCard {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    HStack(alignment: .firstTextBaseline) {
                        PackageSummaryTitle(package: summary.package, isSingleUsePen: isSingleUsePen)
                            .font(Typography.label)
                            .foregroundStyle(Color.ink)
                        Spacer()
                        WeeklySummaryPeriodText(period: summary.package.period, calendar: calendar)
                    }
                    WeeklySummaryRows(summary: summary.summary)
                }
            }
        }
    }

    private func emptyText(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typography.body)
            .foregroundStyle(Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func makeWeekSummaries(now: Date) -> [WeeklySummary] {
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

    /// 패키지는 지금 처방의 기록만으로 센다
    private func makePackageSummaries(now: Date) -> [PackageSummary] {
        guard let prescription = activePrescriptions.first else { return [] }
        let doseSnapshots = prescription.doseSnapshots
        let checkSnapshots = checks.compactMap(\.snapshot)
        let weightSnapshots = weights.map(\.snapshot)
        let proteinSnapshots = proteins.map(\.snapshot)
        let sessionSnapshots = sessions.map(\.snapshot)
        return PackageSummaryRules.finishedPackages(doses: doseSnapshots, now: now, calendar: calendar).map { package in
            PackageSummaryRules.summary(
                package: package,
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
