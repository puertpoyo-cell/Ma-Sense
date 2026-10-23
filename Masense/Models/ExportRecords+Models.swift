import Foundation
import SwiftData

// SwiftData 모델 ↔ 내보내기 레코드 변환 (EXPORT_FORMAT.md). 형식 정의는 Rules/ExportCodec.swift.
// rawValue 문자열은 그대로 옮긴다. 모르는 값도 저장해 두고, 읽을 때 모델의 기본값 규칙이 처리한다 (DATA_MODEL.md).

extension UserSettings {
    var exportRecord: ExportDocument.SettingsRecord {
        ExportDocument.SettingsRecord(
            hasAcceptedRoleNotice: hasAcceptedRoleNotice,
            hasConfirmedAdult: hasConfirmedAdult,
            reminderEnabled: reminderEnabled,
            eveningReminderHour: eveningReminderHour,
            conditionCheckEnabled: conditionCheckEnabled,
            clinicReminderDaysBefore: clinicReminderDaysBefore,
            exhaustionReminderDosesLeft: exhaustionReminderDosesLeft,
            proteinTargetGrams: proteinTargetGrams,
            bodyWeightForGuideKg: bodyWeightForGuideKg,
            reportTheme: reportTheme,
            reportDefaultPeriod: reportDefaultPeriod,
            heightCm: heightCm
        )
    }

    /// 교체 가져오기. 기기·계정에 종속인 `healthKitAuthorized`, `hasPurchasedPro`는 그대로 두고,
    /// 이 기기에서 이미 마친 온보딩 확인은 되돌리지 않는다
    func apply(_ record: ExportDocument.SettingsRecord) {
        hasAcceptedRoleNotice = hasAcceptedRoleNotice || record.hasAcceptedRoleNotice
        hasConfirmedAdult = hasConfirmedAdult || record.hasConfirmedAdult
        reminderEnabled = record.reminderEnabled
        eveningReminderHour = record.eveningReminderHour
        conditionCheckEnabled = record.conditionCheckEnabled
        clinicReminderDaysBefore = record.clinicReminderDaysBefore
        exhaustionReminderDosesLeft = record.exhaustionReminderDosesLeft
        proteinTargetGrams = record.proteinTargetGrams
        bodyWeightForGuideKg = record.bodyWeightForGuideKg
        reportTheme = record.reportTheme
        reportDefaultPeriod = record.reportDefaultPeriod
        heightCm = record.heightCm
    }
}

extension Prescription {
    var exportRecord: ExportDocument.PrescriptionRecord {
        ExportDocument.PrescriptionRecord(
            id: id,
            startDate: startDate,
            endDate: endDate,
            penCount: penCount,
            dosesPerPen: dosesPerPen,
            intervalDays: intervalDays,
            scheduledWeekday: scheduledWeekday,
            scheduledHour: scheduledHour,
            scheduledMinute: scheduledMinute,
            nextClinicDate: nextClinicDate,
            doseLabel: doseLabel,
            isActive: isActive,
            createdAt: createdAt
        )
    }

    convenience init(record: ExportDocument.PrescriptionRecord) {
        self.init(
            id: record.id,
            startDate: record.startDate,
            penCount: record.penCount,
            dosesPerPen: record.dosesPerPen,
            intervalDays: record.intervalDays,
            scheduledWeekday: record.scheduledWeekday,
            scheduledHour: record.scheduledHour,
            scheduledMinute: record.scheduledMinute,
            endDate: record.endDate,
            nextClinicDate: record.nextClinicDate,
            doseLabel: record.doseLabel,
            isActive: record.isActive,
            createdAt: record.createdAt
        )
    }

    var span: PrescriptionSpan {
        PrescriptionSpan(id: id, startDate: startDate, endDate: endDate, isActive: isActive)
    }
}

extension Dose {
    var exportRecord: ExportDocument.DoseRecord {
        ExportDocument.DoseRecord(
            id: id,
            prescriptionId: prescription?.id,
            administeredAt: administeredAt,
            scheduledFor: scheduledFor,
            site: siteRaw,
            sequence: sequence,
            note: note,
            isCancelled: isCancelled,
            createdAt: createdAt
        )
    }

    /// 처방 관계는 넣은 뒤 서비스가 잇는다
    convenience init(record: ExportDocument.DoseRecord) {
        self.init(
            id: record.id,
            administeredAt: record.administeredAt,
            scheduledFor: record.scheduledFor,
            site: nil,
            sequence: record.sequence,
            note: record.note,
            isCancelled: record.isCancelled,
            createdAt: record.createdAt
        )
        siteRaw = record.site
    }
}

extension ConditionCheck {
    var exportRecord: ExportDocument.ConditionCheckRecord {
        ExportDocument.ConditionCheckRecord(
            id: id,
            doseId: dose?.id,
            checkedAt: checkedAt,
            window: windowRaw,
            symptoms: symptoms.map { ExportDocument.SymptomRecord(symptom: $0.symptom.rawValue, severity: $0.severity) },
            appetite: appetiteRaw,
            note: note,
            createdAt: createdAt
        )
    }

    /// 투약 관계는 넣은 뒤 서비스가 잇는다. 모르는 증상은 담을 수 없어 뺀다 (심각도는 0~3으로 맞춘다)
    convenience init(record: ExportDocument.ConditionCheckRecord) {
        self.init(
            id: record.id,
            checkedAt: record.checkedAt,
            window: .h24,
            symptoms: record.symptoms.compactMap { symptom in
                Symptom(rawValue: symptom.symptom).map { SymptomEntry(symptom: $0, severity: symptom.severity) }
            },
            note: record.note,
            createdAt: record.createdAt
        )
        windowRaw = record.window
        appetiteRaw = record.appetite
    }
}

extension WeightSample {
    var exportRecord: ExportDocument.WeightSampleRecord {
        ExportDocument.WeightSampleRecord(
            id: id,
            measuredAt: measuredAt,
            kilograms: kilograms,
            source: sourceRaw,
            healthKitUUID: healthKitUUID,
            leanBodyMassKg: leanBodyMassKg,
            createdAt: createdAt
        )
    }

    convenience init(record: ExportDocument.WeightSampleRecord) {
        self.init(
            id: record.id,
            measuredAt: record.measuredAt,
            kilograms: record.kilograms,
            source: .manual,
            healthKitUUID: record.healthKitUUID,
            leanBodyMassKg: record.leanBodyMassKg,
            createdAt: record.createdAt
        )
        sourceRaw = record.source
    }
}

extension ProteinEntry {
    var exportRecord: ExportDocument.ProteinEntryRecord {
        ExportDocument.ProteinEntryRecord(
            id: id,
            date: date,
            meal: mealRaw,
            foods: foodsRaw,
            estimatedGrams: estimatedGrams,
            createdAt: createdAt
        )
    }

    convenience init(record: ExportDocument.ProteinEntryRecord) {
        self.init(
            id: record.id,
            date: record.date,
            meal: .breakfast,
            foods: [],
            estimatedGrams: record.estimatedGrams,
            createdAt: record.createdAt
        )
        mealRaw = record.meal
        foodsRaw = record.foods
    }
}

extension StrengthSession {
    var exportRecord: ExportDocument.StrengthSessionRecord {
        ExportDocument.StrengthSessionRecord(
            id: id,
            startedAt: startedAt,
            durationMinutes: durationMinutes,
            kind: kindRaw,
            intensity: intensityRaw,
            source: sourceRaw,
            healthKitUUID: healthKitUUID,
            note: note,
            createdAt: createdAt
        )
    }

    convenience init(record: ExportDocument.StrengthSessionRecord) {
        self.init(
            id: record.id,
            startedAt: record.startedAt,
            durationMinutes: record.durationMinutes,
            kind: .strength,
            healthKitUUID: record.healthKitUUID,
            note: record.note,
            createdAt: record.createdAt
        )
        kindRaw = record.kind
        intensityRaw = record.intensity
        sourceRaw = record.source
    }
}

extension HabitCheck {
    var exportRecord: ExportDocument.HabitCheckRecord {
        ExportDocument.HabitCheckRecord(
            id: id,
            date: date,
            water: water,
            fiber: fiber,
            sleep: sleep,
            createdAt: createdAt
        )
    }

    convenience init(record: ExportDocument.HabitCheckRecord) {
        self.init(
            id: record.id,
            date: record.date,
            water: record.water,
            fiber: record.fiber,
            sleep: record.sleep,
            createdAt: record.createdAt
        )
    }
}
