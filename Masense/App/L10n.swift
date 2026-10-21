import Foundation

/// 런타임에 만든 키로 `Localizable.xcstrings` 문자열을 찾는다.
/// `String(localized: "site.\(x)")`처럼 보간 리터럴을 쓰면 키가 "site.%@"로 바뀌어 찾지 못하므로 이 함수를 거친다.
enum L10n {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}
