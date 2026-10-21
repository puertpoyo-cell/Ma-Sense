import Foundation
import SwiftData

/// M2 스키마: V1 + 단백질·근력운동·습관 (DATA_MODEL.md "스키마 버전").
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        SchemaV1.models + [
            ProteinEntry.self,
            StrengthSession.self,
            HabitCheck.self,
        ]
    }
}

/// V1 → V2는 엔티티만 더하므로 경량 마이그레이션.
/// 베타 배포 뒤 스키마를 바꿀 때는 새 VersionedSchema와 단계를 여기에 더한다.
enum MasenseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
