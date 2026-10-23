import Foundation

/// 앱 안에서 바로 열 곳 (알림·위젯·Live Activity에서 들어올 때)
enum AppRoute: String, Equatable {
    /// 오늘 탭 + 투약 기록 시트
    case logDose
    /// 오늘 탭 + 지금 열려 있는 컨디션 체크
    case conditionCheck
}

/// D6: 알림에서 바로 하는 일 (RULES.md R4-1). 카테고리·액션 식별자, 응답을 앱 안 이동이나 미루기로 바꾸는 규칙.
/// 앱은 판단하지 않는다. 미루기는 같은 문구를 한 시간 뒤 한 번 더 보낼 뿐이다.
enum NotificationActions {
    static let doseCategory = "dose"
    static let conditionCategory = "condition"

    static let logDose = "action.logDose"
    static let snooze = "action.snooze"
    static let logCondition = "action.logCondition"
    /// 알림 본문을 누른 경우. 서비스가 `UNNotificationDefaultActionIdentifier`를 이 값으로 바꿔 넘긴다
    static let defaultAction = "action.default"

    static let snoozeInterval: TimeInterval = 60 * 60
    /// 미룬 알림은 하나만 둔다. 다시 미루면 덮어쓴다
    static let snoozeIdentifier = "dose.snooze"

    enum Response: Equatable {
        case open(AppRoute)
        case snooze
    }

    /// 투약 알림은 기록하기·1시간 뒤 다시, 컨디션 알림은 컨디션 기록. 그 밖의 알림은 액션 없음
    static func category(for kind: NotificationKind) -> String? {
        switch kind {
        case .doseDue, .doseEvening: return doseCategory
        case .conditionH24, .conditionH48: return conditionCategory
        case .clinicSoon, .prescriptionLow: return nil
        }
    }

    static func response(action: String, category: String) -> Response? {
        switch (category, action) {
        case (doseCategory, logDose), (doseCategory, defaultAction):
            return .open(.logDose)
        case (doseCategory, snooze):
            return .snooze
        case (conditionCategory, logCondition), (conditionCategory, defaultAction):
            return .open(.conditionCheck)
        default:
            return nil
        }
    }

    /// 지금부터 한 시간 뒤, 같은 종류(같은 문구)로 한 번
    static func snoozed(kind: NotificationKind, now: Date) -> PlannedNotification {
        PlannedNotification(id: snoozeIdentifier, kind: kind, fireDate: now.addingTimeInterval(snoozeInterval))
    }
}
