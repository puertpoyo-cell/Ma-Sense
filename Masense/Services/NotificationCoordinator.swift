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
        let prescription = try Prescription.active(in: context)
        let settings = try UserSettings.current(in: context)
        // D7 체중 기록 알림은 처방이 없어도 보낸다
        var plan = NotificationRules.weightReminders(
            settings: settings.snapshot,
            prescriptionWeekday: prescription?.scheduledWeekday,
            weights: try WeightSample.all(in: context).map(\.snapshot),
            now: now,
            calendar: calendar
        )
        // D47 마선생 알림 (할 일이 생긴 날에만, 하루 하나, 설정에서 끄기)
        let doses = prescription?.doseSnapshots ?? []
        let checks = try ConditionCheck.all(in: context).compactMap(\.snapshot)
        let openQuestions = (try? context.fetchCount(FetchDescriptor<ClinicQuestion>(predicate: #Predicate { $0.askedAt == nil }))) ?? 0
        let facts = CoachFactsRules.facts(
            prescription: prescription?.snapshot, doses: doses, checks: checks,
            openQuestions: openQuestions, recordDates: [], now: now, calendar: calendar
        )
        let allDoses = ((try? context.fetch(FetchDescriptor<Dose>())) ?? []).filter { !$0.isCancelled }.map(\.administeredAt)
        let records: [Date] = allDoses
            + checks.map(\.checkedAt)
            + ((try? WeightSample.all(in: context)) ?? []).map(\.measuredAt)
            + ((try? context.fetch(FetchDescriptor<ProteinEntry>())) ?? []).map(\.createdAt)
            + ((try? context.fetch(FetchDescriptor<StrengthSession>())) ?? []).map(\.startedAt)
        plan += NotificationRules.coachReminders(
            enabled: CoachNotificationSetting.isEnabled,
            nextClinicDate: prescription?.nextClinicDate,
            openQuestions: openQuestions,
            pensLastDose: facts.pensLastDose,
            lastRecord: records.max(),
            now: now,
            calendar: calendar
        )
        if let prescription {
            plan += NotificationRules.notificationPlan(
                p: prescription.snapshot,
                settings: settings.snapshot,
                doses: prescription.doseSnapshots,
                checks: try ConditionCheck.all(in: context).compactMap(\.snapshot),
                now: now,
                calendar: calendar
            )
        }
        return NotificationRules.sorted(plan)
    }
}

/// D47 마선생 알림 켜기·끄기 (기기 설정, 기본 켬 — 2026-11-09 사람 결정)
enum CoachNotificationSetting {
    static let key = "coach.notifications"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}
