import Foundation
import SwiftData

/// M1 스키마 (DATA_MODEL.md "스키마 버전"). M2에서 SchemaV2 + `SchemaMigrationPlan`을 추가한다.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Prescription.self,
            Dose.self,
            ConditionCheck.self,
            WeightSample.self,
            UserSettings.self,
        ]
    }
}
