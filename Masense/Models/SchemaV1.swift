import Foundation
import SwiftData

/// M1 스키마 (DATA_MODEL.md "스키마 버전"). M2에서 SchemaV2 + `SchemaMigrationPlan`을 추가한다.
/// V3에서 `UserSettings`가 바뀌었으므로 V1·V2의 `UserSettings`는 아래 고정 사본을 쓴다.
/// 나머지 모델은 V3까지 바뀌지 않아 현재 타입을 그대로 쓴다.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Prescription.self,
            Dose.self,
            ConditionCheck.self,
            WeightSample.self,
            SchemaV1.UserSettings.self,
        ]
    }
}

extension SchemaV1 {
    /// V1·V2의 `UserSettings` 고정 사본. 저장 속성은 V3 이전 그대로 두고 고치지 않는다 (마이그레이션이 버전을 알아보는 기준)
    @Model
    final class UserSettings {
        @Attribute(.unique) var id: UUID
        var hasAcceptedRoleNotice: Bool
        var hasConfirmedAdult: Bool
        var reminderEnabled: Bool
        var eveningReminderHour: Int
        var conditionCheckEnabled: Bool
        var clinicReminderDaysBefore: Int
        var exhaustionReminderDosesLeft: Int
        var proteinTargetGrams: Int?
        var bodyWeightForGuideKg: Double?
        var healthKitAuthorized: Bool
        var hasPurchasedPro: Bool
        var reportTheme: String
        var createdAt: Date

        init(
            id: UUID = UUID(),
            hasAcceptedRoleNotice: Bool = false,
            hasConfirmedAdult: Bool = false,
            reminderEnabled: Bool = true,
            eveningReminderHour: Int = 20,
            conditionCheckEnabled: Bool = true,
            clinicReminderDaysBefore: Int = 1,
            exhaustionReminderDosesLeft: Int = 2,
            proteinTargetGrams: Int? = nil,
            bodyWeightForGuideKg: Double? = nil,
            healthKitAuthorized: Bool = false,
            hasPurchasedPro: Bool = false,
            reportTheme: String = "midnight",
            createdAt: Date = Date()
        ) {
            self.id = id
            self.hasAcceptedRoleNotice = hasAcceptedRoleNotice
            self.hasConfirmedAdult = hasConfirmedAdult
            self.reminderEnabled = reminderEnabled
            self.eveningReminderHour = eveningReminderHour
            self.conditionCheckEnabled = conditionCheckEnabled
            self.clinicReminderDaysBefore = clinicReminderDaysBefore
            self.exhaustionReminderDosesLeft = exhaustionReminderDosesLeft
            self.proteinTargetGrams = proteinTargetGrams
            self.bodyWeightForGuideKg = bodyWeightForGuideKg
            self.healthKitAuthorized = healthKitAuthorized
            self.hasPurchasedPro = hasPurchasedPro
            self.reportTheme = reportTheme
            self.createdAt = createdAt
        }
    }
}
