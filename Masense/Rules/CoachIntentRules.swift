import Foundation

/// D30 마선생에게 글로 물을 때 (2026-11-01 사람 요청 "대화창 더 풍부하게, AI로 맥락상 답변 변화").
/// 글을 주제로 분류만 한다. 대답은 늘 미리 정해 검토한 문장(`CoachLine`)에서 고른다 — 앱이 지어낸 건강 조언 없음 (COMPLIANCE.md).
/// 용량·약·심한 증상처럼 의사가 판단할 이야기는 무엇보다 먼저 `askDoctor`로 보내 "물어볼 것"에 담게 한다
enum CoachIntent: Equatable {
    case topic(CoachTopic)
    /// 의사와 상의할 질문 (용량·단계·약·심한 증상 등)
    case askDoctor
    /// 알아듣지 못함 → 주제 버튼을 보인다
    case unknown
}

enum CoachIntentRules {
    /// 의사에게 넘길 말. 다른 주제 단어가 함께 있어도 이것이 먼저
    static let doctorKeywords = [
        "용량", "증량", "감량해", "줄여도", "늘려도", "늘려야", "줄여야", "몇 mg", "mg", "밀리", "단계", "레벨", "lv",
        // "예약"과 겹치지 않게 앞에 띄어쓰기를 둔다 (입력 앞에 공백을 붙여 맨 앞 단어도 잡힌다)
        " 약 ", " 약을", " 약은", " 약이", " 약 먹", "처방", "복용", "투여", "끊어", "끊어도", "중단", "건너뛰", "두 번 맞", "더 맞",
        "부작용", "심해", "심한", "심하게", "피가", "혈변", "숨이", "숨쉬", "가슴이", "통증", "응급", "병원 가", "쓰러",
        "dose", "medication", "side effect",
    ]

    static let topicKeywords: [(CoachTopic, [String])] = [
        (.clinic, ["진료", "의사", "병원", "검사", "피검사", "예약", "리포트", "물어볼"]),
        (.condition, ["컨디션", "메스꺼", "속이", "구역", "울렁", "변비", "설사", "피곤", "두통", "어지러", "기운", "식욕", "입맛"]),
        (.protein, ["단백질", "고기", "계란", "달걀", "두부", "닭가슴", "프로틴", "셰이크", "밥", "먹을", "먹어", "식사", "끼니", "음식"]),
        (.movement, ["운동", "근력", "걷기", "산책", "스쿼트", "헬스", "움직", "근육"]),
        (.water, ["물", "수분", "마실", "음료"]),
        (.sleep, ["잠", "수면", "자야", "졸려", "피로", "밤에"]),
        (.weight, ["체중", "몸무게", "살", "kg", "체지방", "인바디", "정체"]),
        (.today, ["오늘", "뭐부터", "뭐 하", "할 일", "시작"]),
    ]

    /// 규칙으로 분류. 의사 질문이 먼저, 그다음 주제 단어가 가장 많이 맞는 주제, 없으면 `unknown`
    static func classify(_ text: String) -> CoachIntent {
        let normalized = " " + text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) + " "
        guard normalized.trimmingCharacters(in: .whitespaces).count >= 1 else { return .unknown }
        if doctorKeywords.contains(where: { normalized.contains($0) }) { return .askDoctor }
        var best: (topic: CoachTopic, hits: Int)?
        for (topic, words) in topicKeywords {
            let hits = words.filter { normalized.contains($0) }.count
            if hits > 0, hits > (best?.hits ?? 0) { best = (topic, hits) }
        }
        return best.map { .topic($0.topic) } ?? .unknown
    }

    /// AI 분류(`CoachIntentService`)를 받아 줄 때도 의사 질문 규칙이 이긴다 (안전 쪽으로)
    static func merge(rule: CoachIntent, model: CoachIntent?) -> CoachIntent {
        if rule == .askDoctor || model == .askDoctor { return .askDoctor }
        if case .topic = rule { return rule }
        return model ?? rule
    }
}
