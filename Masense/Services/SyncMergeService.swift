import Foundation
import SwiftData

/// iCloud로 받은 기록과 이 기기 기록 사이의 중복을 정리한다 (D26, `SyncMergeRules`).
/// - 설정: 하나만 남기고, 켜진 확인(역할·연령·구매·건강 앱)은 어느 쪽이든 켜져 있으면 켬, 빈 값은 다른 쪽 값으로 채움
/// - 처방: 같은 처방이면 투약 기록을 남는 쪽으로 옮긴 뒤 지움 → 그다음 같은 투약은 컨디션 체크를 옮기고 지움
/// - 습관: 같은 날이면 체크를 합치고 메모를 이음
/// - 건강 앱에서 가져온 체중·운동: 같은 건강 앱 기록(UUID)이면 하나만
/// 단백질·컨디션·진료처럼 한 기기에서만 만드는 기록은 iCloud가 그대로 옮기므로 건드리지 않는다
@MainActor
enum SyncMergeService {
    /// 무엇이든 정리했으면 true. 저장은 부른 쪽이 아니라 여기서 한다
    @discardableResult
    static func mergeDuplicates(context: ModelContext, calendar: Calendar = .current) throws -> Bool {
        var changed = false
        changed = try mergeSettings(context) || changed
        changed = try mergePrescriptions(context, calendar: calendar) || changed
        changed = try mergeDoses(context) || changed
        changed = try mergeHabits(context, calendar: calendar) || changed
        changed = try mergeHealthImports(context) || changed
        if changed { try context.save() }
        return changed
    }

    private static func mergeSettings(_ context: ModelContext) throws -> Bool {
        let all = try context.fetch(FetchDescriptor<UserSettings>())
        let plan = SyncMergeRules.duplicates(all.map { SyncMergeRules.Item(id: $0.id, key: 0, createdAt: $0.createdAt) })
        guard !plan.isEmpty else { return false }
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (removedID, keptID) in plan {
            guard let removed = byID[removedID], let kept = byID[keptID] else { continue }
            kept.hasAcceptedRoleNotice = kept.hasAcceptedRoleNotice || removed.hasAcceptedRoleNotice
            kept.hasConfirmedAdult = kept.hasConfirmedAdult || removed.hasConfirmedAdult
            kept.hasPurchasedPro = kept.hasPurchasedPro || removed.hasPurchasedPro
            kept.healthKitAuthorized = kept.healthKitAuthorized || removed.healthKitAuthorized
            kept.proteinTargetGrams = kept.proteinTargetGrams ?? removed.proteinTargetGrams
            kept.bodyWeightForGuideKg = kept.bodyWeightForGuideKg ?? removed.bodyWeightForGuideKg
            kept.heightCm = kept.heightCm ?? removed.heightCm
            kept.reportDefaultPeriod = kept.reportDefaultPeriod ?? removed.reportDefaultPeriod
            kept.weightReminderWeekday = kept.weightReminderWeekday ?? removed.weightReminderWeekday
            context.delete(removed)
        }
        return true
    }

    private static func mergePrescriptions(_ context: ModelContext, calendar: Calendar) throws -> Bool {
        let all = try context.fetch(FetchDescriptor<Prescription>())
        let plan = SyncMergeRules.duplicates(all.map { p in
            SyncMergeRules.Item(
                id: p.id,
                key: SyncMergeRules.PrescriptionKey(
                    startDay: calendar.startOfDay(for: p.startDate),
                    weekday: p.scheduledWeekday,
                    hour: p.scheduledHour,
                    minute: p.scheduledMinute,
                    penCount: p.penCount,
                    dosesPerPen: p.dosesPerPen,
                    intervalDays: p.intervalDays
                ),
                createdAt: p.createdAt
            )
        })
        guard !plan.isEmpty else { return false }
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (removedID, keptID) in plan {
            guard let removed = byID[removedID], let kept = byID[keptID] else { continue }
            // 지우는 처방의 투약을 먼저 옮긴다 (처방 삭제는 투약까지 지우므로)
            let moving = removed.doses
            for dose in moving { dose.prescription = kept }
            removed.doses = []
            kept.nextClinicDate = kept.nextClinicDate ?? removed.nextClinicDate
            kept.doseLabel = kept.doseLabel ?? removed.doseLabel
            kept.endDate = kept.endDate ?? removed.endDate
            context.delete(removed)
        }
        return true
    }

    private static func mergeDoses(_ context: ModelContext) throws -> Bool {
        let all = try context.fetch(FetchDescriptor<Dose>())
        let plan = SyncMergeRules.duplicates(all.map { d in
            SyncMergeRules.Item(
                id: d.id,
                key: SyncMergeRules.DoseKey(
                    prescriptionID: d.prescription?.id,
                    administeredAt: d.administeredAt,
                    site: d.siteRaw,
                    isCancelled: d.isCancelled
                ),
                createdAt: d.createdAt
            )
        })
        guard !plan.isEmpty else { return false }
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (removedID, keptID) in plan {
            guard let removed = byID[removedID], let kept = byID[keptID] else { continue }
            let moving = removed.conditionChecks
            for check in moving { check.dose = kept }
            removed.conditionChecks = []
            kept.note = kept.note ?? removed.note
            context.delete(removed)
        }
        return true
    }

    private static func mergeHabits(_ context: ModelContext, calendar: Calendar) throws -> Bool {
        let all = try context.fetch(FetchDescriptor<HabitCheck>())
        let plan = SyncMergeRules.duplicates(all.map { SyncMergeRules.Item(id: $0.id, key: calendar.startOfDay(for: $0.date), createdAt: $0.createdAt) })
        guard !plan.isEmpty else { return false }
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (removedID, keptID) in plan {
            guard let removed = byID[removedID], let kept = byID[keptID] else { continue }
            kept.water = kept.water || removed.water
            kept.fiber = kept.fiber || removed.fiber
            kept.sleep = kept.sleep || removed.sleep
            kept.note = SyncMergeRules.mergedNote(kept.note, removed.note)
            context.delete(removed)
        }
        return true
    }

    private static func mergeHealthImports(_ context: ModelContext) throws -> Bool {
        let weights = try context.fetch(FetchDescriptor<WeightSample>())
        let weightPlan = SyncMergeRules.duplicates(weights.compactMap { w in
            w.healthKitUUID.map { SyncMergeRules.Item(id: w.id, key: $0, createdAt: w.createdAt) }
        })
        for sample in weights where weightPlan[sample.id] != nil { context.delete(sample) }

        let sessions = try context.fetch(FetchDescriptor<StrengthSession>())
        let sessionPlan = SyncMergeRules.duplicates(sessions.compactMap { s in
            s.healthKitUUID.map { SyncMergeRules.Item(id: s.id, key: $0, createdAt: s.createdAt) }
        })
        for session in sessions where sessionPlan[session.id] != nil { context.delete(session) }
        return !weightPlan.isEmpty || !sessionPlan.isEmpty
    }
}
