import Foundation
import UserNotifications

/// 로컬 알림 등록. 테스트·미리보기에서는 `FakeNotificationService`를 주입한다.
protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    /// 대기 중인 알림을 전부 지우고 `plan`을 등록한다 (RULES.md R4: 포그라운드 진입마다).
    /// 사용자가 미룬 알림(`NotificationActions.snoozeIdentifier`)은 남긴다. 투약을 기록하면 `cancelSnooze()`
    func replaceAll(with plan: [PlannedNotification]) async
    func pendingIdentifiers() async -> [String]
    /// 한 건만 더한다 (알림의 "1시간 뒤 다시")
    func schedule(_ item: PlannedNotification) async
    func cancelSnooze() async
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
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0 != NotificationActions.snoozeIdentifier }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for item in plan {
            try? await center.add(request(for: item))
        }
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func schedule(_ item: PlannedNotification) async {
        try? await center.add(request(for: item))
    }

    func cancelSnooze() async {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationActions.snoozeIdentifier])
    }

    /// 알림을 길게 누르면 보이는 버튼 (D6, R4-1). 앱 시작 때 한 번 등록한다
    func registerCategories() {
        let logDose = UNNotificationAction(
            identifier: NotificationActions.logDose,
            title: String(localized: "notif.action.logDose"),
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: NotificationActions.snooze,
            title: String(localized: "notif.action.snooze"),
            options: []
        )
        let logCondition = UNNotificationAction(
            identifier: NotificationActions.logCondition,
            title: String(localized: "notif.action.logCondition"),
            options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(identifier: NotificationActions.doseCategory, actions: [logDose, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: NotificationActions.conditionCategory, actions: [logCondition], intentIdentifiers: []),
        ])
    }

    private func request(for item: PlannedNotification) -> UNNotificationRequest {
        // 잠금화면에 노출되므로 본문만, 약 이름·용량·"주사" 단어 없음 (COMPLIANCE.md 3.3)
        let content = UNMutableNotificationContent()
        content.body = Self.body(for: item)
        content.sound = .default
        content.userInfo = [Self.kindKey: item.kind.rawValue]
        if let category = NotificationActions.category(for: item.kind) {
            content.categoryIdentifier = category
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
    }

    /// 미루기에서 같은 문구를 다시 쓰려고 알림에 종류를 담는다
    static let kindKey = "kind"

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
        pending = plan + pending.filter { $0.id == NotificationActions.snoozeIdentifier }
        replaceCount += 1
    }

    func pendingIdentifiers() async -> [String] { pending.map(\.id) }

    func schedule(_ item: PlannedNotification) async {
        pending.removeAll { $0.id == item.id }
        pending.append(item)
    }

    func cancelSnooze() async {
        pending.removeAll { $0.id == NotificationActions.snoozeIdentifier }
    }
}

/// 알림 응답 (D6, R4-1). 앱 시작 때 `UNUserNotificationCenter.delegate`로 둔다 (delegate는 약한 참조라 앱이 붙잡는다)
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    private let router: AppRouter
    private let service: NotificationScheduling

    init(router: AppRouter, service: NotificationScheduling) {
        self.router = router
        self.service = service
    }

    /// 앱을 보고 있을 때도 배너로 보여 준다
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let action = response.actionIdentifier == UNNotificationDefaultActionIdentifier
            ? NotificationActions.defaultAction
            : response.actionIdentifier
        switch NotificationActions.response(action: action, category: content.categoryIdentifier) {
        case let .open(route)?:
            Task { @MainActor in
                router.open(route)
                completionHandler()
            }
        case .snooze?:
            let kind = (content.userInfo[NotificationService.kindKey] as? String).flatMap(NotificationKind.init(rawValue:)) ?? .doseDue
            Task {
                await service.schedule(NotificationActions.snoozed(kind: kind, now: Date()))
                completionHandler()
            }
        case nil:
            completionHandler()
        }
    }
}
