import Foundation
import SwiftData

/// HealthKit 샘플을 `WeightSample` 캐시에 upsert하고, HealthKit에서 사라진 샘플은 캐시에서도 지운다.
@MainActor
enum WeightSyncService {
    /// 동기화 범위. 리포트 최대 기간(12주)보다 넉넉하게, 체중 추이 "전체"(D7)가 1년을 보이도록 (D11에서 26 → 52주)
    static let lookbackWeeks = 52

    static func sync(
        reader: HealthKitReading,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        deletesMissing: Bool = true
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
            } else if deletesMissing, sample.measuredAt >= since {
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

        // M2·D11: HealthKit 제지방량·체지방률을 같은 날 HealthKit 체중 샘플에 붙인다 (체성분계는 함께 기록한다)
        let lean = try await reader.leanBodyMassSamples(since: since)
        let fat = try await reader.bodyFatSamples(since: since)
        for sample in try WeightSample.all(in: context) where sample.source == .healthKit {
            sample.leanBodyMassKg = lean
                .filter { calendar.isDate($0.measuredAt, inSameDayAs: sample.measuredAt) }
                .max { $0.measuredAt < $1.measuredAt }?
                .kilograms
            sample.bodyFatPercent = fat
                .filter { calendar.isDate($0.measuredAt, inSameDayAs: sample.measuredAt) }
                .max { $0.measuredAt < $1.measuredAt }?
                .percent
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
        calendar: Calendar = .current,
        deletesMissing: Bool = true
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
            } else if deletesMissing, session.startedAt >= since {
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

/// 체중·제지방량·체지방률·운동을 한 번에 동기화하고 저장한다
@MainActor
enum HealthSyncService {
    static func syncAll(
        reader: HealthKitReading,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        deletesMissing: Bool = !AppConfig.usesCloudSync
    ) async throws {
        // D26: iCloud로 다른 기기가 가져온 건강 앱 기록은 이 기기 건강 앱에 아직 없을 수 있다.
        // 동기화가 켜져 있으면 "이 기기 건강 앱에 없음"을 지운 것으로 보지 않는다 (기기끼리 지웠다 다시 넣기를 되풀이하지 않게)
        try await WeightSyncService.sync(reader: reader, context: context, now: now, calendar: calendar, deletesMissing: deletesMissing)
        try await WorkoutSyncService.sync(reader: reader, context: context, now: now, calendar: calendar, deletesMissing: deletesMissing)
        try context.save()
        // 두 기기가 같은 건강 앱 기록을 각각 가져왔으면 하나로
        try SyncMergeService.mergeDuplicates(context: context, calendar: calendar)
    }
}
