import Foundation
import Observation
import SwiftData

/// S9 처방 입력 폼의 상태와 저장. 온보딩 0-3과 PrescriptionSheet가 함께 쓴다.
@Observable
final class PrescriptionFormModel {
    var startDate: Date
    /// 1(일)~7(토)
    var scheduledWeekday: Int
    /// 시·분만 쓴다
    var scheduledTime: Date
    var penCount: Int
    var dosesPerPen: Int
    var hasNextClinicDate: Bool
    var nextClinicDate: Date
    /// 자유 메모. 앱은 해석하지 않는다 (COMPLIANCE.md 2.2)
    var doseLabel: String

    let calendar: Calendar
    private let editing: Prescription?

    static let penCountRange = 1...20
    static let dosesPerPenRange = 1...8
    static let defaultHour = 20

    /// `editing`이 없으면 새 처방. 새 처방을 저장하면 이전 활성 처방은 보관된다.
    init(editing: Prescription? = nil, now: Date = Date(), calendar: Calendar = .current) {
        self.editing = editing
        self.calendar = calendar
        let today = calendar.startOfDay(for: now)
        let fourWeeksLater = calendar.date(byAdding: .day, value: 28, to: today) ?? today

        if let p = editing {
            startDate = p.startDate
            scheduledWeekday = p.scheduledWeekday
            scheduledTime = calendar.date(bySettingHour: p.scheduledHour, minute: p.scheduledMinute, second: 0, of: today) ?? today
            penCount = p.penCount
            dosesPerPen = p.dosesPerPen
            hasNextClinicDate = p.nextClinicDate != nil
            nextClinicDate = p.nextClinicDate ?? fourWeeksLater
            doseLabel = p.doseLabel ?? ""
        } else {
            startDate = today
            scheduledWeekday = calendar.component(.weekday, from: now)
            scheduledTime = calendar.date(bySettingHour: Self.defaultHour, minute: 0, second: 0, of: today) ?? today
            penCount = 1
            dosesPerPen = 4
            hasNextClinicDate = false
            nextClinicDate = fourWeeksLater
            doseLabel = ""
        }
    }

    var isEditing: Bool { editing != nil }

    var totalDoses: Int { penCount * dosesPerPen }

    var isValid: Bool {
        Self.penCountRange.contains(penCount) && Self.dosesPerPenRange.contains(dosesPerPen)
    }

    func weekdayName(_ weekday: Int) -> String {
        let symbols = calendar.weekdaySymbols
        guard (1...symbols.count).contains(weekday) else { return "" }
        return symbols[weekday - 1]
    }

    @discardableResult
    func save(in context: ModelContext) throws -> Prescription {
        let time = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        let hour = time.hour ?? Self.defaultHour
        let minute = time.minute ?? 0
        let trimmed = doseLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? nil : trimmed
        let clinic = hasNextClinicDate ? nextClinicDate : nil

        let prescription: Prescription
        if let editing {
            editing.startDate = startDate
            editing.scheduledWeekday = scheduledWeekday
            editing.scheduledHour = hour
            editing.scheduledMinute = minute
            editing.penCount = penCount
            editing.dosesPerPen = dosesPerPen
            editing.nextClinicDate = clinic
            editing.doseLabel = label
            prescription = editing
        } else {
            prescription = Prescription(
                startDate: startDate,
                penCount: penCount,
                dosesPerPen: dosesPerPen,
                scheduledWeekday: scheduledWeekday,
                scheduledHour: hour,
                scheduledMinute: minute,
                nextClinicDate: clinic,
                doseLabel: label
            )
            try Prescription.activate(prescription, in: context)
        }
        try context.save()
        return prescription
    }
}
