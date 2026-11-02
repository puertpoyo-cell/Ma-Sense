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

    /// 좌우 없이 구역만 ("복부 위"). 좌우는 그림의 L/R로 보일 때 (D38-2)
    var regionName: String {
        let region = rawValue.replacingOccurrences(of: "Left", with: "").replacingOccurrences(of: "Right", with: "")
        return L10n.string("site.region." + region)
    }

    /// 부위 기록 없음(nil, D6)은 "부위 기록 없음"
    static func localizedName(_ site: BodySite?) -> String {
        site?.localizedName ?? L10n.string("site.unknown")
    }
}
