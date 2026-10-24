import Foundation

/// 주사 부위 8구역 (DATA_MODEL.md). 표시명은 `Localizable.xcstrings`의 `site.<rawValue>`.
enum BodySite: String, Codable, CaseIterable, Identifiable {
    case abdomenUpperLeft, abdomenUpperRight
    case abdomenLowerLeft, abdomenLowerRight
    case thighLeft, thighRight
    case upperArmLeft, upperArmRight

    enum Group: String, Codable, CaseIterable {
        case abdomen, thigh, upperArm
    }

    var id: String { rawValue }

    var group: Group {
        switch self {
        case .abdomenUpperLeft, .abdomenUpperRight, .abdomenLowerLeft, .abdomenLowerRight:
            return .abdomen
        case .thighLeft, .thighRight:
            return .thigh
        case .upperArmLeft, .upperArmRight:
            return .upperArm
        }
    }

    var localizedName: String {
        L10n.string("site." + rawValue)
    }

    /// 부위 기록 없음(nil, D6)은 "부위 기록 없음"
    static func localizedName(_ site: BodySite?) -> String {
        site?.localizedName ?? L10n.string("site.unknown")
    }
}
