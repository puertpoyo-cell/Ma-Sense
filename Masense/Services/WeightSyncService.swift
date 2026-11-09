import Foundation
import SwiftData

/// 건강 앱 체중·제지방량·체지방률·운동을 읽어 이 기기 `HealthCache`에 둔다.
/// D49 (R1, App Store 가이드라인 5.1.3): 건강 앱 데이터는 SwiftData(iCloud 동기화)에 넣지 않는다.
/// 예전 빌드가 SwiftData에 넣어 둔 건강 앱 기록은 동기화할 때마다 지운다 (지운 것이 iCloud에도 전해져 거기서도 빠진다)
@MainActor
enum HealthSyncService {
    /// 읽는 범위. 리포트 최대 기간(12주)보다 넉넉하게, 체중 추이 "전체"(D7)가 1년을 보이도록 (D11에서 26 → 52주)
    static let lookbackWeeks = 52

    static func syncAll(
        reader: HealthKitReading,
        context: ModelContext,
        cache: HealthCache = .shared,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws {
        try purgeStoredHealthRecords(context: context)
        guard reader.isAvailable,
              let since = calendar.date(byAdding: .weekOfYear, value: -lookbackWeeks, to: now)
        else { return }

        let bodyMass = try await reader.bodyMassSamples(since: since)
        let lean = try await reader.leanBodyMassSamples(since: since)
        let fat = try await reader.bodyFatSamples(since: since)
        let weights = HealthCacheRules.weights(bodyMass: bodyMass, lean: lean, fat: fat, calendar: calendar)
        let workouts = try await reader.workouts(since: since).map {
            StrengthSessionSnapshot(startedAt: $0.startedAt, durationMinutes: $0.durationMinutes, kind: $0.kind)
        }
        cache.replace(weights: weights, workouts: workouts, now: now)
    }

    /// 예전 빌드가 SwiftData에 넣은 건강 앱 기록을 지운다. 직접 입력한 기록은 그대로
    static func purgeStoredHealthRecords(context: ModelContext) throws {
        var changed = false
        for sample in try WeightSample.all(in: context) where sample.source == .healthKit {
            context.delete(sample)
            changed = true
        }
        for session in try context.fetch(FetchDescriptor<StrengthSession>()) where session.source == .healthKit {
            context.delete(session)
            changed = true
        }
        if changed { try context.save() }
    }
}

/// D49 건강 앱 샘플 → 캐시 스냅샷. 제지방량·체지방률은 같은 날 체중에 붙인다(그날 가장 늦은 값, 체성분계는 함께 기록한다)
enum HealthCacheRules {
    static func weights(bodyMass: [HealthWeightSample], lean: [HealthWeightSample], fat: [HealthPercentSample], calendar: Calendar) -> [WeightSampleSnapshot] {
        bodyMass
            .sorted { $0.measuredAt < $1.measuredAt }
            .map { sample in
                WeightSampleSnapshot(
                    measuredAt: sample.measuredAt,
                    kilograms: sample.kilograms,
                    source: .healthKit,
                    leanBodyMassKg: lean
                        .filter { calendar.isDate($0.measuredAt, inSameDayAs: sample.measuredAt) }
                        .max { $0.measuredAt < $1.measuredAt }?
                        .kilograms,
                    bodyFatPercent: fat
                        .filter { calendar.isDate($0.measuredAt, inSameDayAs: sample.measuredAt) }
                        .max { $0.measuredAt < $1.measuredAt }?
                        .percent
                )
            }
    }
}
