import Foundation

// `Rules/`는 SwiftData 모델을 직접 받지 않고 값 타입 스냅샷만 받는다 (CLAUDE.md 아키텍처).
// 모델 → 스냅샷 변환은 `Models/Snapshots+Models.swift`에 있다.

struct PrescriptionSnapshot: Equatable {
    let startDate: Date
    /// 1(일)~7(토), `Calendar` weekday
    let scheduledWeekday: Int
    let scheduledHour: Int
    let scheduledMinute: Int
    /// 펜당 회차. 회차 표시 "펜 m의 k번째"에 쓴다
    let dosesPerPen: Int
    /// `penCount * dosesPerPen`
    let totalDoses: Int
    let nextClinicDate: Date?
    /// 처방 종료일 (그날까지 유효). 활성 처방은 nil
    let endDate: Date?
    /// 사용자 메모. 처방 전환 표시에만 쓰고 해석하지 않는다
    let doseLabel: String?

    init(
        startDate: Date,
        scheduledWeekday: Int,
        scheduledHour: Int,
        scheduledMinute: Int = 0,
        dosesPerPen: Int = 4,
        totalDoses: Int,
        nextClinicDate: Date? = nil,
        endDate: Date? = nil,
        doseLabel: String? = nil
    ) {
        self.startDate = startDate
        self.scheduledWeekday = scheduledWeekday
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.dosesPerPen = dosesPerPen
        self.totalDoses = totalDoses
        self.nextClinicDate = nextClinicDate
        self.endDate = endDate
        self.doseLabel = doseLabel
    }
}

struct DoseSnapshot: Equatable, Identifiable {
    let id: UUID
    let administeredAt: Date
    let scheduledFor: Date
    let site: BodySite
    let sequence: Int
    let isCancelled: Bool
    /// 자유 메모. 기록 탭 메모 표시, 리포트 G 섹션
    let note: String?

    init(
        id: UUID = UUID(),
        administeredAt: Date,
        scheduledFor: Date,
        site: BodySite,
        sequence: Int,
        isCancelled: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.administeredAt = administeredAt
        self.scheduledFor = scheduledFor
        self.site = site
        self.sequence = sequence
        self.isCancelled = isCancelled
        self.note = note
    }
}

struct ConditionCheckSnapshot: Equatable {
    let doseID: UUID
    let window: ConditionWindow
    let checkedAt: Date
    let symptoms: [SymptomEntry]
    let appetite: AppetiteLevel
    let note: String?

    init(
        doseID: UUID,
        window: ConditionWindow,
        checkedAt: Date,
        symptoms: [SymptomEntry] = [],
        appetite: AppetiteLevel = .normal,
        note: String? = nil
    ) {
        self.doseID = doseID
        self.window = window
        self.checkedAt = checkedAt
        self.symptoms = symptoms
        self.appetite = appetite
        self.note = note
    }
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
    /// 리포트 D 섹션 출처 표기
    let source: WeightSource
    /// 제지방량 (M2, 리포트 F)
    let leanBodyMassKg: Double?

    init(measuredAt: Date, kilograms: Double, source: WeightSource = .manual, leanBodyMassKg: Double? = nil) {
        self.measuredAt = measuredAt
        self.kilograms = kilograms
        self.source = source
        self.leanBodyMassKg = leanBodyMassKg
    }
}

// MARK: M2

struct ProteinEntrySnapshot: Equatable {
    let date: Date
    let meal: MealSlot
    let foods: [ProteinFood]
    let estimatedGrams: Int
}

struct StrengthSessionSnapshot: Equatable {
    let startedAt: Date
    let durationMinutes: Int
    let kind: SessionKind
    let intensity: Intensity

    init(startedAt: Date, durationMinutes: Int, kind: SessionKind, intensity: Intensity = .moderate) {
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.kind = kind
        self.intensity = intensity
    }
}

struct HabitCheckSnapshot: Equatable {
    let date: Date
    let water: Bool
    let fiber: Bool
    let sleep: Bool
}
