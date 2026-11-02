import SwiftData
import SwiftUI

/// D37 잠 흐름 (R29). 건강 앱 수면 기록을 최근 밤과 투약 후 며칠째별 평균으로 나란히 놓는다.
/// 원인을 판단하지 않는다. 숫자는 저장하지 않고 열 때마다 건강 앱에서 읽는다
struct SleepFlowView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.services) private var services
    @Query(sort: \Prescription.startDate) private var prescriptions: [Prescription]
    @State private var nights: [SleepNight]?
    @State private var questionDraft: QuestionDraft?

    private struct QuestionDraft: Identifiable {
        let id = UUID()
        let text: String
    }

    private var doseDates: [Date] {
        prescriptions.flatMap(\.doses).filter { !$0.isCancelled }.map(\.administeredAt)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                if let nights {
                    if nights.isEmpty {
                        Text("sleep.flow.empty")
                            .font(Typography.body)
                            .foregroundStyle(Color.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("sleep.flow.caption \(SleepRules.flowWeeks)")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        flowCard(SleepRules.flow(nights: nights, doseDates: doseDates, calendar: calendar))
                        recentCard(Array(nights.suffix(7).reversed()))
                        if let summary = SleepRules.summary(nights, calendar: calendar) {
                            GhostButton("sleep.flow.addQuestion") {
                                questionDraft = QuestionDraft(text: SleepFormat.questionText(summary))
                            }
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                }
                NoticeLine("sleep.flow.notice")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("sleep.flow.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $questionDraft) { draft in
            ClinicQuestionsSheet(draft: draft.text)
        }
    }

    private func load() async {
        // 화면을 여는 시각이 now 주입 지점
        let since = calendar.date(byAdding: .day, value: -7 * SleepRules.flowWeeks, to: .now) ?? .now
        _ = try? await services.healthKit.requestReadAuthorization()
        let segments = (try? await services.healthKit.sleepSegments(since: since)) ?? []
        nights = SleepRules.nights(from: segments, calendar: calendar)
    }

    // MARK: 투약 후 며칠째

    private func flowCard(_ flow: [SleepFlowDay]) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("sleep.flow.byDay")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                headerRow
                ForEach(flow) { day in
                    HStack {
                        Group {
                            if day.offset == 0 {
                                Text("sleep.flow.doseDay")
                            } else {
                                Text("sleep.flow.dayAfter \(day.offset)")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: day.averageAsleepMinutes.map(SleepFormat.duration) ?? "–")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(verbatim: day.averageAwakenings.map(SleepFormat.count) ?? "–")
                            .frame(width: 44, alignment: .trailing)
                        Text(verbatim: day.averageWakeMinute.map(SleepFormat.clock) ?? "–")
                            .frame(width: 52, alignment: .trailing)
                    }
                    .font(Typography.body)
                    .monospacedDigit()
                    .foregroundStyle(day.nights == 0 ? Color.inkTertiary : Color.ink)
                    .accessibilityElement(children: .combine)
                }
                Text("sleep.flow.byDay.footnote")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("sleep.flow.column.day").frame(maxWidth: .infinity, alignment: .leading)
            Text("sleep.flow.column.asleep").frame(maxWidth: .infinity, alignment: .trailing)
            Text("sleep.flow.column.awakenings").frame(width: 44, alignment: .trailing)
            Text("sleep.flow.column.wake").frame(width: 52, alignment: .trailing)
        }
        .font(Typography.caption)
        .foregroundStyle(Color.inkSecondary)
    }

    // MARK: 최근 밤

    private func recentCard(_ recent: [SleepNight]) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("sleep.flow.recent")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                ForEach(recent) { night in
                    SleepNightRow(night: night)
                }
            }
        }
    }
}

/// 하룻밤 한 줄: 날짜 · 23:40–4:50 · 5시간 10분 · 깨어남 2회
struct SleepNightRow: View {
    let night: SleepNight
    var showsDate = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
            if showsDate {
                Text(verbatim: night.day.formatted(.dateTime.month(.defaultDigits).day()))
                    .frame(width: 52, alignment: .leading)
                    .foregroundStyle(Color.inkSecondary)
            }
            Text(verbatim: "\(night.bedtime.formatted(date: .omitted, time: .shortened)) – \(night.wakeTime.formatted(date: .omitted, time: .shortened))")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: Spacing.s1)
            Text(verbatim: SleepFormat.duration(night.asleepMinutes))
            Text(verbatim: SleepFormat.awakenings(night.awakenings))
                .foregroundStyle(Color.inkSecondary)
        }
        .font(Typography.caption)
        .monospacedDigit()
        .foregroundStyle(Color.ink)
        .accessibilityElement(children: .combine)
    }
}

/// D37 기록 탭 하루 카드의 그날 잠 (그날 아침에 깬 밤). 건강 앱에 없으면 그리지 않는다
struct SleepDayRow: View {
    let day: Date
    @Environment(\.calendar) private var calendar
    @Environment(\.services) private var services
    @State private var night: SleepNight?

    var body: some View {
        VStack(spacing: 0) {
            if let night {
                BlueprintDivider()
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
                    Image(systemName: "bed.double")
                        .font(.caption)
                        .foregroundStyle(Color.accent)
                        .frame(width: 8)
                        .accessibilityHidden(true)
                    SleepNightRow(night: night, showsDate: false)
                }
                .padding(Spacing.cellPadding)
            }
        }
        .task(id: day) {
            let start = calendar.startOfDay(for: day)
            let since = calendar.date(byAdding: .hour, value: -18, to: start) ?? start
            let segments = (try? await services.healthKit.sleepSegments(since: since)) ?? []
            night = SleepRules.nights(from: segments, calendar: calendar).first { $0.day == start }
        }
    }
}

/// 잠 숫자 표기
enum SleepFormat {
    /// "6시간 40분"
    static func duration(_ minutes: Int) -> String {
        String(format: L10n.string("sleep.duration %lld %lld"), minutes / 60, minutes % 60)
    }

    /// "4:50" (24시간)
    static func clock(_ minuteOfDay: Int) -> String {
        String(format: "%d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }

    /// "1.5"
    static func count(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "깨어남 2회"
    static func awakenings(_ count: Int) -> String {
        String(format: L10n.string("sleep.awakenings %lld"), count)
    }

    /// 물어볼 것·리포트에 쓰는 사실 문장. 질문은 사용자가 덧붙인다
    static func summaryText(_ summary: SleepSummary) -> String {
        String(
            format: L10n.string("sleep.summary %lld %@ %@ %@"),
            summary.nights, duration(summary.averageAsleepMinutes), count(summary.averageAwakenings), clock(summary.averageWakeMinute)
        )
    }

    static func questionText(_ summary: SleepSummary) -> String {
        String(format: L10n.string("sleep.flow.question %lld %@"), SleepRules.flowWeeks, summaryText(summary))
    }
}

#Preview {
    NavigationStack {
        SleepFlowView()
    }
    .modelContainer(ModelContainer.previewWithSampleData)
    .preferredColorScheme(.dark)
}
