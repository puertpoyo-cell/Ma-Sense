import Observation
import SwiftUI

/// 알림·위젯·Live Activity에서 들어와 앱 안 어디를 열지 (D6). 탭과 오늘 화면이 `pending`을 보고 열고, 연 뒤 비운다.
@Observable
final class AppRouter {
    var pending: AppRoute?

    func open(_ route: AppRoute) {
        pending = route
    }

    /// 화면이 처리했으면 비운다
    func finish(_ route: AppRoute) {
        if pending == route {
            pending = nil
        }
    }

    /// `masense://log-dose` 같은 링크 (위젯·Live Activity의 `widgetURL`)
    static func route(for url: URL) -> AppRoute? {
        guard url.scheme == AppRouter.urlScheme else { return nil }
        switch url.host {
        case "log-dose": return .logDose
        case "condition": return .conditionCheck
        case "log-weight": return .logWeight
        default: return nil
        }
    }

    static let urlScheme = "masense"
}

private struct AppRouterKey: EnvironmentKey {
    static let defaultValue = AppRouter()
}

extension EnvironmentValues {
    var router: AppRouter {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }
}
