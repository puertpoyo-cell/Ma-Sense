import Foundation
import SwiftData
import Testing

@testable import Masense

// M2-b: 오늘의 마디, 단백질·운동 기록, 습관 캘린더
@MainActor
struct HabitsTests {
    private let container: ModelContainer
    private let calendar = TestCalendar.seoul

    init() throws {
        container = try ModelContainer.masense(inMemory: true)
    }

    private var context: ModelContext { container.mainContext }

    // MARK: S7 단백질

    @Test func defaultMealFollowsTimeOfDay() {
        #expect(ProteinLogModel.defaultMeal(at: TestCalendar.date(2026, 10, 22, 8), calendar: calendar) == .breakfast)
        #expect(ProteinLogModel.defaultMeal(at: TestCalendar.date(2026, 10, 22, 12), calendar: calendar) == .lunch)
        #expect(ProteinLogModel.defaultMeal(at: TestCalendar.date(2026, 10, 22, 19), calendar: calendar) == .dinner)
        #expect(ProteinLogModel.defaultMeal(at: TestCalendar.date(2026, 10, 22, 22), calendar: calendar) == .snack)
    }

    @Test func proteinQuantitiesAndOtherGrams() throws {
        let now = TestCalendar.date(2026, 10, 22, 12, 30)
        let model = ProteinLogModel(target: 90, recordedToday: 20, isLowAppetite: false, preselected: .egg, now: now, calendar: calendar)
        #expect(model.quantity(of: .egg) == 1)
        model.setQuantity(2, for: .egg)
        model.toggle(.greekYogurt)
        model.toggle(.other)
        model.otherGramsText = "5"
        #expect(model.foods == [.egg, .egg, .greekYogurt, .other])
        #expect(model.estimatedGrams == 6 * 2 + 15 + 5)
        #expect(model.todayTotal == 20 + 32)

        model.setQuantity(99, for: .milk)
        #expect(model.quantity(of: .milk) == ProteinLogModel.quantityRange.upperBound)
        model.setQuantity(0, for: .milk)

        let entry = try #require(try model.save(in: context))
        #expect(entry.meal == .lunch)
        #expect(entry.date == TestCalendar.date(2026, 10, 22))
        #expect(entry.estimatedGrams == 32)
    }

    @Test func emptyProteinEntryIsNotSaved() throws {
        let model = ProteinLogModel(target: nil, recordedToday: 0, isLowAppetite: true, now: TestCalendar.date(2026, 10, 22, 8), calendar: calendar)
        #expect(!model.canSave)
        #expect(try model.save(in: context)?.id == nil)
    }

    // MARK: S8 운동

    @Test func strengthOrderAndRestDetails() throws {
        let low = StrengthLogModel(isLowCondition: true, now: TestCalendar.date(2026, 10, 22, 7))
        #expect(low.kind == .walk)
        let normal = StrengthLogModel(isLowCondition: false, now: TestCalendar.date(2026, 10, 22, 7))
        #expect(normal.kind == .strength)

        normal.kind = .rest
        normal.durationMinutes = 40
        #expect(!normal.takesDetails)
        let session = try normal.save(in: context)
        #expect(session.kind == .rest)
        #expect(session.durationMinutes == 0)
        #expect(session.source == .manual)
    }

    // MARK: 1-4 오늘의 마디

    @Test func todayModelDailyCycle() {
        let now = TestCalendar.date(2026, 10, 22, 13)
        let doseID = UUID()
        let today = TodayModel(
            prescription: nil,
            doses: [],
            checks: [ConditionCheckSnapshot(doseID: doseID, window: .h24, checkedAt: TestCalendar.date(2026, 10, 22, 9), appetite: .reduced)],
            weights: [],
            proteins: [
                ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 22), meal: .breakfast, foods: [.egg], estimatedGrams: 6),
                ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 22), meal: .lunch, foods: [.beef], estimatedGrams: 22),
                ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 21), meal: .dinner, foods: [.fish], estimatedGrams: 20),
            ],
            sessions: [StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 20, 7), durationMinutes: 20, kind: .strength)],
            habits: [HabitCheckSnapshot(date: TestCalendar.date(2026, 10, 22), water: true, fiber: false, sleep: true)],
            proteinTarget: 28,
            now: now,
            calendar: calendar
        )
        #expect(today.daily.filledMeals == [.breakfast, .lunch])
        #expect(today.daily.protein == .met(estimated: 28, target: 28))
        #expect(today.daily.week == StrengthWeek(strengthCount: 1, lightCount: 0, restCount: 0))
        // 식욕 저하만 있고 강도 2 이상 증상은 없다: R10은 해당, R11은 아님
        #expect(today.daily.isLowAppetite)
        #expect(!today.daily.isLowCondition)
        #expect(today.daily.habit?.water == true)
        #expect(today.paceNotice == nil)
    }

    // MARK: S4 습관 캘린더

    @Test func habitMonthAlignsToWeekdayAndMarksFacts() {
        // 2026-10-01은 목요일, 일요일 시작 → 앞 빈칸 4개
        let proteins = [
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 5), meal: .lunch, foods: [.beef], estimatedGrams: 22),
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 6), meal: .lunch, foods: [.chickenBreast, .chickenBreast, .chickenBreast, .chickenBreast], estimatedGrams: 92),
        ]
        let sessions = [
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 5, 7), durationMinutes: 20, kind: .strength),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 7, 7), durationMinutes: 30, kind: .walk),
        ]
        let cells = HistoryModel.habitMonth(containing: TestCalendar.date(2026, 10, 15), proteins: proteins, sessions: sessions, proteinTarget: 90, calendar: calendar)
        #expect(cells.prefix(4).allSatisfy { $0 == nil })
        #expect(cells.compactMap { $0 }.count == 31)
        let days = cells.compactMap { $0 }
        #expect(days[4] == HistoryModel.HabitDay(date: TestCalendar.date(2026, 10, 5), proteinMarked: false, strengthDone: true))
        #expect(days[5].proteinMarked)
        #expect(!days[6].strengthDone)

        let noTarget = HistoryModel.habitMonth(containing: TestCalendar.date(2026, 10, 15), proteins: proteins, sessions: [], proteinTarget: nil, calendar: calendar)
        #expect(noTarget.compactMap { $0 }[4].proteinMarked)
    }
}
