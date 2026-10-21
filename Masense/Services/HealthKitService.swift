import Foundation
import HealthKit

/// HealthKit 체중 읽기 (DATA_MODEL.md "HealthKit 매핑"). 쓰기는 v1.1.
/// 실제 사용에는 HealthKit 권한(entitlement)과 `NSHealthShareUsageDescription`이 필요하다.
protocol HealthKitReading: AnyObject {
    var isAvailable: Bool { get }
    func requestReadAuthorization() async throws -> Bool
    /// `since` 이후 체중 샘플. 삭제 감지를 위해 범위 안의 전체를 돌려준다
    func bodyMassSamples(since: Date) async throws -> [HealthWeightSample]
}

struct HealthWeightSample: Equatable {
    let uuid: UUID
    let measuredAt: Date
    let kilograms: Double
}

final class HealthKitService: HealthKitReading {
    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)

    /// Info.plist에 `NSHealthShareUsageDescription`이 없으면 권한 요청 순간 앱이 종료된다.
    /// 키를 추가하기 전(사람 확인 대기)에는 HealthKit을 쓰지 않는다.
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
            && Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil
    }

    func requestReadAuthorization() async throws -> Bool {
        guard isAvailable else { return false }
        try await store.requestAuthorization(toShare: [], read: [bodyMass])
        // 읽기 권한은 조회 결과로만 알 수 있다 (거부해도 .sharingDenied를 돌려주지 않음)
        return true
    }

    func bodyMassSamples(since: Date) async throws -> [HealthWeightSample] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: bodyMass, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }
        let unit = HKUnit.gramUnit(with: .kilo)
        return samples.map {
            HealthWeightSample(uuid: $0.uuid, measuredAt: $0.startDate, kilograms: $0.quantity.doubleValue(for: unit))
        }
    }
}

/// 테스트·미리보기용
final class FakeHealthKitService: HealthKitReading {
    var isAvailable = true
    var authorized = true
    var samples: [HealthWeightSample] = []

    func requestReadAuthorization() async throws -> Bool { authorized }

    func bodyMassSamples(since: Date) async throws -> [HealthWeightSample] {
        samples.filter { $0.measuredAt >= since }
    }
}
