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

        // M2: HealthKit 제지방량을 같은 날 HealthKit 체중 샘플에 붙인다 (체성분계는 둘을 함께 기록한다)
        let lean = try await reader.leanBodyMassSamples(since: since)
        for sample in try WeightSample.all(in: context) where sample.source == .healthKit {
            let sameDay = lean
                .filter { calendar.isDate($0.measuredAt, inSameDayAs: sample.measuredAt) }
                .max { $0.measuredAt < $1.measuredAt }
            sample.leanBodyMassKg = sameDay?.kilograms
        }
    }
}

/// M2 (P2): Apple Watch 운동 기록을 근력운동 마디로 자동 인식. `healthKitUUID` 기준 upsert, 사라진 운동은 삭제.
@MainActor
enum WorkoutSyncService {
    static func sync(
        reader: HealthKitReading,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws {
        guard reader.isAvailable,
              let since = calendar.date(byAdding: .weekOfYear, value: -WeightSyncService.lookbackWeeks, to: now)
        else { return }

        let fresh = try await reader.workouts(since: since)
        let freshByUUID = Dictionary(fresh.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })

        let cached = try context.fetch(FetchDescriptor<StrengthSession>()).filter { $0.source == .healthKit }
        for session in cached {
            guard let uuid = session.healthKitUUID else { continue }
            if let latest = freshByUUID[uuid] {
                session.startedAt = latest.startedAt
                session.durationMinutes = latest.durationMinutes
                session.kind = latest.kind
            } else if session.startedAt >= since {
                context.delete(session)
            }
        }

        let knownUUIDs = Set(cached.compactMap(\.healthKitUUID))
        for workout in fresh where !knownUUIDs.contains(workout.uuid) {
            context.insert(StrengthSession(
                startedAt: workout.startedAt,
                durationMinutes: workout.durationMinutes,
                kind: workout.kind,
                source: .healthKit,
                healthKitUUID: workout.uuid
            ))
        }
    }
}

/// 체중·제지방량·운동을 한 번에 동기화하고 저장한다
@MainActor
enum HealthSyncService {
    static func syncAll(
        reader: HealthKitReading,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws {
        try await WeightSyncService.sync(reader: reader, context: context, now: now, calendar: calendar)
        try await WorkoutSyncService.sync(reader: reader, context: context, now: now, calendar: calendar)
        try context.save()
    }
}
