import Foundation
import Testing

@testable import Masense

// D44 기록·진료 상황 제안의 근거와 자리별 순서
struct CoachFactsRulesTests {
    private let calendar = TestCalendar.seoul
    private func d(_ m: Int, _ day: Int, _ h: Int = 0) -> Date { TestCalendar.date(2026, m, day, h) }

    /// 11/1(일) 시작, 일요일 20시 투약, 펜 4회
    private func prescription(clinic: Date?, total: Int = 4) -> PrescriptionSnapshot {
        PrescriptionSnapshot(startDate: d(11, 1), scheduledWeekday: 1, scheduledHour: 20, totalDoses: total, nextClinicDate: clinic)
    }

    private func facts(_ p: PrescriptionSnapshot?, doses: [DoseSnapshot] = [], checks: [ConditionCheckSnapshot] = [],
                       questions: Int = 0, records: [Date] = [], now: Date) -> CoachFacts {
        CoachFactsRules.facts(prescription: p, doses: doses, checks: checks, openQuestions: questions,
                              recordDates: records, now: now, calendar: calendar)
    }

    @Test func clinicDaysWithinAWeekOnly() {
        #expect(facts(prescription(clinic: d(11, 12)), now: d(11, 10, 9)).daysToClinic == 2)
        #expect(facts(prescription(clinic: d(11, 10, 15)), now: d(11, 10, 9)).daysToClinic == 0)
        #expect(facts(prescription(clinic: d(11, 30)), now: d(11, 10, 9)).daysToClinic == nil)
        #expect(facts(prescription(clinic: d(11, 9)), now: d(11, 10, 9)).daysToClinic == nil)
    }

    @Test func conditionMissingBetween48HoursAndAWeek() {
        let dose = DoseSnapshot(administeredAt: d(11, 8, 20), scheduledFor: d(11, 8, 20), site: nil, sequence: 2)
        #expect(facts(prescription(clinic: nil), doses: [dose], now: d(11, 10, 21)).conditionMissing)
        #expect(!facts(prescription(clinic: nil), doses: [dose], now: d(11, 9, 21)).conditionMissing)
        #expect(!facts(prescription(clinic: nil), doses: [dose], now: d(11, 16, 21)).conditionMissing)
        let check = ConditionCheckSnapshot(doseID: dose.id, window: .h24, checkedAt: d(11, 9, 21))
        #expect(!facts(prescription(clinic: nil), doses: [dose], checks: [check], now: d(11, 10, 21)).conditionMissing)
    }

    @Test func repeatedSymptomNeedsThreeRecentPeriods() {
        let nausea = [SymptomEntry(symptom: .nausea, severity: 1)]
        let checks = [d(11, 2, 21), d(11, 9, 21), d(11, 16, 21)].map {
            ConditionCheckSnapshot(doseID: UUID(), window: .h24, checkedAt: $0, symptoms: nausea)
        }
        // 11/23 진행 중 마디는 아직 비어 있어 그 앞 세 마디를 센다
        let f = facts(prescription(clinic: nil, total: 8), checks: checks, now: d(11, 23, 10))
        #expect(f.repeatedSymptom == .nausea && f.repeatedPeriods == 3)
        let two = facts(prescription(clinic: nil, total: 8), checks: Array(checks.dropFirst()), now: d(11, 23, 10))
        #expect(two.repeatedSymptom == nil)
    }

    @Test func pensShortWhenClinicIsAfterTheNextNeededDose() {
        // 4회: 11/1·8 맞음, 11/15·22 남음. 다음 필요한 날 11/29, 진료 12/6 → 부족
        let used = [d(11, 1, 20), d(11, 8, 20)].enumerated().map {
            DoseSnapshot(administeredAt: $0.element, scheduledFor: $0.element, site: nil, sequence: $0.offset + 1)
        }
        let short = facts(prescription(clinic: d(12, 6)), doses: used, now: d(11, 10, 9))
        #expect(short.pensLastDose.map { calendar.startOfDay(for: $0) } == d(11, 22))
        #expect(short.pensClinic == d(12, 6))
        // 진료 11/27 → 다음 필요한 날 전에 진료
        #expect(facts(prescription(clinic: d(11, 27)), doses: used, now: d(11, 10, 9)).pensLastDose == nil)
    }

    @Test func recordGapFromThreeDays() {
        #expect(facts(nil, records: [d(11, 5, 9)], now: d(11, 10, 9)).recordGapDays == 5)
        #expect(facts(nil, records: [d(11, 8, 9)], now: d(11, 10, 9)).recordGapDays == nil)
        #expect(facts(nil, records: [], now: d(11, 10, 9)).recordGapDays == nil)
    }

    @Test func factLinesOrderBySpot() {
        var f = CoachFacts()
        f.daysToClinic = 2
        f.conditionMissing = true
        f.recordGapDays = 4
        #expect(CoachRules.factLines(f, for: .clinic) == [.clinicSoon(2), .questionsEmpty])
        #expect(CoachRules.factLines(f, for: .history) == [.recordGap(4), .conditionMissing, .clinicSoon(2)])
        #expect(CoachRules.factLines(f, for: .report) == [.clinicSoon(2), .questionsEmpty, .conditionMissing])
        f.openQuestions = 2
        #expect(CoachRules.factLines(f, for: .clinic) == [.clinicSoon(2)])
        // 일주일 안이지만 3일보다 멀면 리포트 권유는 없고 물어볼 것만
        f.daysToClinic = 6
        f.openQuestions = 0
        #expect(CoachRules.factLines(f, for: .clinic) == [.questionsEmpty])
    }

    @Test func clinicSpotUsesFactsBeforePlaceLine() {
        var c = CoachContext()
        c.facts.daysToClinic = 1
        let lines = CoachRules.lines(for: .clinic, context: c, now: d(11, 10, 9), calendar: calendar)
        #expect(lines.first == .clinicSoon(1))
        #expect(CoachRules.greeting(context: c, now: d(11, 10, 9), calendar: calendar) == .clinicSoon(1))
        #expect(CoachRules.suggestedTopics(context: c, now: d(11, 10, 9), calendar: calendar).first == .clinic)
    }
}
