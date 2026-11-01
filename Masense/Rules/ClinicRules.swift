import Foundation

/// 진료 예약·결과 흐름 (D28, 2026-11-01 사람 요청 "진료 탭 대폭 업데이트").
/// 다음 진료(날짜, 시각은 선택) → 진료 날이 지나면 결과 적기 → 결과를 적으면 다음 예약 넣기
enum ClinicRules {
    enum Appointment: Equatable {
        /// 예약이 없다
        case none
        /// 앞으로. `days` = 오늘부터 남은 날 (1 이상)
        case upcoming(date: Date, days: Int)
        /// 오늘 진료, 아직 결과 없음
        case today(date: Date)
        /// 진료 날이 지났는데 그날(또는 그 뒤) 진료 기록이 없다
        case needsResult(date: Date)
        /// 지난 진료의 결과를 적었다. 다음 예약을 넣을 차례
        case recorded(date: Date)
    }

    /// 다음 진료와 진료 기록으로 지금 보일 상태
    static func appointment(next: Date?, visitDates: [Date], now: Date, calendar: Calendar) -> Appointment {
        guard let next else { return .none }
        let day = calendar.startOfDay(for: next)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        if days > 0 { return .upcoming(date: next, days: days) }
        let recorded = visitDates.contains { calendar.startOfDay(for: $0) >= day }
        if recorded { return .recorded(date: next) }
        return days == 0 ? .today(date: next) : .needsResult(date: next)
    }

    /// 시각까지 정한 예약인지. 자정(0:00)은 날짜만 정한 것으로 본다
    static func hasTime(_ date: Date, calendar: Calendar) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) != 0 || (parts.minute ?? 0) != 0
    }

    /// 날짜와(있으면) 시각을 합친 예약 시각. 시각이 없으면 그날 0:00
    static func appointmentDate(day: Date, time: Date?, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        guard let time else { return start }
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: start) ?? start
    }

    /// 지금까지 받은 패키지 합계 (진료 기록·새 펜 받음 모두)
    static func totalPackages(_ packages: [Int]) -> Int {
        packages.filter { $0 > 0 }.reduce(0, +)
    }
}
