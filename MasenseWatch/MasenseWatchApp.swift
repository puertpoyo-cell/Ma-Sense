import SwiftData
import SwiftUI
import UserNotifications
import WatchKit

/// D50 Apple Watch 앱 (0.7, 2026-11-09 사람 결정 "워치 앱도 같이 진행, iCloud 기반, 가벼운 알림 및 마선생 대화").
/// iPhone과 같은 iCloud(CloudKit 비공개 DB)로 처방·투약·컨디션만 주고받는다. 건강 앱 데이터는 다루지 않는다 (D49).
/// 알림은 iPhone이 보낸 것이 워치에 그대로 오고, 워치에서 누르면 이 앱이 투약 기록으로 연다.
@main
struct MasenseWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate
    private let container = WatchStore.make()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        .modelContainer(container)
    }
}

/// 워치 저장소: 처방·투약·컨디션만, iPhone과 같은 iCloud 컨테이너. 실패하면 이 워치에만
enum WatchStore {
    static let models: [any PersistentModel.Type] = [Prescription.self, Dose.self, ConditionCheck.self]

    static func make() -> ModelContainer {
        let schema = Schema(models)
        let cloud = ModelConfiguration("MasenseWatch", schema: schema, cloudKitDatabase: .private(AppConfig.cloudKitContainer))
        if let container = try? ModelContainer(for: schema, configurations: cloud) { return container }
        let local = ModelConfiguration("MasenseWatchLocal", schema: schema, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: local) { return container }
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("워치 저장소를 열 수 없습니다: \(error)")
        }
    }
}

/// 알림에서 들어온 곳
@Observable
final class WatchRouter {
    static let shared = WatchRouter()
    var opensDoseLog = false
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// 워치에 떠 있는 동안 온 알림도 짧게 보인다
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// 투약 알림(본문·"기록하기")을 누르면 투약 기록으로
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let category = response.notification.request.content.categoryIdentifier
        let action = response.actionIdentifier == UNNotificationDefaultActionIdentifier ? NotificationActions.defaultAction : response.actionIdentifier
        if case .open(.logDose)? = NotificationActions.response(action: action, category: category) {
            await MainActor.run { WatchRouter.shared.opensDoseLog = true }
        }
    }
}
