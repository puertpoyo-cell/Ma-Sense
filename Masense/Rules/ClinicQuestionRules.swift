import Foundation

/// R15 (D6). 진료 때 물어볼 것. 사용자가 적은 문장을 그대로 두고 분류·답·추천을 붙이지 않는다.
enum ClinicQuestionRules {
    /// 입력 한 개의 최대 글자 수
    static let maxLength = 200

    /// 앞뒤 공백을 지우고 줄바꿈은 공백으로. 비면 nil. 길면 `maxLength`에서 자른다
    static func normalized(_ text: String) -> String? {
        let single = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !single.isEmpty else { return nil }
        return String(single.prefix(maxLength))
    }

    /// 아직 묻지 않은 것, 적은 순
    static func pending(_ questions: [ClinicQuestionSnapshot]) -> [ClinicQuestionSnapshot] {
        questions
            .filter { $0.askedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 물어본 것, 최근에 물어본 순
    static func asked(_ questions: [ClinicQuestionSnapshot]) -> [ClinicQuestionSnapshot] {
        questions
            .filter { $0.askedAt != nil }
            .sorted { ($0.askedAt ?? .distantPast) > ($1.askedAt ?? .distantPast) }
    }
}
