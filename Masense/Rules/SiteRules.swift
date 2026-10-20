import Foundation

/// 바디맵에 표시할 최근 사용 부위
struct SiteUse: Equatable {
    let site: BodySite
    let date: Date
}

/// R6. 바디맵 표시. **추천하지 않는다.** 사용자가 보고 고른다.
enum SiteRules {
    /// 최근 `limit`회 사용 부위와 날짜, 최근 순. 취소된 기록은 제외.
    static func siteHistory(doses: [DoseSnapshot], limit: Int = 4) -> [SiteUse] {
        doses
            .filter { !$0.isCancelled }
            .sorted { $0.administeredAt > $1.administeredAt }
            .prefix(max(limit, 0))
            .map { SiteUse(site: $0.site, date: $0.administeredAt) }
    }

    /// 부위의 최근 사용 순위 (0이 가장 최근). 최근 `limit`회 안에 없으면 nil. `Color.siteRecent(rank:)`에 넘긴다.
    static func recencyRank(of site: BodySite, in history: [SiteUse]) -> Int? {
        history.firstIndex { $0.site == site }
    }
}
