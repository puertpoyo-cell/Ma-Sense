import Foundation
import Testing

@testable import Masense

// RULES.md R8·R9·R10·R11 (M2)
struct M2RulesTests {
    private let calendar = TestCalendar.seoul

    // MARK: R9 단백질

    @Test func proteinGuideRangeRoundsToWholeGrams() {
        #expect(ProteinRules.proteinGuideRange(weightKg: 70) == 84...112)
        // 65.5 × 1.2 = 78.6 → 79, 65.5 × 1.6 = 104.8 → 105
        #expect(ProteinRules.proteinGuideRange(weightKg: 65.5) == 79...105)
    }

    @Test func estimatedGramsSumsDefaults() {
        #expect(ProteinRules.estimatedGrams(for: [.egg, .egg, .greekYogurt]) == 27)
        #expect(ProteinRules.estimatedGrams(for: [.other]) == 0)
        #expect(ProteinRules.estimatedGrams(for: []) == 0)
    }

    @Test func dayStatus() {
        let day = TestCalendar.date(2026, 10, 22)
        let entries = [
            ProteinEntrySnapshot(date: day, meal: .breakfast, foods: [.egg, .egg], estimatedGrams: 12),
            ProteinEntrySnapshot(date: day, meal: .lunch, foods: [.chickenBreast], estimatedGrams: 23),
            ProteinEntrySnapshot(date: TestCalendar.date(2026, 10, 21), meal: .dinner, foods: [.beef], estimatedGrams: 22),
        ]
        let today = ProteinRules.entries(on: day, from: entries, calendar: calendar)
        #expect(today.count == 2)
        #expect(ProteinRules.proteinDayStatus(entries: today, target: nil) == .noTarget(estimated: 35))
        #expect(ProteinRules.proteinDayStatus(entries: today, target: 90) == .below(estimated: 35, target: 90))
        #expect(ProteinRules.proteinDayStatus(entries: today, target: 35) == .met(estimated: 35, target: 35))
    }

    // MARK: R10·R11 저컨디션

    @Test func lowAppetiteAndLowConditionAreSeparateWithin48Hours() {
        let now = TestCalendar.date(2026, 10, 24, 12)
        let doseID = UUID()
        let at = TestCalendar.date(2026, 10, 23, 9)
        let nausea = ConditionCheckSnapshot(doseID: doseID, window: .h24, checkedAt: at, symptoms: [SymptomEntry(symptom: .nausea, severity: 2)])
        let appetite = ConditionCheckSnapshot(doseID: doseID, window: .h48, checkedAt: at, appetite: .reduced)
        let constipation = ConditionCheckSnapshot(doseID: doseID, window: .h24, checkedAt: at, symptoms: [SymptomEntry(symptom: .constipation, severity: 2)])
        let mild = ConditionCheckSnapshot(doseID: doseID, window: .h24, checkedAt: at, symptoms: [SymptomEntry(symptom: .fatigue, severity: 1)])
        let old = ConditionCheckSnapshot(doseID: doseID, window: .h24, checkedAt: TestCalendar.date(2026, 10, 22, 11),
                                         symptoms: [SymptomEntry(symptom: .nausea, severity: 3)], appetite: .veryReduced)

        // R10 식욕 저하일: 구역 ≥ 2 또는 식욕 ≠ 평소
        #expect(ConditionRules.isLowAppetiteDay(checks: [nausea], now: now))
        #expect(ConditionRules.isLowAppetiteDay(checks: [appetite], now: now))
        #expect(!ConditionRules.isLowAppetiteDay(checks: [constipation], now: now))
        #expect(!ConditionRules.isLowAppetiteDay(checks: [mild], now: now))
        #expect(!ConditionRules.isLowAppetiteDay(checks: [old], now: now))

        // R11 저컨디션 날: 강도 2 이상 증상 (식욕은 보지 않음)
        #expect(ConditionRules.isLowConditionDay(checks: [nausea], now: now))
        #expect(ConditionRules.isLowConditionDay(checks: [constipation], now: now))
        #expect(!ConditionRules.isLowConditionDay(checks: [appetite], now: now))
        #expect(!ConditionRules.isLowConditionDay(checks: [mild], now: now))
        #expect(!ConditionRules.isLowConditionDay(checks: [old], now: now))
        #expect(!ConditionRules.isLowConditionDay(checks: [], now: now))
    }

    @Test func sessionOrderPutsLightOptionsFirstOnLowConditionDay() {
        #expect(StrengthRules.kindOrder(isLowCondition: false) == [.strength, .walk, .stretch, .rest])
        #expect(StrengthRules.kindOrder(isLowCondition: true) == [.walk, .stretch, .rest, .strength])
    }

    @Test func strengthWeekCountsFacts() {
        // 2026-10-18(일) ~ 10-24(토) 주
        let sessions = [
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 19, 7), durationMinutes: 20, kind: .strength),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 21, 7), durationMinutes: 15, kind: .strength),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 22, 7), durationMinutes: 30, kind: .walk),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 23, 7), durationMinutes: 10, kind: .stretch),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 24, 7), durationMinutes: 0, kind: .rest),
            StrengthSessionSnapshot(startedAt: TestCalendar.date(2026, 10, 25, 7), durationMinutes: 20, kind: .strength),
        ]
        let week = StrengthRules.strengthWeekSummary(sessions: sessions, weekOf: TestCalendar.date(2026, 10, 22), calendar: calendar)
        #expect(week == StrengthWeek(strengthCount: 2, lightCount: 2, restCount: 1))
    }

    // MARK: R8 감량 속도

    private func series(_ values: [Double?]) -> [WeekPoint] {
        values.enumerated().map { index, value in
            WeekPoint(
                weekStart: TestCalendar.date(2026, 9, 6).addingTimeInterval(Double(index) * 7 * 86_400),
                averageKg: value,
                sampleCount: value == nil ? 0 : 1
            )
        }
    }

    @Test func paceNoticeWhenTwoWeeksFasterThanOneKilogram() {
        #expect(PaceRules.paceNotice(series: series([100, 98, 96])) == .fasterThanGeneralGuide)
        #expect(PaceRules.paceNotice(series: series([110, 105, 100, 98.5, 97])) == .fasterThanGeneralGuide)
        // 기준은 kg: 체중이 커서 1% 미만이어도 주 1 kg를 넘으면 안내
        #expect(PaceRules.paceNotice(series: series([150, 148.8, 147.6])) == .fasterThanGeneralGuide)
    }

    @Test func noPaceNoticeAtExactlyOneKilogramOrOnlyOneWeek() {
        // 첫 주 정확히 -1.0 kg → 초과가 아니므로 안내 없음
        #expect(PaceRules.paceNotice(series: series([100, 99, 97])) == nil)
        // 한 주만 빠름
        #expect(PaceRules.paceNotice(series: series([100, 99.5, 97])) == nil)
        // 체중이 작아 1%를 넘어도 주 1 kg 이하면 안내 없음
        #expect(PaceRules.paceNotice(series: series([60, 59.2, 58.4])) == nil)
    }

    @Test func noPaceNoticeWhenSlowerGainingOrMissingWeeks() {
        #expect(PaceRules.paceNotice(series: series([100, 100.2, 100.5])) == nil)
        #expect(PaceRules.paceNotice(series: series([100, 99.8, 99.6])) == nil)
        #expect(PaceRules.paceNotice(series: series([100, nil, 96])) == nil)
        #expect(PaceRules.paceNotice(series: series([100, 98])) == nil)
    }
}
