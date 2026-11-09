import SwiftData
import SwiftUI

/// 워치에서 마선생에게 묻기: 지금 상황에 맞는 주제 순서, 누르면 고정 대답 (iPhone과 같은 문장·규칙, 판단 없음)
struct WatchCoachView: View {
    @Query(filter: #Predicate<Prescription> { $0.isActive }) private var active: [Prescription]
    @Query private var checks: [ConditionCheck]
    @Environment(\.calendar) private var calendar
    @State private var shown: Set<String> = []
    @State private var reply: CoachLine?

    private var coachContext: CoachContext {
        var context = CoachContext()
        let p = active.first
        let doses = p?.doseSnapshots ?? []
        let snapshots = checks.compactMap(\.snapshot)
        context.isLowCondition = ConditionRules.isLowConditionDay(checks: snapshots, now: .now)
        context.isLowAppetite = ConditionRules.isLowAppetiteDay(checks: snapshots, now: .now)
        // 워치는 물어볼 것·진료 기록을 보지 않으므로 그 제안은 iPhone에 맡긴다 (openQuestions 1)
        context.facts = CoachFactsRules.facts(
            prescription: p?.snapshot, doses: doses, checks: snapshots, openQuestions: 1,
            recordDates: doses.map(\.administeredAt) + snapshots.map(\.checkedAt), now: .now, calendar: calendar
        )
        return context
    }

    var body: some View {
        let context = coachContext
        List {
            HStack(alignment: .top, spacing: 8) {
                WatchCoachFace(size: 32, mood: (reply ?? CoachRules.greeting(context: context, now: .now, calendar: calendar)).mood)
                Text(verbatim: WatchCoachText.text(reply ?? CoachRules.greeting(context: context, now: .now, calendar: calendar)))
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .listRowBackground(Color.clear)
            ForEach(CoachRules.suggestedTopics(context: context, now: .now, calendar: calendar), id: \.self) { topic in
                Button {
                    let line = CoachRules.reply(to: topic, context: context, shownKeys: shown, now: .now, calendar: calendar)
                    shown.insert(line.key)
                    withAnimation { reply = line }
                } label: {
                    Text(LocalizedStringKey("coach.topic." + topic.rawValue))
                }
            }
            Text("coach.notice")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
        .navigationTitle("coach.name")
    }
}

/// 마선생 얼굴 (iPhone과 같은 그림, 매운맛이면 빨간 배경)
struct WatchCoachFace: View {
    var size: CGFloat
    var mood: CoachMood = .smile
    @AppStorage(CoachTone.key) private var toneRaw = CoachTone.mild.rawValue

    var body: some View {
        let base = toneRaw == CoachTone.spicy.rawValue ? "MasenseCoachSpicy" : "MasenseCoach"
        let suffix: String = switch mood {
        case .smile: ""
        case .happy: "Happy"
        case .gentle: "Gentle"
        case .thinking: "Thinking"
        case .wink: "Wink"
        }
        Image(base + suffix)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

/// 마선생 한 줄 → 글 (iPhone `CoachMessage.text`와 같은 키 규칙, 말투는 첫 번째)
enum WatchCoachText {
    static func text(_ line: CoachLine, tone: CoachTone = .mild) -> String {
        func plain(_ base: String) -> String { L10n.string(CoachRules.localizedKey(base: base, variant: 0, tone: tone)) }
        func format(_ key: String, _ args: CVarArg...) -> String { String(format: L10n.string(key), arguments: args) }
        switch line {
        case let .fact(.doseDay(site?)): return format("coach.doseDay %@", site.localizedName)
        case .fact(.doseDay(nil)): return plain("doseDay.noSite")
        case let .fact(.lowSupply(remaining, true)): return format("coach.lowPens %lld", remaining)
        case let .fact(.lowSupply(remaining, false)): return format("coach.lowDoses %lld", remaining)
        case .fact(.noRecentWeight): return plain("noWeight")
        case .lowCondition: return plain("lowCondition")
        case .lowAppetite: return plain("lowAppetite")
        case .proteinNotYet: return plain("proteinNotYet")
        case .strengthNotYet: return plain("strengthNotYet")
        case let .tip(index): return plain("tip." + String(index))
        case let .place(spot): return plain("place." + spot.rawValue)
        case .greeting: return plain("greeting")
        case .clinicFollowUp: return plain("clinicFollowUp")
        case let .recorded(kind): return plain("recorded." + kind.rawValue)
        case let .proteinEstimate(grams): return format("coach.proteinEstimate %lld", grams)
        case let .answer(topic, index): return L10n.string("coach.answer." + topic.rawValue + "." + String(index))
        case let .greetingAt(part): return plain("greeting." + part.rawValue)
        case .askDoctor: return plain("askDoctor")
        case .notUnderstood: return plain("notUnderstood")
        case .savedQuestion: return plain("savedQuestion")
        case .clinicSoon(0): return plain("clinicSoon.today")
        case let .clinicSoon(days): return format("coach.clinicSoon %lld", days)
        case .questionsEmpty: return plain("questionsEmpty")
        case let .repeatedSymptom(symptom, periods): return format("coach.repeatedSymptom %@ %lld", symptom.localizedName, periods)
        case .conditionMissing: return plain("conditionMissing")
        case let .pensShort(lastDose, clinic):
            return format("coach.pensShort %@ %@",
                          lastDose.formatted(.dateTime.month(.defaultDigits).day()),
                          clinic.formatted(.dateTime.month(.defaultDigits).day()))
        case let .recordGap(days): return format("coach.recordGap %lld", days)
        }
    }
}
