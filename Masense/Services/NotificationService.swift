import Foundation
import UserNotifications

/// 로컬 알림 등록. 테스트·미리보기에서는 `FakeNotificationService`를 주입한다.
protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    /// 대기 중인 알림을 전부 지우고 `plan`을 등록한다 (RULES.md R4: 포그라운드 진입마다)
    func replaceAll(with plan: [PlannedNotification]) async
    func pendingIdentifiers() async -> [String]
}

final class NotificationService: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func replaceAll(with plan: [PlannedNotification]) async {
        center.removeAllPendingNotificationRequests()
        for item in plan {
            try? await center.add(request(for: item))
        }
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    private func request(for item: PlannedNotification) -> UNNotificationRequest {
        // 잠금화면에 노출되므로 본문만, 약 이름·용량·"주사" 단어 없음 (COMPLIANCE.md 3.3)
        let content = UNMutableNotificationContent()
        content.body = Self.body(for: item)
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
    }

    static func body(for item: PlannedNotification) -> String {
        let format = String(localized: String.LocalizationValue(item.kind.bodyKey))
        if let argument = item.argument {
            return String(format: format, locale: .current, argument)
        }
        return format
    }
}

/// 테스트·미리보기용. 등록 결과를 메모리에 들고 있는다.
final class FakeNotificationService: NotificationScheduling {
    var granted = true
    var status: UNAuthorizationStatus = .notDetermined
    private(set) var pending: [PlannedNotification] = []
    private(set) var replaceCount = 0

    func requestAuthorization() async -> Bool {
        status = granted ? .authorized : .denied
        return granted
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func replaceAll(with plan: [PlannedNotification]) async {
        pending = plan
        replaceCount += 1
    }

    func pendingIdentifiers() async -> [String] { pending.map(\.id) }
}
