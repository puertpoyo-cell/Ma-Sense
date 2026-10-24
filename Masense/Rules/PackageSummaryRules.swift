import Foundation

/// 패키지 하나(4회, 약 한 달)의 기간 (R18, D9). 회차는 투약 시각 순으로 센다
struct PackagePeriod: Equatable {
    /// 1부터
    let number: Int
    /// 이 패키지의 첫·마지막 회차 (1부터)
    let firstSequence: Int
    let lastSequence: Int
    /// [첫 투약일 0시, 마지막 투약일 + 7일) — 다음 패키지 첫 투약일이 더 이르면 그날까지
    let period: DateInterval
}

/// 패키지 정리 한 장 (R18). 집계는 주간 정리(R16)와 같다
struct PackageSummary: Equatable, Identifiable {
    let package: PackagePeriod
    let summary: WeeklySummary

    var id: Int { package.number }
}

/// R18 (D9). 4회를 다 쓴 패키지마다 그 기간을 주간 정리와 같은 숫자로 묶는다. 평가·비교 없음
enum PackageSummaryRules {
    /// 오늘 카드는 패키지 기간이 끝난 뒤 이 일수 동안만
    static let recentDays = 7

    /// 4회를 다 쓰고 기간이 끝난 패키지, 최근 순 최대 `limit`개
    static func finishedPackages(doses: [DoseSnapshot], now: Date, calendar: Calendar, limit: Int = 12) -> [PackagePeriod] {
        let size = PrescriptionRules.dosesPerPackage
        let active = doses.filter { !$0.isCancelled }.sorted { $0.administeredAt < $1.administeredAt }
        guard limit > 0, size > 0 else { return [] }
        var result: [PackagePeriod] = []
        var index = 0
        while (index + 1) * size <= active.count {
            let first = active[index * size]
            let last = active[(index + 1) * size - 1]
            let start = calendar.startOfDay(for: first.administeredAt)
            let lastDay = calendar.startOfDay(for: last.administeredAt)
            guard var end = calendar.date(byAdding: .day, value: CycleRules.intervalDays, to: lastDay),
                  let minimumEnd = calendar.date(byAdding: .day, value: 1, to: lastDay)
            else { break }
            if (index + 1) * size < active.count {
                // 다음 패키지를 일찍 시작했으면 겹치지 않게 그 전날까지
                end = min(end, calendar.startOfDay(for: active[(index + 1) * size].administeredAt))
            }
            end = max(end, minimumEnd)
            guard end <= now else { break }
            result.append(PackagePeriod(
                number: index + 1,
                firstSequence: index * size + 1,
                lastSequence: (index + 1) * size,
                period: DateInterval(start: start, end: end)
            ))
            index += 1
        }
        return Array(result.suffix(limit).reversed())
    }

    /// 패키지 기간의 숫자 정리 (R16 집계 그대로)
    static func summary(
        package: PackagePeriod,
        doses: [DoseSnapshot],
        checks: [ConditionCheckSnapshot],
        weights: [WeightSampleSnapshot],
        proteins: [ProteinEntrySnapshot],
        sessions: [StrengthSessionSnapshot],
        proteinTarget: Int?,
        calendar: Calendar
    ) -> PackageSummary {
        PackageSummary(
            package: package,
            summary: WeeklySummaryRules.summary(
                period: package.period,
                doses: doses,
                checks: checks,
                weights: weights,
                proteins: proteins,
                sessions: sessions,
                proteinTarget: proteinTarget,
                calendar: calendar
            )
        )
    }

    /// 오늘 카드에 띄울 패키지: 가장 최근에 끝났고, 끝난 지 `recentDays`일이 안 됐을 때
    static func recentlyFinished(doses: [DoseSnapshot], now: Date, calendar: Calendar) -> PackagePeriod? {
        guard let latest = finishedPackages(doses: doses, now: now, calendar: calendar, limit: 1).first,
              let until = calendar.date(byAdding: .day, value: recentDays, to: latest.period.end),
              now < until
        else { return nil }
        return latest
    }
}
