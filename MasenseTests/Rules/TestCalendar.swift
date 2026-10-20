import Foundation

/// 규칙 테스트용 고정 달력. 한국(DST 없음), 그레고리력.
enum TestCalendar {
    static let seoul: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        seoul.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
