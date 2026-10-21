import SwiftData
import SwiftUI

/// 앱 전역 서비스 묶음 (DI). 실제 앱은 `live()`, 미리보기·테스트는 `fake()`.
final class AppServices {
    let notifications: NotificationScheduling
    let healthKit: HealthKitReading
    let store: StorePurchasing
    let calendar: Calendar

    init(
        notifications: NotificationScheduling,
        healthKit: HealthKitReading,
        store: StorePurchasing,
        calendar: Calendar = .current
    ) {
        self.notifications = notifications
        self.healthKit = healthKit
        self.store = store
        self.calendar = calendar
    }

    static func live() -> AppServices {
        AppServices(notifications: NotificationService(), healthKit: HealthKitService(), store: StoreService())
    }

    static func fake() -> AppServices {
        AppServices(notifications: FakeNotificationService(), healthKit: FakeHealthKitService(), store: FakeStoreService())
    }

    /// 저장된 데이터로 알림을 전부 다시 등록한다 (RULES.md R4)
    @MainActor
    func refreshNotifications(context: ModelContext, now: Date = Date()) async {
        await NotificationCoordinator(service: notifications, calendar: calendar).refresh(context: context, now: now)
    }
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices.fake()
}

private struct RestartOnboardingKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var services: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }

    /// 전체 삭제 후 온보딩으로 돌아간다. RootView가 채운다
    var restartOnboarding: () -> Void {
        get { self[RestartOnboardingKey.self] }
        set { self[RestartOnboardingKey.self] = newValue }
    }
}
