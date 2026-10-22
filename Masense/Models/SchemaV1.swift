import Foundation
import SwiftData

/// 출시 스키마 (DATA_MODEL.md "스키마 버전"). 2026-10-22 출시 전 재정리: CloudKit 호환 규칙(B)과 처방 endDate(C)를 담아
/// 이전 개발용 V1~V3 이력을 접었다. 출시(베타 배포) 뒤 스키마를 바꿀 때는 바뀌는 모델의 고정 사본을 이 버전에 두고
/// `SchemaV2`와 `MasenseMigrationPlan`의 단계를 더한다. CloudKit 규칙 5에 따라 변경은 필드·모델 추가만.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

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

enum MasenseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
