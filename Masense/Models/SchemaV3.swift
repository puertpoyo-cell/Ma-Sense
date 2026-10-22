import Foundation
import SwiftData

/// 현재 스키마: V2 + `UserSettings.reportDefaultPeriod` (리포트 기본 기간 저장, 2026-10-22 결정).
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

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
        ]
    }
}

/// V1 → V2는 엔티티만 더하고, V2 → V3는 선택 속성 하나를 더하므로 모두 경량 마이그레이션.
/// 스키마를 다시 바꿀 때는 바뀌는 모델의 고정 사본을 이전 버전에 두고 새 VersionedSchema와 단계를 여기에 더한다.
enum MasenseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
        ]
    }
}
