import Foundation
import Observation
import SwiftData

/// S2 투약 기록 폼. 과거 시각도 받아서 누락을 해제할 수 있다 (R3).
@Observable
final class DoseLogModel {
    var administeredAt: Date
    var site: BodySite?
    /// 처방 내 회차 (1부터). 자동 계산, 사용자가 고칠 수 있다
    var sequence: Int
    var note: String = ""

    /// 시트를 연 시각. 이보다 미래는 고를 수 없다
    let openedAt: Date
    /// 바디맵 최근 사용 부위 (R6)
    let history: [SiteUse]
    /// 바디맵 구역 날짜·부위별 목록 (R6)
    let lastUseBySite: [BodySite: Date]
    /// 화면 위 "지난 투약" 안내. 사실만, 추천 없음 (R6)
    let lastDoseNote: LastDoseNote?
    let dosesPerPen: Int
    let totalDoses: Int

    let prescription: Prescription
    private let calendar: Calendar

    /// `initialDate`: 기록 탭의 누락 마디에서 열면 그 예정일로 시작한다 (R3 누락 해제)
    init(prescription: Prescription, initialDate: Date? = nil, now: Date = Date(), calendar: Calendar = .current) {
        let doses = prescription.doseSnapshots
        self.prescription = prescription
        self.calendar = calendar
        openedAt = now
        // D25: 30분 단위. 기본은 지금을 내림한 가장 최근 30분, 누락 마디에서 열면 그 예정일
        administeredAt = DoseTimeRules.initialTime(initialDate: initialDate, now: now, calendar: calendar)
        sequence = PrescriptionRules.nextSequence(doses: doses)
        // 부위는 몸 기준이라 이전 처방의 기록도 함께 본다
        let allDoses = (try? prescription.modelContext?.fetch(FetchDescriptor<Dose>())).map { $0.map(\.snapshot) } ?? doses
        history = SiteRules.siteHistory(doses: allDoses)
        lastUseBySite = SiteRules.lastUseBySite(doses: allDoses)
        lastDoseNote = SiteRules.lastDoseNote(doses: allDoses, now: now, calendar: calendar)
        dosesPerPen = prescription.dosesPerPen
        totalDoses = prescription.totalDoses
    }

    var canSave: Bool { site != nil && sequence >= 1 }

    /// D45 예정일과 며칠 차이 (+ 늦게, - 일찍). 같은 날이거나 마디 밖이면 nil
    var scheduleOffset: Int? {
        let offset = ScheduleShiftRules.dayOffset(administeredAt: administeredAt, prescription: prescription.snapshot, doses: prescription.doseSnapshots, calendar: calendar)
        return offset == 0 ? nil : offset
    }

    /// D45 이 기록을 넣고 투약 요일을 그날로 옮긴 처방 (시각은 그대로)
    func shiftedSchedule(including dose: DoseSnapshot? = nil) -> PrescriptionSnapshot {
        let doses = prescription.doseSnapshots + (dose.map { [$0] } ?? [])
        return ScheduleShiftRules.shifted(
            prescription.snapshot, doses: doses,
            weekday: calendar.component(.weekday, from: administeredAt),
            hour: prescription.scheduledHour, minute: prescription.scheduledMinute,
            anchor: administeredAt, calendar: calendar
        )
    }

    /// 저장한 뒤에도 옮길 이유가 남아 있는지 (저장 전에 계산한 차이를 그대로 쓴다)
    func scheduleOffsetAfterSave(_ dose: Dose) -> Int {
        calendar.component(.weekday, from: dose.administeredAt) == prescription.scheduledWeekday ? 0 : 1
    }

    /// D45 켰을 때 다음 예정 일시 (지금 기록하는 것까지 넣어서)
    var shiftPreview: Date? {
        let pending = DoseSnapshot(administeredAt: administeredAt, scheduledFor: administeredAt, site: site, sequence: sequence)
        return ScheduleShiftRules.upcoming(shiftedSchedule(including: pending), doses: prescription.doseSnapshots + [pending], now: max(openedAt, administeredAt), calendar: calendar)
    }

    var penPosition: (pen: Int, position: Int) {
        PrescriptionRules.penPosition(sequence: sequence, dosesPerPen: dosesPerPen)
    }

    @discardableResult
    func save(in context: ModelContext) throws -> Dose? {
        guard let site, canSave else { return nil }
        let doses = prescription.doseSnapshots
        let cycles = CycleRules.cycles(
            for: prescription.snapshot,
            doses: doses,
            now: openedAt,
            until: .distantFuture,
            calendar: calendar
        )
        // 투약 시각이 속한 마디의 예정일. 어느 마디에도 없으면 투약 시각 그대로
        let scheduledFor = CycleRules.cycle(containing: administeredAt, in: cycles)?.scheduledDate ?? administeredAt
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let dose = Dose(
            administeredAt: administeredAt,
            scheduledFor: scheduledFor,
            site: site,
            sequence: sequence,
            note: trimmed.isEmpty ? nil : trimmed
        )
        context.insert(dose)
        dose.prescription = prescription
        try context.save()
        return dose
    }
}
