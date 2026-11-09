import Foundation
import SwiftData
import Testing

@testable import Masense

// M2-c: 리포트 F 섹션, HealthKit 제지방량·운동 동기화, 리포트 테마
@MainActor
struct M2ReportAndHealthTests {
    private let container: ModelContainer
    private let calendar = TestCalendar.seoul

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    private var context: ModelContext { container.mainContext }

    // MARK: F. 감량의 질

    private let period = DateInterval(start: TestCalendar.date(2026, 10, 16), end: TestCalendar.date(2026, 10, 25, 9))

    @Test func qualityIsNilWithoutM2Records() {
        let quality = ReportBuilder.qualitySection(period: period, proteins: [], sessions: [], weights: [], proteinTarget: nil, calendar: calendar)
        #expect(quality == nil)
    }

    @Test func qualityWithTargetCountsDaysFilled() {
        let proteins = [
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 20), meal: .lunch, foods: [.beef], estimatedGrams: 50),
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 20), meal: .dinner, foods: [.fish], estimatedGrams: 40),
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 21), meal: .lunch, foods: [.egg], estimatedGrams: 6),
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 9, 30), meal: .lunch, foods: [.beef], estimatedGrams: 99),
        ]
        let sessions = [
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 19, 7), durationMinutes: 20, kind: .strength),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 22, 7), durationMinutes: 30, kind: .walk),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 23, 7), durationMinutes: 20, kind: .strength),
        ]
        let weights = [
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 17, 8), kilograms: 82, source: .healthKit, leanBodyMassKg: 55.04),
            WeightSampleSnapshot(measuredAt: TestCalendar.date(2026, 10, 24, 8), kilograms: 81, source: .healthKit, leanBodyMassKg: 55.2),
        ]
        let quality = ReportBuilder.qualitySection(period: period, proteins: proteins, sessions: sessions, weights: weights, proteinTarget: 90, calendar: calendar)
        #expect(quality == ClinicReport.QualitySection(
            protein: .target(daysMet: 1, totalDays: 10),
            strengthCount: 2,
            leanMassStartText: "55.0",
            leanMassEndText: "55.2"
        ))
    }

    @Test func qualityWithoutTargetAveragesRecordedDays() {
        let proteins = [
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 20), meal: .lunch, foods: [.beef], estimatedGrams: 50),
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 21), meal: .lunch, foods: [.egg], estimatedGrams: 25),
        ]
        let quality = ReportBuilder.qualitySection(period: period, proteins: proteins, sessions: [], weights: [], proteinTarget: nil, calendar: calendar)
        #expect(quality?.protein == .noTarget(recordedDays: 2, averageGrams: 38))
        #expect(quality?.strengthCount == 0)
        #expect(quality?.leanMassStartText == nil)
    }

    // MARK: HealthKit 동기화

    @Test func leanMassAttachesToSameDayHealthSample() async throws {
        let reader = FakeHealthKitService()
        let cache = HealthCache(fileURL: nil)
        let now = TestCalendar.date(2026, 10, 25, 9)
        reader.samples = [
            HealthWeightSample(uuid: UUID(), measuredAt: TestCalendar.date(2026, 10, 20, 7), kilograms: 81),
            HealthWeightSample(uuid: UUID(), measuredAt: TestCalendar.date(2026, 10, 22, 7), kilograms: 80.5),
        ]
        reader.leanSamples = [HealthWeightSample(uuid: UUID(), measuredAt: TestCalendar.date(2026, 10, 20, 7, 1), kilograms: 54.8)]
        // D11: 체지방률도 같은 날에 붙는다 (0~100)
        reader.fatSamples = [HealthPercentSample(uuid: UUID(), measuredAt: TestCalendar.date(2026, 10, 22, 7, 1), percent: 22.0)]

        try await HealthSyncService.syncAll(reader: reader, context: context, cache: cache, now: now, calendar: calendar)
        #expect(cache.weights.map(\.leanBodyMassKg) == [54.8, nil])
        #expect(cache.weights.map(\.bodyFatPercent) == [nil, 22.0])
        // D49: 건강 앱 기록은 iCloud로 가는 SwiftData에 넣지 않는다
        #expect(try WeightSample.all(in: context).isEmpty)
    }

    @Test func workoutsGoToLocalCacheAndOldStoredHealthRecordsArePurged() async throws {
        let reader = FakeHealthKitService()
        let cache = HealthCache(fileURL: nil)
        let now = TestCalendar.date(2026, 10, 25, 9)
        reader.workoutSamples = [
            HealthWorkout(uuid: UUID(), startedAt: TestCalendar.date(2026, 10, 21, 7), durationMinutes: 25, kind: .strength),
            HealthWorkout(uuid: UUID(), startedAt: TestCalendar.date(2026, 10, 22, 18), durationMinutes: 40, kind: .walk),
        ]
        // 예전 빌드가 넣어 둔 건강 앱 기록 + 직접 입력
        context.insert(StrengthSession(startedAt: TestCalendar.date(2026, 10, 23, 7), durationMinutes: 0, kind: .rest))
        context.insert(StrengthSession(startedAt: TestCalendar.date(2026, 10, 1, 7), durationMinutes: 20, kind: .walk, source: .healthKit, healthKitUUID: UUID()))
        context.insert(WeightSample(measuredAt: TestCalendar.date(2026, 10, 2), kilograms: 80, source: .healthKit, healthKitUUID: UUID()))
        context.insert(WeightSample(measuredAt: TestCalendar.date(2026, 10, 3), kilograms: 79, source: .manual))

        try await HealthSyncService.syncAll(reader: reader, context: context, cache: cache, now: now, calendar: calendar)
        let stored = try context.fetch(FetchDescriptor<StrengthSession>())
        #expect(stored.map(\.kind) == [.rest])
        #expect(try WeightSample.all(in: context).map(\.source) == [.manual])
        #expect(cache.workouts.map(\.kind) == [.strength, .walk])
        // 화면은 직접 입력 + 캐시를 합쳐 본다
        #expect(cache.sessions(adding: stored.map(\.snapshot)).map(\.kind) == [.strength, .walk, .rest])

        // 건강 앱에서 걷기가 사라지면 캐시도 따라간다
        reader.workoutSamples = [HealthWorkout(uuid: UUID(), startedAt: TestCalendar.date(2026, 10, 21, 7), durationMinutes: 30, kind: .strength)]
        try await HealthSyncService.syncAll(reader: reader, context: context, cache: cache, now: now, calendar: calendar)
        #expect(cache.workouts.map(\.durationMinutes) == [30])
    }

    // MARK: 테마

    @Test func reportThemeFallsBackToMidnight() {
        #expect(ReportTheme(rawValue: "sand")?.accent == .accentSand)
        #expect(ReportPage.accent(forTheme: "unknown") == .paperAccent)
        #expect(ReportTheme.midnight.accent == .accent)
        #expect(ReportTheme.allCases.count == 3)
    }
}
