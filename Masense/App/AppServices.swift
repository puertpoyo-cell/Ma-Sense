import SwiftData
import SwiftUI

/// 앱 전역 서비스 묶음 (DI). 실제 앱은 `live()`, 미리보기·테스트는 `fake()`.
final class AppServices {
    let notifications: NotificationScheduling
    let healthKit: HealthKitReading
    let store: StorePurchasing
    let widgets: WidgetPublishing
    let liveActivities: LiveActivityControlling
    let calendar: Calendar

    init(
        notifications: NotificationScheduling,
        healthKit: HealthKitReading,
        store: StorePurchasing,
        widgets: WidgetPublishing = FakeWidgetService(),
        liveActivities: LiveActivityControlling = FakeLiveActivityService(),
        calendar: Calendar = .current
    ) {
        self.notifications = notifications
        self.healthKit = healthKit
        self.store = store
        self.widgets = widgets
        self.liveActivities = liveActivities
        self.calendar = calendar
    }

    static func live(notifications: NotificationService = NotificationService()) -> AppServices {
        AppServices(notifications: notifications, healthKit: HealthKitService(), store: StoreService(), widgets: WidgetService(), liveActivities: LiveActivityService())
    }

    static func fake() -> AppServices {
        AppServices(notifications: FakeNotificationService(), healthKit: FakeHealthKitService(), store: FakeStoreService())
    }

    /// 기록·처방·설정이 바뀌었거나 앱이 앞으로 왔을 때: 알림을 전부 다시 등록하고(RULES.md R4)
    /// 위젯 요약을 다시 쓰고, 투약일이면 Live Activity를 띄우거나 기록 뒤 끝낸다 (D6)
    @MainActor
    func refreshReminders(context: ModelContext, now: Date = Date()) async {
        // D51: 위젯에서 눌러 둔 투약 기록을 먼저 저장소에 넣는다
        QuickLogService.drain(in: context, calendar: calendar)
        let snapshot = WidgetService.snapshot(context: context, now: now, calendar: calendar)
        widgets.publish(snapshot)
        // D32 (2026-11-01 사람 결정 "투약일 실시간 현황은 필요 없음, 알림 정도만"): Live Activity는 띄우지 않고, 떠 있던 것은 끈다
        if AppConfig.doseDayLiveActivityEnabled {
            let doseDay = LiveActivityRules.doseDayScheduledDate(snapshot: snapshot, now: now, calendar: calendar)
            await liveActivities.sync(scheduled: doseDay, staleDate: doseDay.flatMap { LiveActivityRules.staleDate(for: $0, now: now, calendar: calendar) })
        } else {
            await liveActivities.sync(scheduled: nil, staleDate: nil)
        }
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
