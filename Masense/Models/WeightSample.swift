import Foundation
import SwiftData

enum WeightSource: String, Codable, CaseIterable {
    case healthKit, manual
}

/// 체중. HealthKit 캐시 + 수동 입력 (DATA_MODEL.md).
/// HealthKit 샘플은 `healthKitUUID`로 조회해 upsert하고(unique 제약 없음), HealthKit에서 삭제되면 캐시도 삭제한다.
@Model
final class WeightSample {
    var id: UUID = UUID()
    var measuredAt: Date = Date.now
    var kilograms: Double = 0
    /// `WeightSource` rawValue
    var sourceRaw: String = "manual"
    /// HealthKit 샘플 UUID (중복 방지는 조회 후 upsert)
    var healthKitUUID: UUID?
    /// M2. HealthKit `leanBodyMass` 또는 수동
    var leanBodyMassKg: Double?
    /// D11 (SchemaV5). HealthKit `bodyFatPercentage`, 0~100 퍼센트 값. 같은 날 측정을 붙인다
    var bodyFatPercent: Double?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        measuredAt: Date,
        kilograms: Double,
        source: WeightSource,
        healthKitUUID: UUID? = nil,
        leanBodyMassKg: Double? = nil,
        bodyFatPercent: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.kilograms = kilograms
        self.sourceRaw = source.rawValue
        self.healthKitUUID = healthKitUUID
        self.leanBodyMassKg = leanBodyMassKg
        self.bodyFatPercent = bodyFatPercent
        self.createdAt = createdAt
    }

    var source: WeightSource {
        get { WeightSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
