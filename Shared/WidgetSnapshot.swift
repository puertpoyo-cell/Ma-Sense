import Foundation

/// 앱과 위젯 확장이 함께 쓰는 App Group (`Config/*.entitlements`와 같은 값)
enum AppGroup {
    static let identifier = "group.com.puertpoyo.masense"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

/// 위젯이 읽는 투약 요약 (D6, SCREENS.md 위젯). 앱이 기록이 바뀔 때마다 App Group 컨테이너에 JSON으로 써 둔다.
/// 위젯은 SwiftData 저장소를 열지 않는다. 저장소 이전(migration)과 잠금을 앱 한 곳에서만 다루려고.
/// 이 파일은 앱과 위젯 확장 두 타깃에 들어간다 (`Shared/`). Foundation만 쓴다
struct WidgetSnapshot: Codable, Equatable {
    enum Phase: String, Codable {
        /// 처방 입력 전
        case noPrescription
        /// 이번 마디 기록 전. `scheduledDate`는 이번 마디 예정
        case upcoming
        /// 이번 마디 기록 완료. `scheduledDate`는 다음 마디 예정
        case done
        /// 처방 소진
        case exhausted
    }

    var phase: Phase
    var scheduledDate: Date?
    /// 마지막 투약 (취소 제외, 모든 처방)
    var lastDoseDate: Date?
    /// 마지막 투약 부위 표시명 (앱이 쓸 때의 언어). 부위 기록 없음이면 nil
    var lastSiteName: String?
    var remainingDoses: Int?
    var updatedAt: Date

    static let fileName = "WidgetSnapshot.json"
    /// 오늘 화면 + 투약 기록 (`AppRouter.route(for:)`와 같은 링크)
    static let logDoseURL = URL(string: "masense://log-dose")
    /// 마디는 예정일 이틀 전부터 (RULES.md R1 `CycleRules.leadDays`)
    static let cycleLeadDays = 2

    static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    static func read(from url: URL? = WidgetSnapshot.fileURL) -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func write(to url: URL? = WidgetSnapshot.fileURL) throws {
        guard let url else { return }
        try Self.encoder.encode(self).write(to: url, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// MARK: - 위젯 표시 (시각마다)

/// 위젯 한 시점의 카운트다운. 달력 날짜로 센다 (오늘 화면의 D-n과 같은 기준, 24시간 미만 D-Day 분 단위는 생략)
enum WidgetCountdown: Equatable {
    case noPrescription
    case exhausted
    /// 예정일까지 n일 (n ≥ 1)
    case daysLeft(Int, scheduled: Date)
    /// 오늘이 예정일, 예정 시각 전
    case today(scheduled: Date)
    /// 예정 시각이 지났고 기록 없음. 예정일 당일이면 0
    case overdue(daysPast: Int, scheduled: Date)
}

extension WidgetSnapshot {
    func countdown(at date: Date, calendar: Calendar) -> WidgetCountdown {
        switch phase {
        case .noPrescription: return .noPrescription
        case .exhausted: return .exhausted
        case .upcoming, .done:
            guard let scheduled = scheduledDate else { return phase == .done ? .exhausted : .noPrescription }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: scheduled)).day ?? 0
            if date >= scheduled {
                return .overdue(daysPast: max(-days, 0), scheduled: scheduled)
            }
            return days >= 1 ? .daysLeft(days, scheduled: scheduled) : .today(scheduled: scheduled)
        }
    }

    /// 이번 마디를 기록했고 다음 마디 구간(예정 이틀 전)이 아직 오지 않았을 때 "기록 완료"를 함께 보인다
    func showsDone(at date: Date, calendar: Calendar) -> Bool {
        guard phase == .done, let scheduled = scheduledDate,
              let nextStart = calendar.date(byAdding: .day, value: -Self.cycleLeadDays, to: scheduled)
        else { return false }
        return date < nextStart
    }

    /// 위젯 타임라인 시각: 지금, 앞으로 8일의 자정, 다음 마디 구간 시작, 예정 시각. 지난 시각은 뺀다
    func timelineDates(from now: Date, calendar: Calendar) -> [Date] {
        var dates: Set<Date> = [now]
        let today = calendar.startOfDay(for: now)
        for offset in 1...8 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: today) {
                dates.insert(midnight)
            }
        }
        if let scheduled = scheduledDate {
            dates.insert(scheduled)
            if let nextStart = calendar.date(byAdding: .day, value: -Self.cycleLeadDays, to: scheduled) {
                dates.insert(nextStart)
            }
        }
        return dates.filter { $0 >= now }.sorted()
    }
}
