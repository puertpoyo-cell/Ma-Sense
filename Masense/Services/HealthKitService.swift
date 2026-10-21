import Foundation
import HealthKit

/// HealthKit 읽기 전용 (DATA_MODEL.md "HealthKit 매핑"). 쓰기는 v1.1.
/// 실제 사용에는 HealthKit 권한(entitlement)과 `NSHealthShareUsageDescription`이 필요하다.
protocol HealthKitReading: AnyObject {
    var isAvailable: Bool { get }
    func requestReadAuthorization() async throws -> Bool
    /// `since` 이후 체중 샘플. 삭제 감지를 위해 범위 안의 전체를 돌려준다
    func bodyMassSamples(since: Date) async throws -> [HealthWeightSample]
    /// M2: 제지방량 샘플
    func leanBodyMassSamples(since: Date) async throws -> [HealthWeightSample]
    /// M2 (P2): 근력·걷기·유연성 운동. 그 밖의 종류는 돌려주지 않는다
    func workouts(since: Date) async throws -> [HealthWorkout]
}

struct HealthWeightSample: Equatable {
    let uuid: UUID
    let measuredAt: Date
    let kilograms: Double
}

struct HealthWorkout: Equatable {
    let uuid: UUID
    let startedAt: Date
    let durationMinutes: Int
    let kind: SessionKind
}

final class HealthKitService: HealthKitReading {
    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)
    private let leanBodyMass = HKQuantityType(.leanBodyMass)

    /// Info.plist에 `NSHealthShareUsageDescription`이 없으면 권한 요청 순간 앱이 종료된다.
    /// 키를 추가하기 전(사람 확인 대기)에는 HealthKit을 쓰지 않는다.
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
            && Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil
    }

    func requestReadAuthorization() async throws -> Bool {
        guard isAvailable else { return false }
        try await store.requestAuthorization(toShare: [], read: [bodyMass, leanBodyMass, HKObjectType.workoutType()])
        // 읽기 권한은 조회 결과로만 알 수 있다 (거부해도 .sharingDenied를 돌려주지 않음)
        return true
    }

    func bodyMassSamples(since: Date) async throws -> [HealthWeightSample] {
        try await kilogramSamples(of: bodyMass, since: since)
    }

    func leanBodyMassSamples(since: Date) async throws -> [HealthWeightSample] {
        try await kilogramSamples(of: leanBodyMass, since: since)
    }

    func workouts(since: Date) async throws -> [HealthWorkout] {
        let samples = try await samples(of: HKObjectType.workoutType(), since: since)
        return samples.compactMap { sample in
            guard let workout = sample as? HKWorkout, let kind = Self.sessionKind(for: workout.workoutActivityType) else { return nil }
            return HealthWorkout(
                uuid: workout.uuid,
                startedAt: workout.startDate,
                durationMinutes: Int((workout.duration / 60).rounded()),
                kind: kind
            )
        }
    }

    /// Apple Watch 운동 종류 → 근력운동 마디 종류 (DATA_MODEL.md HealthKit 매핑)
    static func sessionKind(for type: HKWorkoutActivityType) -> SessionKind? {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .strength
        case .walking: return .walk
        case .flexibility: return .stretch
        default: return nil
        }
    }

    private func kilogramSamples(of type: HKQuantityType, since: Date) async throws -> [HealthWeightSample] {
        let unit = HKUnit.gramUnit(with: .kilo)
        return try await samples(of: type, since: since)
            .compactMap { $0 as? HKQuantitySample }
            .map { HealthWeightSample(uuid: $0.uuid, measuredAt: $0.startDate, kilograms: $0.quantity.doubleValue(for: unit)) }
    }

    private func samples(of type: HKSampleType, since: Date) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results ?? [])
                }
            }
            store.execute(query)
        }
    }
}

/// 테스트·미리보기용
final class FakeHealthKitService: HealthKitReading {
    var isAvailable = true
    var authorized = true
    var samples: [HealthWeightSample] = []
    var leanSamples: [HealthWeightSample] = []
    var workoutSamples: [HealthWorkout] = []

    func requestReadAuthorization() async throws -> Bool { authorized }

    func bodyMassSamples(since: Date) async throws -> [HealthWeightSample] {
        samples.filter { $0.measuredAt >= since }
    }

    func leanBodyMassSamples(since: Date) async throws -> [HealthWeightSample] {
        leanSamples.filter { $0.measuredAt >= since }
    }

    func workouts(since: Date) async throws -> [HealthWorkout] {
        workoutSamples.filter { $0.startedAt >= since }
    }
}
