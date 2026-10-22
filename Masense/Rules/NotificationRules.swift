import Foundation

enum NotificationKind: String, CaseIterable {
    case doseDue, doseEvening, conditionH24, conditionH48, clinicSoon, prescriptionLow

    /// `Localizable.xcstrings` 키. 약 이름·용량·"주사" 단어 없음 (COMPLIANCE.md 3.3)
    var bodyKey: String {
        switch self {
        case .doseDue: return "notif.dose.due"
        case .doseEvening: return "notif.dose.evening"
        case .conditionH24: return "notif.condition.h24"
        case .conditionH48: return "notif.condition.h48"
        case .clinicSoon: return "notif.clinic.soon"
        case .prescriptionLow: return "notif.prescription.low"
        }
    }
}

/// 등록할 로컬 알림 1건. `id`는 결정적이라 재등록해도 중복이 없다.
struct PlannedNotification: Equatable, Identifiable {
    let id: String
    let kind: NotificationKind
    let fireDate: Date
    /// `prescriptionLow`의 남은 회차 n
    let argument: Int?

    init(id: String, kind: NotificationKind, fireDate: Date, argument: Int? = nil) {
        self.id = id
        self.kind = kind
        self.fireDate = fireDate
        self.argument = argument
    }
}

/// R4. 알림 스케줄. iOS 제한(64개) 때문에 앞으로 4주치만 만든다.
/// 서비스는 앱이 포그라운드로 올 때마다 전부 취소 후 이 결과를 재등록한다.
enum NotificationRules {
    static let horizonDays = 28
    static let clinicReminderHour = 9

    static func notificationPlan(
        p: PrescriptionSnapshot,
        settings: SettingsSnapshot,
        doses: [DoseSnapshot],
        checks: [ConditionCheckSnapshot],
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        guard let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now) else { return [] }
        let inRange = { (date: Date) in date > now && date <= horizon }
        var plan: [PlannedNotification] = []

        // 투약·저녁 리마인드·소진
        if settings.reminderEnabled {
            let cycles = CycleRules.cycles(for: p, doses: doses, now: now, until: horizon, calendar: calendar)
            let remaining = PrescriptionRules.remainingDoses(p: p, doses: doses)
            var lowAttached = false

            for cycle in cycles where CycleRules.doses(in: cycle, from: doses).isEmpty {
                if inRange(cycle.scheduledDate) {
                    plan.append(PlannedNotification(id: "dose.due.\(cycle.index)", kind: .doseDue, fireDate: cycle.scheduledDate))

                    // 소진 알림은 다음 투약 알림과 함께 1회
                    if !lowAttached, remaining > 0, remaining <= settings.exhaustionReminderDosesLeft {
                        plan.append(PlannedNotification(
                            id: "prescription.low.\(cycle.index)",
                            kind: .prescriptionLow,
                            fireDate: cycle.scheduledDate,
                            argument: remaining
                        ))
                        lowAttached = true
                    }
                }
                if p.scheduledHour < settings.eveningReminderHour,
                   let evening = calendar.date(
                       bySettingHour: settings.eveningReminderHour,
                       minute: 0,
                       second: 0,
                       of: cycle.scheduledDate
                   ),
                   inRange(evening) {
                    plan.append(PlannedNotification(id: "dose.evening.\(cycle.index)", kind: .doseEvening, fireDate: evening))
                }
            }
        }

        // 컨디션 24h·48h
        if settings.conditionCheckEnabled {
            for dose in doses where !dose.isCancelled {
                let answered = Set(checks.filter { $0.doseID == dose.id }.map(\.window))
                let h24 = dose.administeredAt.addingTimeInterval(24 * 3_600)
                let h48 = dose.administeredAt.addingTimeInterval(48 * 3_600)
                if !answered.contains(.h24), inRange(h24) {
                    plan.append(PlannedNotification(id: "condition.h24.\(dose.id.uuidString)", kind: .conditionH24, fireDate: h24))
                }
                if !answered.contains(.h48), inRange(h48) {
                    plan.append(PlannedNotification(id: "condition.h48.\(dose.id.uuidString)", kind: .conditionH48, fireDate: h48))
                }
            }
        }

        // 진료
        if let clinic = p.nextClinicDate,
           let day = calendar.date(byAdding: .day, value: -settings.clinicReminderDaysBefore, to: clinic),
           let fire = calendar.date(bySettingHour: clinicReminderHour, minute: 0, second: 0, of: day),
           inRange(fire) {
            plan.append(PlannedNotification(id: "clinic.soon", kind: .clinicSoon, fireDate: fire))
        }

        return plan.sorted { lhs, rhs in
            if lhs.fireDate != rhs.fireDate { return lhs.fireDate < rhs.fireDate }
            return lhs.id < rhs.id
        }
    }
}
