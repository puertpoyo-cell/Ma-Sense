import Foundation

/// D44 마선생이 기록·진료 상황을 보고 알맞은 때 건네는 제안의 근거 (2026-11-08 사람 요청
/// "기록 추이나 진료 등에 대해서도 조언·제언, 적절 시점에", "그냥 띄워 놓기만 하면 어쩌냐").
/// 사실만 모은다. 원인·용량·체중 결과를 해석하지 않고, 할 일(리포트·물어볼 것·기록·병원 확인)만 권한다 (COMPLIANCE.md)
struct CoachFacts: Equatable {
    /// 다음 진료까지 남은 날 (0 = 오늘). 일주일 넘게 남았거나 지났으면 nil
    var daysToClinic: Int?
    /// 아직 묻지 않은 물어볼 것 수
    var openQuestions = 0
    /// 최근 마디에 이어서 기록한 증상과 그 마디 수 (3 이상일 때만)
    var repeatedSymptom: Symptom?
    var repeatedPeriods = 0
    /// 지난 투약 뒤 48시간이 지났는데(7일 안) 그 투약의 컨디션 기록이 하나도 없다
    var conditionMissing = false
    /// 남은 펜으로 맞는 마지막 투약일과 다음 진료일. 마지막 투약 다음 예정일보다 진료가 늦을 때만
    var pensLastDose: Date?
    var pensClinic: Date?
    /// 어떤 기록도 없이 지난 날 수 (3 이상일 때만)
    var recordGapDays: Int?
}

enum CoachFactsRules {
    /// 진료 며칠 전부터 "리포트 만들어 둘까요"
    static let clinicSoonDays = 3
    /// 진료 며칠 전부터 "물어볼 것이 비어 있어요"
    static let questionsWindowDays = 7
    /// 증상을 몇 마디 이어서 기록하면 물어볼 것으로 권하는지
    static let repeatedPeriodsMin = 3
    /// 기록이 며칠 비면 다시 이어 가자고 하는지
    static let recordGapMin = 3

    static func facts(
        prescription: PrescriptionSnapshot?,
        doses: [DoseSnapshot],
        checks: [ConditionCheckSnapshot],
        openQuestions: Int,
        recordDates: [Date],
        now: Date,
        calendar: Calendar
    ) -> CoachFacts {
        var facts = CoachFacts()
        facts.openQuestions = openQuestions
        let today = calendar.startOfDay(for: now)

        if let clinic = prescription?.nextClinicDate,
           let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: clinic)).day,
           (0...questionsWindowDays).contains(days) {
            facts.daysToClinic = days
        }

        if let prescription {
            let (symptom, periods) = repeatedSymptom(prescription: prescription, checks: checks, now: now, calendar: calendar)
            if periods >= repeatedPeriodsMin {
                facts.repeatedSymptom = symptom
                facts.repeatedPeriods = periods
            }
            if let clinic = prescription.nextClinicDate,
               let last = PrescriptionRules.exhaustionEstimate(p: prescription, doses: doses, now: now, calendar: calendar),
               let needed = calendar.date(byAdding: .day, value: CycleRules.intervalDays, to: calendar.startOfDay(for: last)),
               calendar.startOfDay(for: clinic) > needed,
               needed >= today {
                facts.pensLastDose = last
                facts.pensClinic = clinic
            }
        }

        if let last = doses.filter({ !$0.isCancelled }).max(by: { $0.administeredAt < $1.administeredAt }) {
            let hours = now.timeIntervalSince(last.administeredAt) / 3_600
            if hours >= 48, hours <= 24 * 7, !checks.contains(where: { $0.doseID == last.id }) {
                facts.conditionMissing = true
            }
        }

        if let latest = recordDates.max(),
           let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: latest), to: today).day,
           days >= recordGapMin {
            facts.recordGapDays = days
        }
        return facts
    }

    /// 최근 마디들에서 끝에서부터 이어서 기록된 마디가 가장 많은 증상. 지금 진행 중인 마디가 비어 있으면 그 앞부터 센다
    static func repeatedSymptom(prescription: PrescriptionSnapshot, checks: [ConditionCheckSnapshot], now: Date, calendar: Calendar) -> (Symptom?, Int) {
        let periods = SymptomFlowRules.recentPeriods(prescription: prescription, now: now, calendar: calendar)
        var best: (Symptom?, Int) = (nil, 0)
        for flow in SymptomFlowRules.flows(periods: periods, checks: checks) {
            var severities = flow.severities
            if severities.last == 0 { severities.removeLast() }
            let run = severities.reversed().prefix { $0 > 0 }.count
            if run > best.1 { best = (flow.symptom, run) }
        }
        return best
    }
}
