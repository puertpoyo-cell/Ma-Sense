import Foundation
import SwiftData

/// M2 스키마: V1 + 단백질·근력운동·습관 (DATA_MODEL.md "스키마 버전").
/// `UserSettings`는 V1과 같은 고정 사본(`SchemaV1.UserSettings`)이다.
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
