import ActivityKit
import SwiftUI
import WidgetKit

/// 투약일 Live Activity (D6, SCREENS.md Live Activity). 잠금화면과 Dynamic Island에 오늘 예정 시각까지 남은 시간.
/// 누르면 오늘 탭 + 투약 기록. 약 이름·"주사" 단어 없음, 판단 없음
struct DoseDayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseDayAttributes.self) { context in
            DoseDayLockScreenView(scheduled: context.state.scheduledDate, isStale: context.isStale)
                .activityBackgroundTint(WidgetPalette.midnight)
                .activitySystemActionForegroundColor(WidgetPalette.ink)
                .widgetURL(WidgetSnapshot.logDoseURL)
        } dynamicIsland: { context in
            let scheduled = context.state.scheduledDate
            let isStale = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("activity.title", systemImage: "calendar")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WidgetPalette.inkSecondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(scheduled, style: .time)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DoseDayRemaining(scheduled: scheduled, isStale: isStale)
                        .font(.title3.weight(.semibold))
                }
            } compactLeading: {
                Image(systemName: "calendar")
            } compactTrailing: {
                Text(scheduled, style: .time)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "calendar")
            }
            .widgetURL(WidgetSnapshot.logDoseURL)
        }
    }
}

/// "오늘 투약일" / 남은 시간 또는 "예정 시각이 지났습니다" / "예정 오후 8:00 · 눌러서 기록"
struct DoseDayLockScreenView: View {
    let scheduled: Date
    let isStale: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("activity.title")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WidgetPalette.inkSecondary)
                DoseDayRemaining(scheduled: scheduled, isStale: isStale)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(WidgetPalette.ink)
                Text("activity.scheduled \(scheduled.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(WidgetPalette.inkSecondary)
            }
            Spacer(minLength: 0)
            Text("activity.action")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetPalette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(Capsule().stroke(WidgetPalette.hairline, lineWidth: 1))
        }
        .padding(16)
    }
}

/// 예정 시각 전에는 줄어드는 시간, 지나면 사실 한 줄.
/// Live Activity는 그려 둔 화면을 보이므로 예정 시각을 stale 시각으로 두어(`LiveActivityRules.staleDate`) 그때 다시 그리게 한다
struct DoseDayRemaining: View {
    let scheduled: Date
    let isStale: Bool

    var body: some View {
        // 그리는 시각이 now 주입 지점
        if !isStale, Date.now < scheduled {
            Text(timerInterval: Date.now...scheduled, countsDown: true)
                .monospacedDigit()
        } else {
            Text("activity.overdue")
        }
    }
}

#Preview("잠금화면", as: .content, using: DoseDayAttributes()) {
    DoseDayLiveActivity()
} contentStates: {
    DoseDayAttributes.ContentState(scheduledDate: .now.addingTimeInterval(3 * 3_600))
}
