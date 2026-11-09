import Foundation
import Observation

/// D49 건강 앱에서 읽은 체중·체성분·운동 (R1, 2026-11-09 사람 결정 "R1 반영").
/// App Store 가이드라인 5.1.3은 건강 앱(HealthKit) 데이터를 iCloud에 저장하지 말라고 한다. 그래서 SwiftData(iCloud 동기화)에
/// 넣지 않고 이 기기에만 둔다: 메모리 + App Group 안의 파일(기기 백업에서도 뺀다). 폰마다 자기 건강 앱에서 다시 읽는다
/// (건강 앱은 Apple이 기기끼리 따로 동기화한다). 직접 입력한 체중·운동만 SwiftData로 동기화한다.
@Observable
final class HealthCache {
    static let shared = HealthCache(fileURL: HealthCache.defaultFileURL)

    private(set) var weights: [WeightSampleSnapshot] = []
    private(set) var workouts: [StrengthSessionSnapshot] = []
    private(set) var updatedAt: Date?

    @ObservationIgnored private let fileURL: URL?

    init(fileURL: URL?) {
        self.fileURL = fileURL
        load()
    }

    static var defaultFileURL: URL? {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
            ?? URL.applicationSupportDirectory
        return base.appendingPathComponent("HealthCache.json")
    }

    /// 직접 입력한 체중에 건강 앱 체중을 더한다 (측정 시각 순)
    func weights(adding manual: [WeightSampleSnapshot]) -> [WeightSampleSnapshot] {
        (manual + weights).sorted { $0.measuredAt < $1.measuredAt }
    }

    /// 직접 입력한 운동에 건강 앱 운동을 더한다 (시작 시각 순)
    func sessions(adding manual: [StrengthSessionSnapshot]) -> [StrengthSessionSnapshot] {
        (manual + workouts).sorted { $0.startedAt < $1.startedAt }
    }

    func replace(weights: [WeightSampleSnapshot], workouts: [StrengthSessionSnapshot], now: Date) {
        self.weights = weights.sorted { $0.measuredAt < $1.measuredAt }
        self.workouts = workouts.sorted { $0.startedAt < $1.startedAt }
        updatedAt = now
        save()
    }

    /// 전체 삭제·건강 앱 연결 해제 때
    func clear() {
        weights = []
        workouts = []
        updatedAt = nil
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }

    // MARK: 파일 (이 기기에만, 백업 제외)

    private struct Stored: Codable {
        struct Weight: Codable {
            let measuredAt: Date
            let kilograms: Double
            let leanBodyMassKg: Double?
            let bodyFatPercent: Double?
        }
        struct Workout: Codable {
            let startedAt: Date
            let durationMinutes: Int
            let kind: String
        }
        let weights: [Weight]
        let workouts: [Workout]
        let updatedAt: Date?
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        weights = stored.weights.map {
            WeightSampleSnapshot(measuredAt: $0.measuredAt, kilograms: $0.kilograms, source: .healthKit,
                                 leanBodyMassKg: $0.leanBodyMassKg, bodyFatPercent: $0.bodyFatPercent)
        }
        workouts = stored.workouts.compactMap { item in
            SessionKind(rawValue: item.kind).map { StrengthSessionSnapshot(startedAt: item.startedAt, durationMinutes: item.durationMinutes, kind: $0) }
        }
        updatedAt = stored.updatedAt
    }

    private func save() {
        guard var fileURL else { return }
        let stored = Stored(
            weights: weights.map { .init(measuredAt: $0.measuredAt, kilograms: $0.kilograms, leanBodyMassKg: $0.leanBodyMassKg, bodyFatPercent: $0.bodyFatPercent) },
            workouts: workouts.map { .init(startedAt: $0.startedAt, durationMinutes: $0.durationMinutes, kind: $0.kind.rawValue) },
            updatedAt: updatedAt
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? fileURL.setResourceValues(values)
    }
}
