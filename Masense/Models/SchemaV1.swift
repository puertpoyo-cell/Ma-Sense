import Foundation
import SwiftData

/// 출시 스키마 1.0.0 (DATA_MODEL.md "스키마 버전"). 2026-10-22 출시 전 재정리: CloudKit 호환 규칙(B)과 처방 endDate(C)를 담아
/// 이전 개발용 V1~V3 이력을 접었다. 스키마를 바꿀 때는 바뀌는 모델의 고정 사본을 이 버전에 두고
/// 다음 버전과 `MasenseMigrationPlan`의 단계를 더한다. CloudKit 규칙 5에 따라 변경은 필드·모델 추가만.
/// V2(D5)에서 `UserSettings.heightCm`이 더해져 `UserSettings`만 고정 사본을 둔다.
/// V3(D6)는 `ClinicQuestion` 모델만 더해 기존 모델은 V2와 같다 (고정 사본 없음).
/// V4(D7)에서 `UserSettings`에 체중 알림 필드가 더해져 V2·V3는 `SchemaV2.UserSettings` 고정 사본을 쓴다.
/// V5(D11)에서 `WeightSample`에 체지방률이 더해져 V1~V4는 `SchemaV1.WeightSample` 고정 사본을 쓴다.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Prescription.self,
            Dose.self,
            ConditionCheck.self,
            SchemaV1.WeightSample.self,
            SchemaV1.UserSettings.self,
            ProteinEntry.self,
            StrengthSession.self,
            HabitCheck.self,
        ]
    }

    /// 1.0.0의 `UserSettings` 고정 사본 (V1 저장소를 열고 V2로 옮길 때만 쓴다)
    @Model
    final class UserSettings {
        var id: UUID = UUID()
        var hasAcceptedRoleNotice: Bool = false
        var hasConfirmedAdult: Bool = false
        var reminderEnabled: Bool = true
        var eveningReminderHour: Int = 20
        var conditionCheckEnabled: Bool = true
        var clinicReminderDaysBefore: Int = 1
        var exhaustionReminderDosesLeft: Int = 2
        var proteinTargetGrams: Int?
        var bodyWeightForGuideKg: Double?
        var healthKitAuthorized: Bool = false
        var hasPurchasedPro: Bool = false
        var reportTheme: String = "midnight"
        var reportDefaultPeriod: String?
        var createdAt: Date = Date.now

        init() {}
    }

    /// 1.0.0~1.3.0의 `WeightSample` 고정 사본 (체지방률 없음). V1~V4 저장소를 열고 V5로 옮길 때만 쓴다
    @Model
    final class WeightSample {
        var id: UUID = UUID()
        var measuredAt: Date = Date.now
        var kilograms: Double = 0
        var sourceRaw: String = "manual"
        var healthKitUUID: UUID?
        var leanBodyMassKg: Double?
        var createdAt: Date = Date.now

        init() {}
    }
}

/// D5 (2026-10-22 사람 결정): `UserSettings.heightCm` 추가. 옵셔널 필드 추가라 경량 이전
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [
            Prescription.self,
            Dose.self,
            ConditionCheck.self,
            SchemaV1.WeightSample.self,
            SchemaV2.UserSettings.self,
            ProteinEntry.self,
            StrengthSession.self,
            HabitCheck.self,
        ]
    }

    /// 1.1.0·1.2.0의 `UserSettings` 고정 사본 (heightCm까지, 체중 알림 필드 없음). V2·V3 저장소를 열고 V4로 옮길 때만 쓴다
    @Model
    final class UserSettings {
        var id: UUID = UUID()
        var hasAcceptedRoleNotice: Bool = false
        var hasConfirmedAdult: Bool = false
        var reminderEnabled: Bool = true
        var eveningReminderHour: Int = 20
        var conditionCheckEnabled: Bool = true
        var clinicReminderDaysBefore: Int = 1
        var exhaustionReminderDosesLeft: Int = 2
        var proteinTargetGrams: Int?
        var bodyWeightForGuideKg: Double?
        var heightCm: Double?
        var healthKitAuthorized: Bool = false
        var hasPurchasedPro: Bool = false
        var reportTheme: String = "midnight"
        var reportDefaultPeriod: String?
        var createdAt: Date = Date.now

        init() {}
    }
}

/// D6 (2026-10-23 사람 결정): 진료 때 물어볼 것 `ClinicQuestion` 모델 추가. 관계 없는 모델 추가라 경량 이전
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 2, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV2.models + [ClinicQuestion.self]
    }
}

/// D7 (2026-10-23 사람 결정): `UserSettings`에 주 1회 체중 기록 알림 필드 추가. 기본값 있는 필드 추가라 경량 이전
enum SchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 3, 0)

    static var models: [any PersistentModel.Type] {
        [
            Prescription.self,
            Dose.self,
            ConditionCheck.self,
            SchemaV1.WeightSample.self,
            UserSettings.self,
            ProteinEntry.self,
            StrengthSession.self,
            HabitCheck.self,
            ClinicQuestion.self,
        ]
    }
}

/// D11 (2026-10-25 사람 결정): `WeightSample.bodyFatPercent` 추가 (Apple Health 체지방률). 옵셔널 필드 추가라 경량 이전
enum SchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 4, 0)

    static var models: [any PersistentModel.Type] {
        [
            Prescription.self,
            Dose.self,
            ConditionCheck.self,
            WeightSample.self,
            UserSettings.self,
            ProteinEntry.self,
            StrengthSession.self,
            HabitCheck.self,
            ClinicQuestion.self,
        ]
    }
}

/// 지금 앱이 여는 스키마
typealias CurrentSchema = SchemaV5

enum MasenseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
            .lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self),
        ]
    }
}
