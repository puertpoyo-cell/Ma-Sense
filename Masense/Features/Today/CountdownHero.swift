import SwiftUI

/// 1-1 하이브리드 카운트다운 (DESIGN_SYSTEM.md 5.2).
/// 좌측 메인 셀(D-n / D-Day + 시간·분 / D+n / 기록 완료 / 소진) + 우측 보조 셀(예정 시간, 회차) + 아래 버튼 행.
struct CountdownHero: View {
    let countdown: TodayModel.Countdown
    let scheduleDate: Date?
    let usedDoses: Int?
    let totalDoses: Int?
    var onLogDose: () -> Void = {}
    var onEnterPrescription: () -> Void = {}
    /// D15: 카드 안 "한눈에" 줄 (체중·남은 펜·지난 부위). 있으면 회차 셀은 이 줄로 옮긴다
    var glance: AnyView?

    @ScaledMetric(relativeTo: .largeTitle) private var displaySize: CGFloat = 56

    var body: some View {
        FrostCard(padding: 0) {
            VStack(spacing: 0) {
                switch countdown {
                case .noPrescription:
                    emptyState
                case .exhausted:
                    BlueprintCell("today.cell.prescription", valueAlignment: .leading) {
                        Text("today.countdown.exhausted")
                            .font(Typography.title)
                            .foregroundStyle(Color.ink)
                    }
                    actionRow
                default:
                    BlueprintSplit {
                        mainCell
                    } trailing: {
                        VStack(spacing: 0) {
                            scheduleCell
                            if glance == nil {
                                BlueprintDivider(crosshair: .leading)
                                sequenceCell
                            }
                        }
                    }
                    if let glance {
                        BlueprintDivider()
                        glance
                    }
                    actionRow
                }
            }
        }
    }

    // MARK: 좌측 메인 셀

    @ViewBuilder
    private var mainCell: some View {
        switch countdown {
        case let .daysLeft(_, days, _):
            BlueprintCell("today.cell.next") {
                VStack(alignment: .trailing, spacing: Spacing.s1) {
                    displayText("today.countdown.dDay \(days)")
                        .accessibilityLabel(Text("today.countdown.dDay.a11y \(days)"))
                    caption("today.countdown.untilNext")
                }
            }
        case let .hoursLeft(_, hours, minutes):
            BlueprintCell("today.cell.next") {
                VStack(alignment: .trailing, spacing: Spacing.s1) {
                    displayText("today.countdown.dayOf")
                    caption("today.countdown.untilNext")
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                        DimensionValue(String(hours), unit: "unit.hours")
                        DimensionValue(String(minutes), unit: "unit.minutes")
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    caption("today.countdown.remaining")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("today.countdown.hoursLeft.a11y \(hours) \(minutes)"))
            }
        case let .overdue(_, daysPast):
            BlueprintCell("today.cell.next") {
                VStack(alignment: .trailing, spacing: Spacing.s1) {
                    // 색 변화 없이 숫자와 문구로만 (질책 없음)
                    if daysPast == 0 {
                        displayText("today.countdown.dayOf")
                    } else {
                        displayText("today.countdown.dPlus \(daysPast)")
                    }
                    caption("today.countdown.overdue")
                }
            }
        case let .done(_, nextDays):
            BlueprintCell("today.cell.thisCycle") {
                VStack(alignment: .trailing, spacing: Spacing.s1) {
                    Text("today.countdown.recorded")
                        .font(Typography.title)
                        .foregroundStyle(Color.ink)
                    if let nextDays {
                        caption("today.countdown.nextDDay \(nextDays)")
                    }
                }
            }
        case .noPrescription, .exhausted:
            EmptyView()
        }
    }

    private func displayText(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: displaySize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
            .foregroundStyle(Color.ink)
    }

    private func caption(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(Typography.caption)
            .foregroundStyle(Color.inkSecondary)
            .multilineTextAlignment(.trailing)
    }

    // MARK: 우측 보조 셀

    private var scheduleCell: some View {
        BlueprintCell("today.cell.schedule") {
            if let scheduleDate {
                // "금요일 오후 8:00". 요일과 시각을 한 포맷으로 묶으면 한국어에서 "(금요일)"처럼 괄호가 붙는다
                Text(verbatim: scheduleDate.formatted(.dateTime.weekday(.wide)) + " " + scheduleDate.formatted(date: .omitted, time: .shortened))
                    .font(Typography.label)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var sequenceCell: some View {
        BlueprintCell("today.cell.sequence") {
            if let usedDoses, let totalDoses {
                DimensionValue(String(usedDoses), unit: "unit.ofTotal \(totalDoses)")
                    .accessibilityLabel(Text("today.sequence.a11y \(usedDoses) \(totalDoses)"))
            }
        }
    }

    // MARK: 버튼 행

    @ViewBuilder
    private var actionRow: some View {
        switch countdown {
        case .hoursLeft, .overdue:
            BlueprintDivider()
            PrimaryButton("action.logDose", action: onLogDose)
                .padding(Spacing.cellPadding)
        case let .daysLeft(_, _, canLogEarly) where canLogEarly:
            // 예정일 이틀 전부터는 그 마디로 본다 (R1). 미리 맞은 경우의 입력 경로
            BlueprintDivider()
            GhostButton("action.logDose", action: onLogDose)
                .padding(Spacing.cellPadding)
        case .exhausted:
            BlueprintDivider()
            PrimaryButton("today.enterPrescription", action: onEnterPrescription)
                .padding(Spacing.cellPadding)
        default:
            EmptyView()
        }
    }

    // MARK: 빈 상태

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("today.empty.noPrescription")
                .font(Typography.body)
                .lineSpacing(Typography.bodyLineSpacing)
                .foregroundStyle(Color.ink)
            PrimaryButton("today.enterPrescription", action: onEnterPrescription)
        }
        .padding(Spacing.cardPadding)
    }
}

#Preview {
    let now = Date.now
    return ScrollView {
        VStack(spacing: Spacing.cardGap) {
            CountdownHero(countdown: .daysLeft(scheduled: now.addingTimeInterval(3 * 86_400), days: 3, canLogEarly: false),
                          scheduleDate: now.addingTimeInterval(3 * 86_400), usedDoses: 6, totalDoses: 12)
            CountdownHero(countdown: .hoursLeft(scheduled: now.addingTimeInterval(67_320), hours: 18, minutes: 42),
                          scheduleDate: now.addingTimeInterval(67_320), usedDoses: 6, totalDoses: 12)
            CountdownHero(countdown: .overdue(scheduled: now.addingTimeInterval(-86_400), daysPast: 1),
                          scheduleDate: now.addingTimeInterval(-86_400), usedDoses: 6, totalDoses: 12)
            CountdownHero(countdown: .done(next: now.addingTimeInterval(6 * 86_400), nextDays: 6),
                          scheduleDate: now.addingTimeInterval(6 * 86_400), usedDoses: 7, totalDoses: 12)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }
    .midnightBackground()
    .preferredColorScheme(.dark)
}
