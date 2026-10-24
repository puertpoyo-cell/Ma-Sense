import Foundation

/// 바디맵에 표시할 최근 사용 부위
struct SiteUse: Equatable {
    let site: BodySite
    let date: Date
}

/// R6. 바디맵 표시. **추천하지 않는다.** 사용자가 보고 고른다.
/// 부위 기록 없음(`site == nil`, D6 지난 투약 한꺼번에 입력)은 바디맵 이력·부위별 날짜에 넣지 않는다.
enum SiteRules {
    /// 부위를 아는 최근 `limit`회의 부위와 날짜, 최근 순. 취소된 기록은 제외.
    static func siteHistory(doses: [DoseSnapshot], limit: Int = 4) -> [SiteUse] {
        let uses = doses
            .filter { !$0.isCancelled }
            .sorted { $0.administeredAt > $1.administeredAt }
            .compactMap { dose in dose.site.map { SiteUse(site: $0, date: dose.administeredAt) } }
        return Array(uses.prefix(max(limit, 0)))
    }

    /// 부위의 최근 사용 순위 (0이 가장 최근). 최근 `limit`회 안에 없으면 nil. `Color.siteRecent(rank:)`에 넘긴다.
    static func recencyRank(of site: BodySite, in history: [SiteUse]) -> Int? {
        history.firstIndex { $0.site == site }
    }

    /// 부위별 마지막 사용 시각 (취소 제외). 쓴 적 없는 부위는 키가 없다. 바디맵 구역 날짜와 부위별 목록에 쓴다
    static func lastUseBySite(doses: [DoseSnapshot]) -> [BodySite: Date] {
        doses
            .filter { !$0.isCancelled }
            .reduce(into: [BodySite: Date]()) { result, dose in
                guard let site = dose.site else { return }
                result[site] = max(result[site] ?? .distantPast, dose.administeredAt)
            }
    }

    /// 투약 기록 화면 위의 "지난 투약" 안내: 직전 투약(취소 제외)의 부위·시각과 지난 날 수. 기록이 없으면 nil.
    /// 직전 투약의 부위를 모르면 부위 없이 알린다. 사실만 알린다. 다음 부위를 제안하지 않는다
    static func lastDoseNote(doses: [DoseSnapshot], now: Date, calendar: Calendar) -> LastDoseNote? {
        guard let last = doses.filter({ !$0.isCancelled }).max(by: { $0.administeredAt < $1.administeredAt }) else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last.administeredAt), to: calendar.startOfDay(for: now)).day ?? 0
        return LastDoseNote(site: last.site, date: last.administeredAt, daysAgo: max(days, 0))
    }
}

/// 지난 투약 안내 (R6)
struct LastDoseNote: Equatable {
    /// nil = 부위 기록 없음
    let site: BodySite?
    let date: Date
    /// 달력 날짜 기준. 오늘이면 0
    let daysAgo: Int
}
