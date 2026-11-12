import Foundation
import SwiftData

/// D51 한 번에 투약 기록 (위젯 버튼·Siri·단축어). 부위 기록 없음으로 넣는다. 규칙은 `QuickLogRules`
@MainActor
enum QuickLogService {
    /// 지금 시각으로 기록한다. 결과를 그대로 돌려준다 (이미 기록했으면 넣지 않음)
    @discardableResult
    static func log(in context: ModelContext, at date: Date, calendar: Calendar) -> QuickLogOutcome {
        guard let prescription = try? Prescription.active(in: context) else { return .noPrescription }
        let outcome = QuickLogRules.outcome(prescription: prescription.snapshot, doses: prescription.doseSnapshots, at: date, calendar: calendar)
        guard case let .log(draft) = outcome else { return outcome }
        let dose = Dose(administeredAt: draft.administeredAt, scheduledFor: draft.scheduledFor, site: nil, sequence: draft.sequence)
        context.insert(dose)
        dose.prescription = prescription
        do {
            try context.save()
        } catch {
            context.delete(dose)
            return .noPrescription
        }
        return outcome
    }

    /// 위젯에서 눌러 둔 기록을 저장소에 넣고 비운다. 넣은 수를 돌려준다
    @discardableResult
    static func drain(in context: ModelContext, calendar: Calendar, queueURL: URL? = QuickLogQueue.fileURL) -> Int {
        let pending = QuickLogQueue.read(from: queueURL)
        guard !pending.isEmpty else { return 0 }
        var added = 0
        for date in pending {
            if case .log = log(in: context, at: date, calendar: calendar) { added += 1 }
        }
        QuickLogQueue.clear(at: queueURL)
        return added
    }

    // MARK: 대답 문구 (Siri·단축어)

    static func message(for outcome: QuickLogOutcome, calendar: Calendar = .current) -> String {
        switch outcome {
        case .noPrescription: return L10n.string("quickLog.noPrescription")
        case .exhausted: return L10n.string("quickLog.exhausted")
        case let .alreadyLogged(next):
            guard let next else { return L10n.string("quickLog.already") }
            return String(format: L10n.string("quickLog.already.next %@"), dayText(next))
        case .log: return L10n.string("quickLog.logged")
        }
    }

    /// "다음 투약 언제"의 대답. 사실만 (날짜·시각), 판단 없음
    static func nextDoseMessage(snapshot: WidgetSnapshot, now: Date, calendar: Calendar) -> String {
        if snapshot.phase == .done {
            guard let next = snapshot.scheduledDate else { return L10n.string("quickLog.exhausted") }
            return String(format: L10n.string("quickLog.next.done %@"), dayText(next))
        }
        switch snapshot.countdown(at: now, calendar: calendar) {
        case .noPrescription: return L10n.string("quickLog.noPrescription")
        case .exhausted: return L10n.string("quickLog.exhausted")
        case let .daysLeft(days, scheduled):
            return String(format: L10n.string("quickLog.next.daysLeft %@ %lld"), dayText(scheduled), days)
        case let .today(scheduled):
            return String(format: L10n.string("quickLog.next.today %@"), scheduled.formatted(.dateTime.hour().minute()))
        case let .overdue(_, scheduled):
            return String(format: L10n.string("quickLog.next.overdue %@"), dayText(scheduled))
        }
    }

    private static func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().weekday(.wide).hour().minute())
    }
}
