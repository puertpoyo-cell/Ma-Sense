import Foundation

/// 투약 시각 30분 단위 (D25, 2026-10-31 사람 결정 "투약 시점 30분 단위 관리, 기본은 현재 시간 기준 최근 30분 단위").
/// 투약 기록·예정 시각은 :00·:30에만 놓인다. 기본값은 지금 시각을 내림한 가장 최근 30분
enum DoseTimeRules {
    static let stepMinutes = 30

    /// 가장 최근(같거나 이전) 30분 경계. 8:47 → 8:30, 9:00 → 9:00, 초는 버림
    static func roundedDown(_ date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        var floored = parts
        floored.minute = ((parts.minute ?? 0) / stepMinutes) * stepMinutes
        floored.second = 0
        return calendar.date(from: floored) ?? date
    }

    /// 투약 기록 시트를 열 때의 시각. 누락 마디에서 열면 그 예정일, 아니면 지금. 둘 다 내림하고 미래는 지금의 내림으로
    static func initialTime(initialDate: Date?, now: Date, calendar: Calendar) -> Date {
        let latest = roundedDown(now, calendar: calendar)
        guard let initialDate else { return latest }
        return min(roundedDown(initialDate, calendar: calendar), latest)
    }

    /// 30분 앞뒤로 옮긴 시각. 미래(`latest` 이후)로는 가지 않는다
    static func shifted(_ date: Date, steps: Int, latest: Date, calendar: Calendar) -> Date {
        let moved = calendar.date(byAdding: .minute, value: steps * stepMinutes, to: roundedDown(date, calendar: calendar)) ?? date
        return min(moved, roundedDown(latest, calendar: calendar))
    }
}
