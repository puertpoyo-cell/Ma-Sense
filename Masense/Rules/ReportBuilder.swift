import Foundation

/// 진료 전 리포트 한 장의 데이터 (REPORT_SPEC.md "데이터 → 렌더 계약").
/// 뷰는 이것만 받아 그리고 계산하지 않는다. 숫자 포맷(소수 1자리, 부호)도 여기서 끝낸다.
struct ClinicReport: Equatable {
    /// B. 요약 4칸. 수치만, 판단 없음
    struct Summary: Equatable {
        let dosesTaken: Int
        let dosesScheduled: Int
        let missedCount: Int
        /// 기간 시작 대비 체중 변화. 부호 그대로 ("-3.2", "+0.4", "0.0"). 샘플 2개 미만이면 nil
        let weightChangeText: String?
        let weightStartText: String?
        let weightEndText: String?
        let checksAnswered: Int
        let checksExpected: Int
        let remainingDoses: Int
        let exhaustionDate: Date?
    }

    /// C. 투약 타임라인 한 칸 (마디)
    struct CycleCell: Equatable, Identifiable {
        enum State: Equatable {
            /// `offsetText`: 예정일과 실제일이 2일 이상 차이 나면 "+2d" / "-2d"
            case recorded(date: Date, site: BodySite, sequence: Int, offsetText: String?)
            case missed
            /// 진행 중인 마디, 아직 기록 없음
            case pending
        }

        let id: String
        let scheduledDate: Date
        let state: State
    }

    enum WeightSourceNote: Equatable {
        case none, healthKit, manual, mixed
    }

    /// E. 증상별 빈도
    struct SymptomRow: Equatable, Identifiable {
        enum Timing: Equatable {
            case h24, h48, both
        }

        let symptom: Symptom
        let count: Int
        let maxSeverity: Int
        let timing: Timing
        var id: Symptom { symptom }
        /// 심각도 3이 있던 증상은 굵게 (색 아님)
        var isSevere: Bool { maxSeverity >= 3 }
    }

    struct AppetiteSummary: Equatable {
        let reduced: Int
        let veryReduced: Int
    }

    /// G. 메모 발췌 한 줄
    struct NoteLine: Equatable, Identifiable {
        let id: String
        let date: Date
        let text: String
    }

    /// F. 감량의 질 (M2). M1에서는 항상 nil이라 섹션을 그리지 않는다
    struct QualitySection: Equatable {}

    let period: DateInterval
    let weeks: Int
    let summary: Summary
    let cycles: [CycleCell]
    let weight: [WeekPoint]
    let weightDoseTicks: [Date]
    let weightSource: WeightSourceNote
    let symptoms: [SymptomRow]
    let appetite: AppetiteSummary
    let quality: QualitySection?
    let notes: [NoteLine]
    let generatedAt: Date
    let appVersion: String
}

/// R12 리포트 기간 선택지
enum ReportPeriod: Hashable {
    /// 직전 진료 이후 = 현재 처방 시작일부터 오늘까지
    case sinceClinic
    case weeks(Int)

    static let weekChoices = [4, 8, 12]
    static let fallbackWeeks = 8
}

enum ReportBuilder {
    /// C 타임라인 최대 칸 수
    static let maxCells = 12
    /// G 메모 최대 줄 수와 줄당 글자 수
    static let maxNotes = 5
    static let noteLength = 60
    /// 예정일과 실제일 차이 표시 기준 (일)
    static let offsetThresholdDays = 2

    struct PrescriptionData {
        let prescription: PrescriptionSnapshot
        let doses: [DoseSnapshot]
        let isActive: Bool
    }

    // MARK: R12 기간

    /// 다음 진료일이 있으면 "직전 진료 이후", 없으면 최근 8주
    static func defaultPeriod(hasNextClinicDate: Bool) -> ReportPeriod {
        hasNextClinicDate ? .sinceClinic : .weeks(ReportPeriod.fallbackWeeks)
    }

    static func interval(
        for choice: ReportPeriod,
        activePrescriptionStart: Date?,
        now: Date,
        calendar: Calendar
    ) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        switch choice {
        case .sinceClinic:
            if let start = activePrescriptionStart.map({ calendar.startOfDay(for: $0) }), start <= now {
                return DateInterval(start: start, end: now)
            }
            return interval(for: .weeks(ReportPeriod.fallbackWeeks), activePrescriptionStart: nil, now: now, calendar: calendar)
        case let .weeks(count):
            // 오늘을 포함해 7 × count 일
            let start = calendar.date(byAdding: .day, value: -(7 * max(count, 1)) + 1, to: today) ?? today
            return DateInterval(start: start, end: now)
        }
    }

    /// 기간을 덮는 주 수 (올림)
    static func weekCount(of period: DateInterval, calendar: Calendar) -> Int {
        let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: period.start), to: calendar.startOfDay(for: period.end)).day ?? 0) + 1
        return max(1, Int((Double(days) / 7).rounded(.up)))
    }

    // MARK: 생성

    static func build(
        period: DateInterval,
        prescriptions: [PrescriptionData],
        checks: [ConditionCheckSnapshot],
        weights: [WeightSampleSnapshot],
        now: Date,
        calendar: Calendar,
        appVersion: String
    ) -> ClinicReport {
        let inPeriod = { (date: Date) in date >= period.start && date <= period.end }
        let ordered = prescriptions.sorted { $0.prescription.startDate < $1.prescription.startDate }
        let allDoses = ordered.flatMap(\.doses)
        let activeDoses = allDoses.filter { !$0.isCancelled }
        let periodDoses = activeDoses.filter { inPeriod($0.administeredAt) }

        // C. 마디 칸
        var cells: [ClinicReport.CycleCell] = []
        for (offset, data) in ordered.enumerated() {
            let nextStart = offset + 1 < ordered.count ? ordered[offset + 1].prescription.startDate : nil
            let cycles = CycleRules.pastCycles(for: data.prescription, doses: data.doses, nextStart: nextStart, now: now, calendar: calendar)
            for cycle in cycles where inPeriod(cycle.scheduledDate) {
                let state: ClinicReport.CycleCell.State
                if let dose = CycleRules.doses(in: cycle, from: data.doses).first {
                    state = .recorded(
                        date: dose.administeredAt,
                        site: dose.site,
                        sequence: dose.sequence,
                        offsetText: offsetText(scheduled: cycle.scheduledDate, actual: dose.administeredAt, calendar: calendar)
                    )
                } else if cycle.interval.end <= now {
                    state = .missed
                } else {
                    state = .pending
                }
                cells.append(ClinicReport.CycleCell(id: "\(offset).\(cycle.index)", scheduledDate: cycle.scheduledDate, state: state))
            }
        }
        cells.sort { $0.scheduledDate < $1.scheduledDate }
        let missedCount = cells.filter { $0.state == .missed }.count
        let shownCells = Array(cells.suffix(maxCells))

        // B. 컨디션 체크 응답: 기간 안 투약 중 창이 열린 것만 분모
        let periodDoseIDs = Set(periodDoses.map(\.id))
        let periodChecks = checks.filter { periodDoseIDs.contains($0.doseID) }
        var expected = 0
        var answered = 0
        for dose in periodDoses {
            for window in ConditionWindow.allCases {
                let opensAt = dose.administeredAt.addingTimeInterval(openOffset(window))
                guard opensAt <= now else { continue }
                expected += 1
                if periodChecks.contains(where: { $0.doseID == dose.id && $0.window == window }) {
                    answered += 1
                }
            }
        }

        // B. 체중, D. 체중 추이
        let periodWeights = weights.filter { inPeriod($0.measuredAt) }.sorted { $0.measuredAt < $1.measuredAt }
        let first = periodWeights.first
        let last = periodWeights.last
        let change: String? = periodWeights.count >= 2 && first != nil && last != nil
            ? signedKilograms(last!.kilograms - first!.kilograms)
            : nil
        let weeks = weekCount(of: period, calendar: calendar)
        let series = WeightRules.weeklyWeightSeries(samples: weights, weeks: weeks, now: period.end, calendar: calendar)
        let hasHealth = periodWeights.contains { $0.source == .healthKit }
        let hasManual = periodWeights.contains { $0.source == .manual }
        let source: ClinicReport.WeightSourceNote = hasHealth ? (hasManual ? .mixed : .healthKit) : (hasManual ? .manual : .none)

        // B. 남은 회차 (현재 처방)
        let active = ordered.last { $0.isActive }
        let remaining = active.map { PrescriptionRules.remainingDoses(p: $0.prescription, doses: $0.doses) } ?? 0
        let exhaustion = active.flatMap {
            PrescriptionRules.exhaustionEstimate(p: $0.prescription, doses: $0.doses, now: now, calendar: calendar)
        }

        return ClinicReport(
            period: period,
            weeks: weeks,
            summary: ClinicReport.Summary(
                dosesTaken: periodDoses.count,
                dosesScheduled: cells.count,
                missedCount: missedCount,
                weightChangeText: change,
                weightStartText: first.map { kilograms($0.kilograms) },
                weightEndText: last.map { kilograms($0.kilograms) },
                checksAnswered: answered,
                checksExpected: expected,
                remainingDoses: remaining,
                exhaustionDate: exhaustion
            ),
            cycles: shownCells,
            weight: series,
            weightDoseTicks: periodDoses.map(\.administeredAt).sorted(),
            weightSource: source,
            symptoms: symptomRows(periodChecks),
            appetite: ClinicReport.AppetiteSummary(
                reduced: periodChecks.filter { $0.appetite == .reduced }.count,
                veryReduced: periodChecks.filter { $0.appetite == .veryReduced }.count
            ),
            quality: nil,
            notes: noteLines(doses: periodDoses, checks: periodChecks.filter { inPeriod($0.checkedAt) }),
            generatedAt: now,
            appVersion: appVersion
        )
    }

    // MARK: 세부

    static func symptomRows(_ checks: [ConditionCheckSnapshot]) -> [ClinicReport.SymptomRow] {
        let order = Dictionary(uniqueKeysWithValues: Symptom.allCases.enumerated().map { ($1, $0) })
        var rows: [ClinicReport.SymptomRow] = []
        for symptom in Symptom.allCases {
            var count24 = 0
            var count48 = 0
            var maxSeverity = 0
            for check in checks {
                for entry in check.symptoms where entry.symptom == symptom && entry.severity > 0 {
                    if check.window == .h24 { count24 += 1 } else { count48 += 1 }
                    maxSeverity = max(maxSeverity, entry.severity)
                }
            }
            let count = count24 + count48
            // 발생 0인 증상은 숨긴다
            guard count > 0 else { continue }
            let timing: ClinicReport.SymptomRow.Timing = count24 > count48 ? .h24 : (count48 > count24 ? .h48 : .both)
            rows.append(ClinicReport.SymptomRow(symptom: symptom, count: count, maxSeverity: maxSeverity, timing: timing))
        }
        return rows.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return (order[$0.symptom] ?? 0) < (order[$1.symptom] ?? 0)
        }
    }

    /// 비어 있지 않은 투약·컨디션 메모 최근 5개, 60자에서 자른다
    static func noteLines(doses: [DoseSnapshot], checks: [ConditionCheckSnapshot]) -> [ClinicReport.NoteLine] {
        let doseNotes = doses.compactMap { dose -> ClinicReport.NoteLine? in
            guard let text = trimmed(dose.note) else { return nil }
            return ClinicReport.NoteLine(id: "dose.\(dose.id.uuidString)", date: dose.administeredAt, text: truncated(text))
        }
        let checkNotes = checks.compactMap { check -> ClinicReport.NoteLine? in
            guard let text = trimmed(check.note) else { return nil }
            return ClinicReport.NoteLine(
                id: "check.\(check.doseID.uuidString).\(check.window.rawValue).\(check.checkedAt.timeIntervalSinceReferenceDate)",
                date: check.checkedAt,
                text: truncated(text)
            )
        }
        return Array((doseNotes + checkNotes).sorted { $0.date > $1.date }.prefix(maxNotes))
    }

    static func offsetText(scheduled: Date, actual: Date, calendar: Calendar) -> String? {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: scheduled), to: calendar.startOfDay(for: actual)).day ?? 0
        guard abs(days) >= offsetThresholdDays else { return nil }
        return days > 0 ? "+\(days)d" : "\(days)d"
    }

    /// 소수 1자리, 부호 그대로. 반올림해서 0이면 부호 없이 "0.0"
    static func signedKilograms(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == 0 { return "0.0" }
        return String(format: "%+.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }

    static func kilograms(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), (value * 10).rounded() / 10)
    }

    private static func trimmed(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        // 한 줄로 표시하므로 줄바꿈은 공백으로
        return text.replacingOccurrences(of: "\n", with: " ")
    }

    private static func truncated(_ text: String) -> String {
        text.count > noteLength ? String(text.prefix(noteLength)) + "…" : text
    }

    private static func openOffset(_ window: ConditionWindow) -> TimeInterval {
        switch window {
        case .h24: return ConditionRules.h24Window.lowerBound
        case .h48: return ConditionRules.h48Window.lowerBound
        }
    }
}
