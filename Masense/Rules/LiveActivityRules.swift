import Foundation

/// D6 투약일 Live Activity를 보일지 (SCREENS.md Live Activity). 위젯 요약과 같은 판단을 쓴다.
/// 오늘이 예정일이고 이번 마디를 아직 기록하지 않았을 때만. 지난 예정일(D+1 이후)에는 띄우지 않는다
enum LiveActivityRules {
    /// 보일 때는 오늘 예정 일시, 아니면 nil (있던 활동은 끝낸다)
    static func doseDayScheduledDate(snapshot: WidgetSnapshot, now: Date, calendar: Calendar) -> Date? {
        guard snapshot.phase == .upcoming,
              let scheduled = snapshot.scheduledDate,
              calendar.isDate(scheduled, inSameDayAs: now)
        else { return nil }
        return scheduled
    }

    /// 다시 그릴 시각. 예정 시각 전이면 예정 시각(남은 시간 → "예정 시각이 지났습니다"),
    /// 지났으면 그날 끝(잠금화면에서 오래된 내용으로 흐리게)
    static func staleDate(for scheduled: Date, now: Date, calendar: Calendar) -> Date? {
        if now < scheduled { return scheduled }
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: scheduled))
    }
}
