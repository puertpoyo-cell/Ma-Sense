import Foundation
import SwiftData

/// 저장된 데이터로 R4 알림 계획을 만들어 서비스에 등록한다.
/// 앱이 포그라운드로 올 때, 투약·컨디션·처방·설정이 바뀔 때 `refresh`를 부른다.
@MainActor
final class NotificationCoordinator {
    private let service: NotificationScheduling
    private let calendar: Calendar

    init(service: NotificationScheduling, calendar: Calendar = .current) {
        self.service = service
        self.calendar = calendar
    }

    /// `now`는 서비스 경계에서만 `Date()`를 기본값으로 쓴다 (CLAUDE.md 아키텍처)
    func refresh(context: ModelContext, now: Date = Date()) async {
        let plan = (try? Self.plan(context: context, now: now, calendar: calendar)) ?? []
        await service.replaceAll(with: plan)
    }

    static func plan(context: ModelContext, now: Date, calendar: Calendar) throws -> [PlannedNotification] {
        guard let prescription = try Prescription.active(in: context) else { return [] }
        let settings = try UserSettings.current(in: context)
        let checks = try ConditionCheck.all(in: context).compactMap(\.snapshot)
        return NotificationRules.notificationPlan(
            p: prescription.snapshot,
            settings: settings.snapshot,
            doses: prescription.doseSnapshots,
            checks: checks,
            now: now,
            calendar: calendar
        )
    }
}
