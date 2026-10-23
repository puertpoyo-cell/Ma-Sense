import Foundation
import SwiftData

/// 미리보기·스토어 스크린샷용 예시 데이터.
/// 약물명·용량 수치·메모 없음 (COMPLIANCE.md 6 "스크린샷에 약물명·용량 수치 노출 없음").
/// 실행 인자 `-seedSampleData`를 주면 DEBUG 빌드에서 빈 저장소에 채운다 (MasenseApp).
@MainActor
enum SampleData {
    static func seed(into context: ModelContext, now: Date = Date(), calendar: Calendar = .current) throws {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(offset)) ?? today
        }

        let settings = try UserSettings.current(in: context)
        settings.hasAcceptedRoleNotice = true
        settings.hasConfirmedAdult = true
        settings.proteinTargetGrams = 90
        settings.heightCm = 172

        // 다음 투약은 내일(D-1, 마디 구간 안이라 미리 기록 버튼도 보임), 진료 5일 뒤, 7주째 처방.
        // 이전 마디에 기록이 있으면 예정 이틀 전까지는 "이번 마디 기록 완료"로 보이므로 D-1로 둔다 (R1·R2)
        let prescription = Prescription(
            startDate: day(-45),
            penCount: 3,
            dosesPerPen: 4,
            scheduledWeekday: calendar.component(.weekday, from: day(1)),
            scheduledHour: 20,
            nextClinicDate: day(5)
        )
        try Prescription.activate(prescription, in: context)

        let sites: [BodySite] = [.abdomenUpperLeft, .abdomenUpperRight, .thighLeft, .thighRight, .abdomenLowerLeft, .abdomenLowerRight]
        let cycles = CycleRules.cycles(for: prescription.snapshot, doses: [], now: now, until: now, calendar: calendar)
        var sequence = 1
        for cycle in cycles {
            let administered = cycle.scheduledDate.addingTimeInterval(30 * 60)
            // 세 번째 마디는 기록 없음 (기록 탭·리포트의 누락 표시 예시)
            guard cycle.index != 2, administered < now else { continue }
            let dose = Dose(administeredAt: administered, scheduledFor: cycle.scheduledDate, site: sites[cycle.index % sites.count], sequence: sequence)
            sequence += 1
            context.insert(dose)
            dose.prescription = prescription

            let h24 = ConditionCheck(
                checkedAt: administered.addingTimeInterval(20 * 3_600),
                window: .h24,
                symptoms: cycle.index % 2 == 0
                    ? [SymptomEntry(symptom: .nausea, severity: 1)]
                    : [SymptomEntry(symptom: .constipation, severity: 2), SymptomEntry(symptom: .fatigue, severity: 1)],
                appetite: cycle.index % 3 == 0 ? .reduced : .normal
            )
            context.insert(h24)
            h24.dose = dose
            let h48 = ConditionCheck(checkedAt: administered.addingTimeInterval(44 * 3_600), window: .h48)
            context.insert(h48)
            h48.dose = dose
        }

        // 체중: 3일 간격, 주 0.5kg 안팎의 완만한 변화 (감량 속도 안내가 뜨지 않는 범위)
        for offset in stride(from: -42, through: 0, by: 3) {
            let kilograms = 81.0 - Double(offset + 42) * 0.07
            context.insert(WeightSample(measuredAt: at(offset, 7, 30), kilograms: (kilograms * 10).rounded() / 10, source: .manual))
        }

        // 단백질: 최근 3일
        for offset in -2...0 {
            context.insert(ProteinEntry(date: day(offset), meal: .breakfast, foods: [.egg, .egg, .greekYogurt], estimatedGrams: 27))
            context.insert(ProteinEntry(date: day(offset), meal: .lunch, foods: [.chickenBreast], estimatedGrams: 23))
            if offset < 0 {
                context.insert(ProteinEntry(date: day(offset), meal: .dinner, foods: [.fish, .tofu], estimatedGrams: 32))
            }
        }

        // 운동
        context.insert(StrengthSession(startedAt: at(-1, 7), durationMinutes: 20, kind: .strength))
        context.insert(StrengthSession(startedAt: at(-2, 19), durationMinutes: 30, kind: .walk, intensity: .light))
        context.insert(StrengthSession(startedAt: at(-4, 7), durationMinutes: 20, kind: .strength))

        context.insert(HabitCheck(date: today, water: true, fiber: false, sleep: true))
        try context.save()
    }
}

extension ModelContainer {
    /// 예시 데이터가 들어간 미리보기용 in-memory 컨테이너
    @MainActor
    static var previewWithSampleData: ModelContainer {
        let container = preview
        try? SampleData.seed(into: container.mainContext)
        return container
    }
}
