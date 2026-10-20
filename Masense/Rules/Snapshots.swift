import Foundation

// `Rules/`는 SwiftData 모델을 직접 받지 않고 값 타입 스냅샷만 받는다 (CLAUDE.md 아키텍처).
// 모델 → 스냅샷 변환은 `Models/Snapshots+Models.swift`에 있다.

struct PrescriptionSnapshot: Equatable {
    let startDate: Date
    /// 투약 간격(일). 3 미만이면 마디 구간을 만들 수 없어 규칙이 빈 결과를 돌려준다
    let intervalDays: Int
    /// 1(일)~7(토), `Calendar` weekday
    let scheduledWeekday: Int
    let scheduledHour: Int
    let scheduledMinute: Int
    /// `penCount * dosesPerPen`
    let totalDoses: Int
    let nextClinicDate: Date?

    init(
        startDate: Date,
        intervalDays: Int = 7,
        scheduledWeekday: Int,
        scheduledHour: Int,
        scheduledMinute: Int = 0,
        totalDoses: Int,
        nextClinicDate: Date? = nil
    ) {
        self.startDate = startDate
        self.intervalDays = intervalDays
        self.scheduledWeekday = scheduledWeekday
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.totalDoses = totalDoses
        self.nextClinicDate = nextClinicDate
    }
}

struct DoseSnapshot: Equatable, Identifiable {
    let id: UUID
    let administeredAt: Date
    let scheduledFor: Date
    let site: BodySite
    let sequence: Int
    let isCancelled: Bool

    init(
        id: UUID = UUID(),
        administeredAt: Date,
        scheduledFor: Date,
        site: BodySite,
        sequence: Int,
        isCancelled: Bool = false
    ) {
        self.id = id
        self.administeredAt = administeredAt
        self.scheduledFor = scheduledFor
        self.site = site
        self.sequence = sequence
        self.isCancelled = isCancelled
    }
}

struct ConditionCheckSnapshot: Equatable {
    let doseID: UUID
    let window: ConditionWindow
    let checkedAt: Date
}

struct SettingsSnapshot: Equatable {
    let reminderEnabled: Bool
    let eveningReminderHour: Int
    let conditionCheckEnabled: Bool
    let clinicReminderDaysBefore: Int
    let exhaustionReminderDosesLeft: Int

    init(
        reminderEnabled: Bool = true,
        eveningReminderHour: Int = 20,
        conditionCheckEnabled: Bool = true,
        clinicReminderDaysBefore: Int = 1,
        exhaustionReminderDosesLeft: Int = 2
    ) {
        self.reminderEnabled = reminderEnabled
        self.eveningReminderHour = eveningReminderHour
        self.conditionCheckEnabled = conditionCheckEnabled
        self.clinicReminderDaysBefore = clinicReminderDaysBefore
        self.exhaustionReminderDosesLeft = exhaustionReminderDosesLeft
    }
}

struct WeightSampleSnapshot: Equatable {
    let measuredAt: Date
    let kilograms: Double
}
