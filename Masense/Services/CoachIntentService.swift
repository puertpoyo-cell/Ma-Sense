import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// D30 마선생에게 글로 물은 것을 주제로 나눈다.
/// 1) 규칙(`CoachIntentRules`)이 먼저. 의사 질문이면 그대로 끝
/// 2) 규칙이 못 알아들으면, 기기에 Apple Intelligence가 있을 때 기기 안 언어 모델에게 정해진 보기 중 하나만 고르게 한다
///    모델은 문장을 쓰지 않고 분류만 한다. 대답 문장은 늘 앱에 미리 적어 둔 것 (COMPLIANCE.md: 앱이 건강 판단을 만들지 않음)
/// 글은 기기 밖으로 나가지 않는다 (기기 안 모델)
enum CoachIntentService {
    static func classify(_ text: String) async -> CoachIntent {
        let rule = CoachIntentRules.classify(text)
        if rule == .askDoctor { return rule }
        if case .topic = rule { return rule }
        return CoachIntentRules.merge(rule: rule, model: await modelIntent(text))
    }

    private static func modelIntent(_ text: String) async -> CoachIntent? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await OnDeviceCoachClassifier.classify(text)
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
enum CoachIntentChoice: String {
    case today, protein, movement, water, sleep, weight, condition, clinic
    /// 약·용량·단계·처방·심한 증상처럼 의사가 판단할 질문
    case askDoctor
    case other
}

@available(iOS 26.0, *)
enum OnDeviceCoachClassifier {
    private static let instructions = """
    You sort a short Korean message written to a habit-logging coach into exactly one category. Do not answer the message.
    Categories: today (what to do today), protein (protein, meals, food), movement (exercise, strength, walking), \
    water (drinking water), sleep (sleep, rest), weight (body weight, body fat), condition (how the body feels, appetite, mild discomfort), \
    clinic (doctor visit, lab tests, appointment, report), askDoctor (medicine, dose, dose level or step, prescription, injection schedule changes, \
    severe or worrying symptoms), other (anything else).
    When unsure between askDoctor and another category, choose askDoctor.
    """

    static func classify(_ text: String) async -> CoachIntent? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: text, generating: CoachIntentChoice.self)
            switch response.content {
            case .today: return .topic(.today)
            case .protein: return .topic(.protein)
            case .movement: return .topic(.movement)
            case .water: return .topic(.water)
            case .sleep: return .topic(.sleep)
            case .weight: return .topic(.weight)
            case .condition: return .topic(.condition)
            case .clinic: return .topic(.clinic)
            case .askDoctor: return .askDoctor
            case .other: return .unknown
            }
        } catch {
            return nil
        }
    }
}
#endif
