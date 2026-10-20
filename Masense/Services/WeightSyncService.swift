import Foundation
import SwiftData

/// HealthKit 샘플을 `WeightSample` 캐시에 upsert하고, HealthKit에서 사라진 샘플은 캐시에서도 지운다.
@MainActor
enum WeightSyncService {
    /// 동기화 범위. 리포트 최대 기간(12주)보다 넉넉하게
    static let lookbackWeeks = 26

    static func sync(
        reader: HealthKitReading,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws {
        guard reader.isAvailable,
              let since = calendar.date(byAdding: .weekOfYear, value: -lookbackWeeks, to: now)
        else { return }

        let fresh = try await reader.bodyMassSamples(since: since)
        let freshByUUID = Dictionary(fresh.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })

        let cached = try WeightSample.all(in: context).filter { $0.source == .healthKit }
        for sample in cached {
            guard let uuid = sample.healthKitUUID else { continue }
            if let latest = freshByUUID[uuid] {
                sample.measuredAt = latest.measuredAt
                sample.kilograms = latest.kilograms
            } else if sample.measuredAt >= since {
                context.delete(sample)
            }
        }

        let knownUUIDs = Set(cached.compactMap(\.healthKitUUID))
        for sample in fresh where !knownUUIDs.contains(sample.uuid) {
            context.insert(WeightSample(
                measuredAt: sample.measuredAt,
                kilograms: sample.kilograms,
                source: .healthKit,
                healthKitUUID: sample.uuid
            ))
        }
    }
}
