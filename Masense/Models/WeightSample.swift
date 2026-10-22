import Foundation
import SwiftData

enum WeightSource: String, Codable, CaseIterable {
    case healthKit, manual
}

/// 체중. HealthKit 캐시 + 수동 입력 (DATA_MODEL.md).
/// HealthKit 샘플은 `healthKitUUID` 기준으로 upsert하고, HealthKit에서 삭제되면 캐시도 삭제한다.
@Model
final class WeightSample {
    @Attribute(.unique) var id: UUID
    var measuredAt: Date
    var kilograms: Double
    var source: WeightSource
    /// HealthKit 샘플 UUID (중복 방지)
    var healthKitUUID: UUID?
    /// M2. HealthKit `leanBodyMass` 또는 수동
    var leanBodyMassKg: Double?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        measuredAt: Date,
        kilograms: Double,
        source: WeightSource,
        healthKitUUID: UUID? = nil,
        leanBodyMassKg: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.kilograms = kilograms
        self.source = source
        self.healthKitUUID = healthKitUUID
        self.leanBodyMassKg = leanBodyMassKg
        self.createdAt = createdAt
    }
}
