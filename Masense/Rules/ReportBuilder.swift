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
        /// 기간 안 처방 전환 횟수 (R13). 0이면 표시하지 않는다
        var prescriptionTransitions: Int = 0
        /// 기간 첫·마지막 체중의 BMI (R14). 키가 없으면 nil. 숫자만, 구간 이름 없음
        var bmiStartText: String?
        var bmiEndText: String?
    }

    /// C. 투약 타임라인 한 칸 (마디)
    struct CycleCell: Equatable, Identifiable {
        enum State: Equatable {
            /// `offsetText`: 예정일과 실제일이 2일 이상 차이 나면 "+2d" / "-2d"
            /// `site` nil = 부위 기록 없음 (D6)
            case recorded(date: Date, site: BodySite?, sequence: Int, offsetText: String?)
            case missed
            /// 진행 중인 마디, 아직 기록 없음
            case pending
        }

        /// 처방 전환 표시 (R13, REPORT_SPEC C). 기간 안에 전환이 있을 때만 붙는다
        enum Marker: Equatable {
            /// 첫 칸: 기간 시작 시점의 처방
            case periodStart(label: String?)
            /// 이 칸부터 새 처방
            case change(label: String?, date: Date)
        }

        let id: String
        let scheduledDate: Date
        let state: State
        var marker: Marker?
        /// 처방 구간 색 자리 (R13-2, D7). 처방 시작 순서대로, 용량·단계 의미 없음
        var colorSlot: Int = 0
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

    /// G. 진료 때 물어볼 것 한 줄 (D6, R15). 사용자가 적은 문장 그대로
    struct QuestionLine: Equatable, Identifiable {
        let id: UUID
        let text: String
    }

    /// "최근 검사" (D20). 항목별 가장 최근 숫자와 날짜만. 판단 없음
    struct LabLine: Equatable, Identifiable {
        let id: UUID
        let item: LabItem
        let customName: String?
        let valueText: String
        let unit: String
        let date: Date
    }

    /// F. 감량의 질 (M2). 기간 안에 단백질·운동·제지방량 기록이 하나도 없으면 nil이라 섹션을 그리지 않는다.
    /// "충분", "부족" 같은 평가어 없이 사실만
    struct QualitySection: Equatable {
        enum Protein: Equatable {
            /// 목표 입력 시: 채운 날 / 기간 일수
            case target(daysMet: Int, totalDays: Int)
            /// 목표 미입력: 기록한 날 수와 기록한 날의 평균 g
            case noTarget(recordedDays: Int, averageGrams: Int)
        }

        let protein: Protein?
        /// `.strength`만 센다 (걷기·스트레칭·쉬기 제외)
        let strengthCount: Int
        let leanMassStartText: String?
        let leanMassEndText: String?
    }

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
    /// G 위 "진료 때 물어볼 것" (D6). 비어 있으면 그리지 않는다
    var questions: [QuestionLine] = []
    /// G 위 "최근 검사" (D20). 비어 있으면 그리지 않는다
    var labs: [LabLine] = []
}

/// R12 리포트 기간 선택지
enum ReportPeriod: Hashable {
    /// 직전 진료 이후 = 현재 처방 시작일부터 오늘까지
    case sinceClinic
    case weeks(Int)

    static let weekChoices = [4, 8, 12]
    static let fallbackWeeks = 8
}

extension ReportPeriod {
    /// `UserSettings.reportDefaultPeriod`에 저장하는 값: "sinceClinic", "weeks4", "weeks8", "weeks12"
    var storageValue: String {
        switch self {
        case .sinceClinic: return "sinceClinic"
        case let .weeks(weeks): return "weeks\(weeks)"
        }
    }

    /// 저장 값 해석. 선택지(`weekChoices`)에 없는 주 수나 모르는 값은 nil
    init?(storageValue: String) {
        if storageValue == "sinceClinic" {
            self = .sinceClinic
        } else if storageValue.hasPrefix("weeks"), let weeks = Int(storageValue.dropFirst("weeks".count)),
                  ReportPeriod.weekChoices.contains(weeks) {
            self = .weeks(weeks)
        } else {
            return nil
        }
    }
}

enum ReportBuilder {
    /// C 타임라인 최대 칸 수
    static let maxCells = 12
    /// G 메모 최대 줄 수와 줄당 글자 수
    static let maxNotes = 5
    static let noteLength = 60
    /// G 진료 때 물어볼 것 최대 줄 수 (D6). 물어볼 것과 메모를 합쳐 `maxQuestionAndNoteLines`줄까지라 질문이 많으면 메모가 줄어든다
    static let maxQuestions = 5
    /// 최근 검사 항목 수 (두 칸 세 줄)
    static let maxLabs = 6
    static let maxQuestionAndNoteLines = 8
    /// 최근 검사 칸이 차지하는 줄 (제목 1 + 두 칸 세 줄). 검사가 있으면 물어볼 것·메모 줄을 그만큼 줄인다 (N-B1, 한 장 유지)
    static func labLineBudget(_ labCount: Int) -> Int {
        labCount == 0 ? 0 : 1 + (labCount + 1) / 2
    }
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

    /// 설정에 저장한 기본 기간이 있으면 그것, 없으면 위 기본값.
    /// "직전 진료 이후"는 활성 처방이 있을 때만 고를 수 있으므로, 없으면 위 기본값으로 돌아간다
    static func defaultPeriod(saved: ReportPeriod?, hasActivePrescription: Bool, hasNextClinicDate: Bool) -> ReportPeriod {
        switch saved {
        case .sinceClinic? where hasActivePrescription:
            return .sinceClinic
        case let .weeks(weeks)? where ReportPeriod.weekChoices.contains(weeks):
            return .weeks(weeks)
        default:
            return defaultPeriod(hasNextClinicDate: hasNextClinicDate)
        }
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
        proteins: [ProteinEntrySnapshot] = [],
        sessions: [StrengthSessionSnapshot] = [],
        proteinTarget: Int? = nil,
        heightCm: Double? = nil,
        questions: [ClinicQuestionSnapshot] = [],
        labs: [LabResultSnapshot] = [],
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
        let slots = PrescriptionRules.colorSlots(startDates: ordered.map(\.prescription.startDate))
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
                cells.append(ClinicReport.CycleCell(
                    id: "\(offset).\(cycle.index)",
                    scheduledDate: cycle.scheduledDate,
                    state: state,
                    colorSlot: slots[offset]
                ))
            }
        }
        cells.sort { $0.scheduledDate < $1.scheduledDate }
        let missedCount = cells.filter { $0.state == .missed }.count
        var shownCells = Array(cells.suffix(maxCells))

        // C. 처방 전환 (R13): 기간 안에 전환이 있을 때만 칸에 표시한다. 처방이 하나뿐이면 아무것도 붙이지 않는다
        let markers = PrescriptionRules.prescriptionTimeline(all: ordered.map(\.prescription), in: period, calendar: calendar)
        let transitions = PrescriptionRules.transitionCount(markers)
        if transitions > 0, let firstDate = shownCells.first?.scheduledDate {
            // 첫 칸에는 그 시점에 쓰던 처방. 보이는 칸(최근 12칸) 앞에서 바뀐 처방은 첫 칸의 표시가 대신한다
            let current = markers.last { $0.startDate <= firstDate } ?? markers[0]
            shownCells[0].marker = .periodStart(label: current.label)
            for marker in markers where marker.startDate > firstDate {
                // 새 처방이 시작된 뒤 첫 칸
                guard let index = shownCells.firstIndex(where: { $0.scheduledDate >= marker.startDate }) else { continue }
                shownCells[index].marker = .change(label: marker.label, date: marker.startDate)
            }
        }

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

        let labRows = labLines(labs, now: now)
        // 검사 칸이 있으면 물어볼 것·메모를 그만큼 줄여 한 장을 지킨다
        let textBudget = max(maxQuestionAndNoteLines - labLineBudget(labRows.count), 0)
        let questionRows = Array(Self.questionLines(questions, now: now).prefix(textBudget))
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
                exhaustionDate: exhaustion,
                prescriptionTransitions: transitions,
                bmiStartText: first.flatMap { WeightRules.bmi(kilograms: $0.kilograms, heightCm: heightCm) }.map { kilograms($0) },
                bmiEndText: last.flatMap { WeightRules.bmi(kilograms: $0.kilograms, heightCm: heightCm) }.map { kilograms($0) }
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
            quality: qualitySection(
                period: period,
                proteins: proteins,
                sessions: sessions,
                weights: weights,
                proteinTarget: proteinTarget,
                calendar: calendar
            ),
            notes: noteLines(
                doses: periodDoses,
                checks: periodChecks.filter { inPeriod($0.checkedAt) },
                limit: min(maxNotes, textBudget - questionRows.count)
            ),
            generatedAt: now,
            appVersion: appVersion,
            questions: questionRows,
            labs: labRows
        )
    }

    /// 항목별 가장 최근 값을 최근 검사일 순으로 6개까지. 기간과 무관하다 (진료 때 함께 보는 숫자)
    static func labLines(_ labs: [LabResultSnapshot], now: Date) -> [ClinicReport.LabLine] {
        LabRules.latestByItem(labs.filter { $0.measuredAt <= now }, limit: maxLabs).map {
            ClinicReport.LabLine(
                id: $0.id,
                item: $0.item,
                customName: $0.customName,
                valueText: $0.value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)),
                unit: $0.unit,
                date: $0.measuredAt
            )
        }
    }

    /// 아직 묻지 않은 것을 적은 순으로 5개까지, 60자에서 자른다 (R15). 기간과 무관하다 (다음 진료를 위한 것)
    static func questionLines(_ questions: [ClinicQuestionSnapshot], now: Date) -> [ClinicReport.QuestionLine] {
        ClinicQuestionRules.pending(questions)
            .filter { $0.createdAt <= now }
            .prefix(maxQuestions)
            .compactMap { question in
                trimmed(question.text).map { ClinicReport.QuestionLine(id: question.id, text: truncated($0)) }
            }
    }

    // MARK: 세부

    static func qualitySection(
        period: DateInterval,
        proteins: [ProteinEntrySnapshot],
        sessions: [StrengthSessionSnapshot],
        weights: [WeightSampleSnapshot],
        proteinTarget: Int?,
        calendar: Calendar
    ) -> ClinicReport.QualitySection? {
        let inPeriod = { (date: Date) in date >= calendar.startOfDay(for: period.start) && date <= period.end }
        let periodProteins = proteins.filter { inPeriod($0.date) }
        let periodSessions = sessions.filter { inPeriod($0.startedAt) }
        let leanSamples = weights
            .filter { inPeriod($0.measuredAt) && $0.leanBodyMassKg != nil }
            .sorted { $0.measuredAt < $1.measuredAt }
        guard !periodProteins.isEmpty || !periodSessions.isEmpty || !leanSamples.isEmpty else { return nil }

        var protein: ClinicReport.QualitySection.Protein?
        if !periodProteins.isEmpty {
            let dayTotals = Dictionary(grouping: periodProteins) { calendar.startOfDay(for: $0.date) }
                .mapValues { $0.reduce(0) { $0 + $1.estimatedGrams } }
            if let target = proteinTarget, target > 0 {
                let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: period.start), to: calendar.startOfDay(for: period.end)).day ?? 0) + 1
                protein = .target(daysMet: dayTotals.values.filter { $0 >= target }.count, totalDays: days)
            } else {
                let total = dayTotals.values.reduce(0, +)
                protein = .noTarget(recordedDays: dayTotals.count, averageGrams: Int((Double(total) / Double(dayTotals.count)).rounded()))
            }
        }

        return ClinicReport.QualitySection(
            protein: protein,
            strengthCount: periodSessions.filter { $0.kind == .strength }.count,
            leanMassStartText: leanSamples.first?.leanBodyMassKg.map(kilograms),
            leanMassEndText: leanSamples.last?.leanBodyMassKg.map(kilograms)
        )
    }

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

    /// 비어 있지 않은 투약·컨디션 메모 최근 `limit`개(기본 5), 60자에서 자른다
    static func noteLines(doses: [DoseSnapshot], checks: [ConditionCheckSnapshot], limit: Int = maxNotes) -> [ClinicReport.NoteLine] {
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
        return Array((doseNotes + checkNotes).sorted { $0.date > $1.date }.prefix(max(limit, 0)))
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
