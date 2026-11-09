import Foundation
import SwiftData

/// D44 오늘 탭 밖(기록·진료·리포트)에서 마선생이 쓸 오늘의 사실. 오늘 탭과 같은 `TodayModel` 계산을 저장소에서 바로 불러 쓴다.
/// 화면을 열 때·말을 걸 때만 부른다 (스크롤마다 부르지 않는다)
enum CoachContextService {
    @MainActor
    static func make(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> CoachContext {
        let prescriptions = (try? context.fetch(FetchDescriptor<Prescription>(sortBy: [SortDescriptor(\.startDate)]))) ?? []
        let active = prescriptions.first { $0.isActive }
        let checks = (try? context.fetch(FetchDescriptor<ConditionCheck>(sortBy: [SortDescriptor(\.checkedAt)]))) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightSample>(sortBy: [SortDescriptor(\.measuredAt)]))) ?? []
        let proteins = (try? context.fetch(FetchDescriptor<ProteinEntry>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<StrengthSession>())) ?? []
        let habits = (try? context.fetch(FetchDescriptor<HabitCheck>())) ?? []
        let visits = (try? context.fetch(FetchDescriptor<ClinicVisit>())) ?? []
        let open = (try? context.fetchCount(FetchDescriptor<ClinicQuestion>(predicate: #Predicate { $0.askedAt == nil }))) ?? 0
        let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
        return TodayModel(
            prescription: active?.snapshot,
            doses: active?.doseSnapshots ?? [],
            checks: checks.compactMap(\.snapshot),
            weights: HealthCache.shared.weights(adding: weights.map(\.snapshot)),
            proteins: proteins.map(\.snapshot),
            sessions: HealthCache.shared.sessions(adding: sessions.map(\.snapshot)),
            habits: habits.map(\.snapshot),
            proteinTarget: settings?.proteinTargetGrams,
            heightCm: settings?.heightCm,
            allDoses: prescriptions.flatMap(\.doses).map(\.snapshot),
            visitDates: visits.map(\.visitedAt),
            openQuestions: open,
            now: now,
            calendar: calendar
        ).coachContext
    }
}
