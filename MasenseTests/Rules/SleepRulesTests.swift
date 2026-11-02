import Foundation
import Testing

@testable import Masense

// D37 잠 흐름 (R29)
struct SleepRulesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func nightMergesOverlapsCountsAwakeningsAndBelongsToWakeDay() {
        let segments = [
            SleepSegment(start: at(1, 23), end: at(2, 1), stage: .asleep),
            // 다른 앱의 겹치는 기록
            SleepSegment(start: at(2, 0, 30), end: at(2, 1, 2), stage: .asleep),
            // 1:02~1:20 깨어 있음 (18분)
            SleepSegment(start: at(2, 1, 20), end: at(2, 4, 30), stage: .asleep),
            // 3분 틈은 깨어남으로 세지 않는다
            SleepSegment(start: at(2, 4, 33), end: at(2, 5), stage: .asleep),
            SleepSegment(start: at(1, 22, 30), end: at(2, 5, 10), stage: .inBed),
        ]
        let nights = SleepRules.nights(from: segments, calendar: calendar)
        #expect(nights.count == 1)
        let night = nights[0]
        #expect(night.day == calendar.startOfDay(for: at(2, 12)))
        #expect(night.asleepMinutes == 122 + 190 + 27)
        #expect(night.awakenings == 1)
        #expect(night.bedtime == at(1, 23))
        #expect(night.wakeTime == at(2, 5))
    }

    @Test func napIsSeparateAndLongerSleepWinsTheDay() {
        let segments = [
            SleepSegment(start: at(1, 23), end: at(2, 6), stage: .asleep),
            SleepSegment(start: at(2, 14), end: at(2, 15), stage: .asleep),
        ]
        let nights = SleepRules.nights(from: segments, calendar: calendar)
        #expect(nights.count == 1)
        #expect(nights[0].asleepMinutes == 420)
    }

    @Test func inBedIsUsedWhenNoAsleepData() {
        let nights = SleepRules.nights(from: [SleepSegment(start: at(1, 23), end: at(2, 6), stage: .inBed)], calendar: calendar)
        #expect(nights.first?.asleepMinutes == 420)
        #expect(SleepRules.nights(from: [], calendar: calendar).isEmpty)
    }

    @Test func flowGroupsByDaysSinceDose() {
        let night = { (day: Int, wakeHour: Int, minutes: Int, awakenings: Int) in
            SleepNight(day: calendar.startOfDay(for: at(day, 12)), asleepMinutes: minutes, awakenings: awakenings,
                       bedtime: at(day - 1, 23), wakeTime: at(day, wakeHour))
        }
        let nights = [
            night(2, 4, 300, 2),   // 투약일(2일) 아침에 깬 밤 → 0일째
            night(3, 5, 360, 1),   // 1일째
            night(9, 6, 420, 0),   // 9일 투약 → 0일째
            night(1, 7, 480, 0),   // 투약 전 → 넣지 않음
        ]
        let flow = SleepRules.flow(nights: nights, doseDates: [at(2, 20), at(9, 21)], calendar: calendar)
        #expect(flow.count == 7)
        #expect(flow[0].nights == 2)
        #expect(flow[0].averageAsleepMinutes == 360)
        #expect(flow[0].averageAwakenings == 1)
        #expect(flow[0].averageWakeMinute == 5 * 60)
        #expect(flow[1].nights == 1)
        #expect(flow[1].averageWakeMinute == 5 * 60)
        #expect(flow[2].nights == 0 && flow[2].averageAsleepMinutes == nil)
    }

    @Test func summaryAveragesAndPeriodFilter() {
        let a = SleepNight(day: at(2, 0), asleepMinutes: 300, awakenings: 1, bedtime: at(1, 23), wakeTime: at(2, 4, 30))
        let b = SleepNight(day: at(3, 0), asleepMinutes: 401, awakenings: 2, bedtime: at(2, 23), wakeTime: at(3, 6))
        let summary = SleepRules.summary([a, b], calendar: calendar)
        #expect(summary == SleepSummary(nights: 2, averageAsleepMinutes: 351, averageAwakenings: 1.5, averageWakeMinute: 315))
        #expect(SleepRules.summary([], calendar: calendar) == nil)
        #expect(SleepRules.nights([a, b], in: DateInterval(start: at(3, 0), end: at(4, 0))) == [b])
    }
}
