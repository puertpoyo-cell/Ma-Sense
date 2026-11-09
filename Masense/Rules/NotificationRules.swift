import Foundation

enum NotificationKind: String, CaseIterable {
    case doseDue, doseEvening, conditionH24, conditionH48, clinicSoon, prescriptionLow
    /// D7 주 1회 체중 기록
    case weightDue
    /// D47 마선생 알림: 내일 진료인데 물어볼 것이 비어 있다
    case coachClinicEve
    /// D47 마선생 알림: 남은 펜으로는 오늘이 마지막 투약 (다음 진료 전에 떨어짐)
    case coachPensShort
    /// D47 마선생 알림: 기록이 n일째 비어 있다
    case coachRecordGap

    /// 할 일이 생긴 날에만 오는 마선생 알림 (설정에서 따로 끄고 켠다)
    var isCoach: Bool {
        switch self {
        case .coachClinicEve, .coachPensShort, .coachRecordGap: return true
        default: return false
        }
    }

    /// `Localizable.xcstrings` 키. 약 이름·용량·"주사" 단어 없음 (COMPLIANCE.md 3.3)
    var bodyKey: String {
        switch self {
        case .doseDue: return "notif.dose.due"
        case .doseEvening: return "notif.dose.evening"
        case .conditionH24: return "notif.condition.h24"
        case .conditionH48: return "notif.condition.h48"
        case .clinicSoon: return "notif.clinic.soon"
        case .prescriptionLow: return "notif.prescription.low"
        case .weightDue: return "notif.weight.due"
        case .coachClinicEve: return "notif.coach.clinicEve"
        case .coachPensShort: return "notif.coach.pensShort"
        case .coachRecordGap: return "notif.coach.recordGap"
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
    /// D28 당일 진료 알림: 예약 시각이 있으면 이만큼 앞서
    static let sameDayClinicLeadHours: Double = 2

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
        // D28: 당일 알림이고 예약 시각을 정했으면 2시간 전, 아니면 그날(며칠 전) 오전 9시
        if let clinic = p.nextClinicDate,
           let day = calendar.date(byAdding: .day, value: -settings.clinicReminderDaysBefore, to: clinic),
           let morning = calendar.date(bySettingHour: clinicReminderHour, minute: 0, second: 0, of: day) {
            let fire = settings.clinicReminderDaysBefore == 0 && ClinicRules.hasTime(clinic, calendar: calendar)
                ? clinic.addingTimeInterval(-sameDayClinicLeadHours * 3_600)
                : morning
            if inRange(fire) {
                plan.append(PlannedNotification(id: "clinic.soon", kind: .clinicSoon, fireDate: fire))
            }
        }

        return sorted(plan)
    }

    /// 시각 순, 같으면 id 순
    static func sorted(_ plan: [PlannedNotification]) -> [PlannedNotification] {
        plan.sorted { lhs, rhs in
            if lhs.fireDate != rhs.fireDate { return lhs.fireDate < rhs.fireDate }
            return lhs.id < rhs.id
        }
    }

    // MARK: D7 체중 기록 알림

    /// 체중 알림 요일을 정하지 않았고 처방도 없을 때 (월요일)
    static let defaultWeightWeekday = 2

    /// R4-2. 주 1회, 정한 요일(없으면 투약 요일, 그것도 없으면 월요일)·시각. 앞으로 4주치.
    /// 오늘 이미 체중을 기록했으면 오늘 알림은 만들지 않는다. 처방이 없어도 보낸다 (체중은 처방과 따로 기록)
    static func weightReminders(
        settings: SettingsSnapshot,
        prescriptionWeekday: Int?,
        weights: [WeightSampleSnapshot],
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        guard settings.weightReminderEnabled,
              let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now)
        else { return [] }
        let weekday = settings.weightReminderWeekday ?? prescriptionWeekday ?? defaultWeightWeekday
        guard (1...7).contains(weekday) else { return [] }
        let recordedToday = weights.contains { calendar.isDate($0.measuredAt, inSameDayAs: now) }

        let today = calendar.startOfDay(for: now)
        let delta = (weekday - calendar.component(.weekday, from: today) + 7) % 7
        var plan: [PlannedNotification] = []
        var offset = delta
        while let day = calendar.date(byAdding: .day, value: offset, to: today),
              let fire = calendar.date(bySettingHour: settings.weightReminderHour, minute: settings.weightReminderMinute, second: 0, of: day),
              fire <= horizon {
            let isToday = calendar.isDate(day, inSameDayAs: now)
            if fire > now, !(isToday && recordedToday) {
                let stamp = calendar.dateComponents([.year, .month, .day], from: day)
                let id = String(format: "weight.due.%04d%02d%02d", stamp.year ?? 0, stamp.month ?? 0, stamp.day ?? 0)
                plan.append(PlannedNotification(id: id, kind: .weightDue, fireDate: fire))
            }
            offset += 7
        }
        return plan
    }

    // MARK: D47 마선생 알림 (2026-11-09 사람 결정 "기본 켬")

    /// 저녁 알림 시각
    static let coachEveningHour = 20
    /// 펜 알림 시각 (마지막 투약일 낮)
    static let coachNoonHour = 12
    static let coachNoonMinute = 30
    /// 기록이 빈 지 며칠째에 알리는지, 그 뒤로는 이 간격
    static let recordGapFirstDays = 3
    static let recordGapRepeatDays = 7

    /// 할 일이 생긴 날에만, 하루 하나. 같은 날이면 펜 > 진료 > 기록 빔. 밤 10시~아침 8시에는 없다 (시각 고정).
    /// `lastRecord`는 투약·컨디션·체중·단백질·운동·습관 기록 중 가장 최근 시각
    static func coachReminders(
        enabled: Bool,
        nextClinicDate: Date?,
        openQuestions: Int,
        pensLastDose: Date?,
        lastRecord: Date?,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        guard enabled, let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now) else { return [] }
        let inRange = { (date: Date) in date > now && date <= horizon }
        var candidates: [(priority: Int, item: PlannedNotification)] = []

        if let last = pensLastDose,
           let fire = calendar.date(bySettingHour: coachNoonHour, minute: coachNoonMinute, second: 0, of: last), inRange(fire) {
            candidates.append((0, PlannedNotification(id: "coach.pensShort", kind: .coachPensShort, fireDate: fire)))
        }
        if let clinic = nextClinicDate, openQuestions == 0,
           let eve = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: clinic)),
           let fire = calendar.date(bySettingHour: coachEveningHour, minute: 0, second: 0, of: eve), inRange(fire) {
            candidates.append((1, PlannedNotification(id: "coach.clinicEve", kind: .coachClinicEve, fireDate: fire)))
        }
        if let last = lastRecord {
            let lastDay = calendar.startOfDay(for: last)
            var days = recordGapFirstDays
            while let day = calendar.date(byAdding: .day, value: days, to: lastDay),
                  let fire = calendar.date(bySettingHour: coachEveningHour, minute: 0, second: 0, of: day),
                  fire <= horizon {
                if fire > now {
                    candidates.append((2, PlannedNotification(id: "coach.recordGap.\(days)", kind: .coachRecordGap, fireDate: fire, argument: days)))
                }
                days += recordGapRepeatDays
            }
        }

        // 하루 하나
        var byDay: [Date: (priority: Int, item: PlannedNotification)] = [:]
        for candidate in candidates {
            let day = calendar.startOfDay(for: candidate.item.fireDate)
            if let existing = byDay[day], existing.priority <= candidate.priority { continue }
            byDay[day] = candidate
        }
        return sorted(byDay.values.map(\.item))
    }
}
