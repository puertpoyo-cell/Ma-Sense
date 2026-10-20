import Foundation
import SwiftData

// SwiftData 모델 → Rules 스냅샷 변환. Rules는 모델을 모른다.

extension Prescription {
    var snapshot: PrescriptionSnapshot {
        PrescriptionSnapshot(
            startDate: startDate,
            intervalDays: intervalDays,
            scheduledWeekday: scheduledWeekday,
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            dosesPerPen: dosesPerPen,
            totalDoses: totalDoses,
            nextClinicDate: nextClinicDate
        )
    }

    var doseSnapshots: [DoseSnapshot] {
        doses.map(\.snapshot)
    }
}

extension Dose {
    var snapshot: DoseSnapshot {
        DoseSnapshot(
            id: id,
            administeredAt: administeredAt,
            scheduledFor: scheduledFor,
            site: site,
            sequence: sequence,
            isCancelled: isCancelled
        )
    }
}

extension ConditionCheck {
    /// `dose`가 없는 체크는 스냅샷을 만들 수 없다
    var snapshot: ConditionCheckSnapshot? {
        guard let dose else { return nil }
        return ConditionCheckSnapshot(doseID: dose.id, window: window, checkedAt: checkedAt)
    }
}

extension UserSettings {
    var snapshot: SettingsSnapshot {
        SettingsSnapshot(
            reminderEnabled: reminderEnabled,
            eveningReminderHour: eveningReminderHour,
            conditionCheckEnabled: conditionCheckEnabled,
            clinicReminderDaysBefore: clinicReminderDaysBefore,
            exhaustionReminderDosesLeft: exhaustionReminderDosesLeft
        )
    }
}

extension WeightSample {
    var snapshot: WeightSampleSnapshot {
        WeightSampleSnapshot(measuredAt: measuredAt, kilograms: kilograms)
    }
}
