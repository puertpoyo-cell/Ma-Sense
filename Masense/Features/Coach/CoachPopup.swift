import Observation
import SwiftData
import SwiftUI

/// 화면에 띄운 한 줄과 그 말투 (D18). 같은 뜻을 `CoachRules.variantCount`가지 말투로 돌려 말한다
struct CoachMessage: Equatable {
    let line: CoachLine
    let variant: Int

    var id: String { line.key + "." + String(variant) }
}

/// 마선생 한마디 팝업 (R20, D18). 화면 맨 위에 늘 떠 있지 않고, 스크롤하다 자리(`CoachSpot`)에 닿으면
/// 그 자리에 맞는 한 줄이 아래에서 통 튀어나왔다가 몇 초 뒤 들어간다.
/// - 한 번에 하나만. 자리마다 하루 한 번, 같은 한 줄은 하루 한 번 (기기 화면 상태라 UserDefaults)
/// - 얼굴을 누르거나 오늘 화면의 얼굴 버튼으로 말을 걸면 주제를 골라 묻는 대화가 된다 (정해 둔 문장만, 자유 대화 없음)
/// - 과정만 다정하게 권하고 체중 결과를 평가하지 않는다 (COMPLIANCE.md 3.1). 건강관리 한마디에는 고지를 붙인다
@Observable
final class CoachPopupCenter {
    private(set) var current: CoachMessage?
    /// 말 걸기 중이면 주제 버튼을 보이고 저절로 들어가지 않는다
    private(set) var isTalking = false
    /// 시작 전환 화면 등으로 가려져 있을 때. 쉬는 동안 닿은 자리는 기록하지 않는다
    var isPaused = false
    /// N-H4: VoiceOver가 켜져 있으면 저절로 들어가지 않는다 (닫을 때까지)
    var holdsForVoiceOver = false

    /// N-G3 설정 > 마선생: 자주(자리마다) / 가끔(하루 2번) / 끄기(팝업 없음, 말 걸기는 됨). UserDefaults `coach.frequency`
    enum Frequency: String, CaseIterable {
        case often, sometimes, off

        /// 가끔일 때 하루 최대 팝업 수
        static let sometimesLimit = 2
    }

    static let frequencyKey = "coach.frequency"

    var frequency: Frequency {
        Frequency(rawValue: defaults.string(forKey: Self.frequencyKey) ?? "") ?? .often
    }

    /// 떠 있는 시간
    static let visibleSeconds: Double = 6
    /// 자리에 닿고 튀어나오기까지
    static let popDelaySeconds: Double = 0.5
    /// 들어간 뒤 다음 팝업까지 쉬는 시간 (빠르게 스크롤할 때 줄줄이 뜨지 않게)
    static let restSeconds: Double = 2.5

    private let defaults: UserDefaults
    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private var lastDismissedAt: Date?
    @ObservationIgnored private var isPending = false
    /// 말 걸기 대답에 쓰는 오늘의 사실. 오늘 화면이 자리에 닿을 때마다 새로 받는다
    @ObservationIgnored private var lastContext = CoachContext()
    /// 이번 대화에서 한 줄 (같은 주제를 다시 물으면 다른 줄로)
    @ObservationIgnored private var talkKeys: Set<String> = []
    /// D30 글로 물은 것 중 의사와 상의할 질문. "물어볼 것에 담기"를 누르면 저장
    private(set) var pendingQuestion: String?
    /// D30 글을 분류하는 중
    private(set) var isThinking = false
    /// D30 지금 상황에 맞춘 주제 버튼 순서
    private(set) var topics: [CoachTopic] = CoachTopic.allCases

    private enum Key {
        static let day = "coach.popup.day"
        static let lines = "coach.popup.lines"
        static let spots = "coach.popup.spots"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 자리에 닿았을 때. `now`는 뷰의 주입 지점에서 받는다
    @MainActor
    func reach(_ spot: CoachSpot, context: CoachContext, now: Date, calendar: Calendar) {
        if ![.history, .report, .clinic].contains(spot) { lastContext = context }
        resetIfNewDay(now: now, calendar: calendar)
        guard !isPaused, current == nil, !isPending, !shownSpots.contains(spot.rawValue) else { return }
        if let lastDismissedAt, now.timeIntervalSince(lastDismissedAt) < Self.restSeconds { return }
        // N-G3: 끄기면 자리 팝업 없음, 가끔이면 하루 2번까지
        switch frequency {
        case .off: return
        case .sometimes: if shownLines.count >= Frequency.sometimesLimit { return }
        case .often: break
        }
        // 그 자리는 오늘 지나간 것으로 (후보를 다 띄웠으면 조용히)
        shownSpots.insert(spot.rawValue)
        guard let line = CoachRules.next(for: spot, context: context, shownKeys: shownLines, now: now, calendar: calendar) else { return }
        shownLines.insert(line.key)
        isPending = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.popDelaySeconds))
            isPending = false
            guard current == nil, !isPaused else {
                // 띄우지 못했으면 다음에 다시 닿을 수 있게 되돌린다
                shownSpots.remove(spot.rawValue)
                shownLines.remove(line.key)
                return
            }
            current = Self.message(line)
            scheduleDismiss()
        }
    }

    /// 기록을 마친 직후 한마디 (D19). 하루 한 번 제한 없이, 떠 있던 팝업을 바꾼다
    @MainActor
    func react(to kind: CoachRecordKind) {
        react(with: .recorded(kind))
    }

    /// 기록 직후 정해 둔 한 줄 (D20 사진 단백질 "약 n g")
    @MainActor
    func react(with line: CoachLine) {
        guard !isPaused, frequency != .off else { return }
        isTalking = false
        current = Self.message(line, avoiding: current)
        scheduleDismiss()
    }

    /// 말 걸기: 인사와 주제 버튼. 오늘 화면에서 부르면 그 화면의 사실을 함께 받는다
    @MainActor
    func talk(context: CoachContext? = nil, now: Date = .now, calendar: Calendar = .current) {
        if let context { lastContext = context }
        dismissTask?.cancel()
        talkKeys = []
        pendingQuestion = nil
        isTalking = true
        // D30: 지금 꼭 할 말이 있으면 그것, 없으면 시간대 인사. 주제 버튼은 상황에 맞는 것부터
        topics = CoachRules.suggestedTopics(context: lastContext, now: now, calendar: calendar)
        current = Self.message(CoachRules.greeting(context: lastContext, now: now, calendar: calendar), avoiding: current)
    }

    /// D30 글로 묻기. 규칙 → (있으면) 기기 안 AI 분류 → 정해 둔 대답. 의사 질문이면 물어볼 것에 담기를 권한다
    @MainActor
    func ask(text: String, now: Date, calendar: Calendar) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isThinking = true
        let intent = await CoachIntentService.classify(trimmed)
        isThinking = false
        switch intent {
        case let .topic(topic):
            pendingQuestion = nil
            ask(topic, now: now, calendar: calendar)
        case .askDoctor:
            pendingQuestion = trimmed
            current = Self.message(.askDoctor, avoiding: current)
        case .unknown:
            pendingQuestion = nil
            current = Self.message(.notUnderstood, avoiding: current)
        }
    }

    /// D30 의사 질문을 진료 탭 "물어볼 것"에 담는다
    @MainActor
    func saveQuestion(in context: ModelContext) {
        guard let pendingQuestion else { return }
        context.insert(ClinicQuestion(text: pendingQuestion))
        try? context.save()
        self.pendingQuestion = nil
        current = Self.message(.savedQuestion, avoiding: current)
    }

    /// 주제 버튼을 눌렀을 때
    @MainActor
    func ask(_ topic: CoachTopic, now: Date, calendar: Calendar) {
        pendingQuestion = nil
        let line = CoachRules.reply(to: topic, context: lastContext, shownKeys: talkKeys, now: now, calendar: calendar)
        talkKeys.insert(line.key)
        current = Self.message(line, avoiding: current)
    }

    @MainActor
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        isTalking = false
        pendingQuestion = nil
        guard current != nil else { return }
        current = nil
        lastDismissedAt = .now
    }

    /// 말투는 무작위로, 바로 앞과 같은 줄이면 다른 말투로
    private static func message(_ line: CoachLine, avoiding previous: CoachMessage? = nil) -> CoachMessage {
        var variant = Int.random(in: 0..<CoachRules.variantCount)
        if let previous, previous.line == line, previous.variant == variant {
            variant = (variant + 1) % CoachRules.variantCount
        }
        return CoachMessage(line: line, variant: variant)
    }

    @MainActor
    private func scheduleDismiss() {
        dismissTask?.cancel()
        // VoiceOver 사용자는 읽는 데 시간이 더 걸린다. 닫을 때까지 둔다 (N-H4)
        guard !holdsForVoiceOver else { return }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.visibleSeconds))
            guard !Task.isCancelled, !isTalking else { return }
            dismiss()
        }
    }

    // MARK: 하루 단위 기록

    private var shownLines: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.lines) ?? []) }
        set { defaults.set(Array(newValue), forKey: Key.lines) }
    }

    private var shownSpots: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.spots) ?? []) }
        set { defaults.set(Array(newValue), forKey: Key.spots) }
    }

    private func resetIfNewDay(now: Date, calendar: Calendar) {
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        let key = "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
        guard defaults.string(forKey: Key.day) != key else { return }
        defaults.set(key, forKey: Key.day)
        defaults.removeObject(forKey: Key.lines)
        defaults.removeObject(forKey: Key.spots)
    }
}

private struct CoachPopupCenterKey: EnvironmentKey {
    static let defaultValue = CoachPopupCenter()
}

extension EnvironmentValues {
    var coach: CoachPopupCenter {
        get { self[CoachPopupCenterKey.self] }
        set { self[CoachPopupCenterKey.self] = newValue }
    }
}

// MARK: 문구

extension CoachMessage {
    /// 말투 0은 원래 키, 1·2는 키 뒤에 ".v2"·".v3". 보간하는 줄은 키가 문자열 그대로 있어야 해서 하나씩 적는다
    var text: Text {
        switch line {
        case let .fact(.doseDay(site?)):
            let name = site.localizedName
            switch variant {
            case 1: return Text("coach.doseDay.v2 \(name)")
            case 2: return Text("coach.doseDay.v3 \(name)")
            default: return Text("coach.doseDay \(name)")
            }
        case let .fact(.lowSupply(remaining, true)):
            switch variant {
            case 1: return Text("coach.lowPens.v2 \(remaining)")
            case 2: return Text("coach.lowPens.v3 \(remaining)")
            default: return Text("coach.lowPens \(remaining)")
            }
        case let .proteinEstimate(grams):
            switch variant {
            case 1: return Text("coach.proteinEstimate.v2 \(grams)")
            case 2: return Text("coach.proteinEstimate.v3 \(grams)")
            default: return Text("coach.proteinEstimate \(grams)")
            }
        case let .fact(.lowSupply(remaining, false)):
            switch variant {
            case 1: return Text("coach.lowDoses.v2 \(remaining)")
            case 2: return Text("coach.lowDoses.v3 \(remaining)")
            default: return Text("coach.lowDoses \(remaining)")
            }
        case .fact(.doseDay(nil)):
            return plain("coach.doseDay.noSite")
        case .fact(.noRecentWeight):
            return plain("coach.noWeight")
        case .lowCondition:
            return plain("coach.lowCondition")
        case .lowAppetite:
            return plain("coach.lowAppetite")
        case .proteinNotYet:
            return plain("coach.proteinNotYet")
        case .strengthNotYet:
            return plain("coach.strengthNotYet")
        case let .tip(index):
            return plain("coach.tip." + String(index))
        case let .place(spot):
            return plain("coach.place." + spot.rawValue)
        case .greeting:
            return plain("coach.greeting")
        case .clinicFollowUp:
            return plain("coach.clinicFollowUp")
        case let .recorded(kind):
            return plain("coach.recorded." + kind.rawValue)
        case let .answer(topic, index):
            // 고정 대답은 말투 하나
            return Text(LocalizedStringKey("coach.answer." + topic.rawValue + "." + String(index)))
        case let .greetingAt(part):
            return plain("coach.greeting." + part.rawValue)
        case .askDoctor:
            return plain("coach.askDoctor")
        case .notUnderstood:
            return plain("coach.notUnderstood")
        case .savedQuestion:
            return plain("coach.savedQuestion")
        }
    }

    /// 보간 없는 키는 이어 붙인 String으로 (보간하면 키가 "%lld" 꼴이 된다)
    private func plain(_ base: String) -> Text {
        let suffix = variant == 0 ? "" : ".v" + String(variant + 1)
        return Text(LocalizedStringKey(base + suffix))
    }
}

extension CoachTopic {
    var titleKey: LocalizedStringKey {
        LocalizedStringKey("coach.topic." + rawValue)
    }
}

// MARK: 팝업 그림

/// 캐릭터 얼굴 + 유리 말풍선. 얼굴이 살짝 기울었다가 통 튀며 바로 선다.
/// 얼굴을 누르면 말 걸기, 말풍선을 누르거나 아래로 밀면 닫힌다. 말 걸기 중이면 아래에 주제 버튼
struct CoachPopup: View {
    let message: CoachMessage
    let isTalking: Bool
    /// D30 상황에 맞춘 주제 순서
    var topics: [CoachTopic] = CoachTopic.allCases
    /// D30 의사 질문을 담을 수 있으면 버튼을 보인다
    var canSaveQuestion = false
    var isThinking = false
    var onTalk: () -> Void
    var onAsk: (CoachTopic) -> Void
    var onSend: (String) -> Void = { _ in }
    var onSaveQuestion: () -> Void = {}
    var onDismiss: () -> Void
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// D35 나올 때·말이 바뀔 때마다 하나씩 올려 얼굴 움직임을 다시 튼다
    @State private var entranceTick = 0

    private var bubble: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6, bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(alignment: .bottom, spacing: Spacing.s2) {
                Button(action: onTalk) {
                    CoachFace(size: 64, mood: message.line.mood, blinks: true)
                        // 표정이 바뀌면 살짝 튄다
                        .id(message.line.mood)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                        // D35: 표정에 맞춰 통통·부르르·살짝 커짐 (동작 줄이기면 없음)
                        .keyframeAnimator(initialValue: FaceMotion(), trigger: entranceTick) { face, motion in
                            face
                                .scaleEffect(x: motion.scaleX, y: motion.scaleY, anchor: .bottom)
                                .rotationEffect(.degrees(motion.rotation), anchor: .bottom)
                                .offset(y: motion.offsetY)
                        } keyframes: { _ in
                            FaceMotion.keyframes(reduceMotion ? nil : CoachEntrance.for(message.line, variant: message.variant))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("coach.talk.button"))
                bubbleContent
            }
            if isTalking {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s2) {
                        ForEach(topics, id: \.self) { topic in
                            Button { onAsk(topic) } label: {
                                Text(topic.titleKey)
                                    .font(Typography.label)
                                    .foregroundStyle(Color.ink)
                                    .padding(.horizontal, Spacing.s3)
                                    .padding(.vertical, Spacing.s2)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .background(Color.accentSoft, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 64 + Spacing.s2)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                // D30 직접 물어보기. 기기 안에서만 읽는다
                HStack(spacing: Spacing.s2) {
                    TextField("coach.input.placeholder", text: $draft)
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                        .focused($inputFocused)
                        .submitLabel(.send)
                        .onSubmit(send)
                    if isThinking {
                        ProgressView()
                    } else {
                        Button(action: send) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Color.inkTertiary : Color.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel(Text("coach.input.send"))
                    }
                }
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, Spacing.s2)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .padding(.leading, 64 + Spacing.s2)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.s3)
        .gesture(
            DragGesture(minimumDistance: 12).onEnded { value in
                if value.translation.height > 16 { onDismiss() }
            }
        )
        .onAppear { entranceTick += 1 }
        .onChange(of: message.id) { _, _ in entranceTick += 1 }
    }

    private func send() {
        let text = draft
        draft = ""
        inputFocused = false
        onSend(text)
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            HStack(alignment: .firstTextBaseline) {
                Text("coach.name")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.accent)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.inkTertiary)
                        .frame(minWidth: 28, minHeight: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("coach.popup.close"))
            }
            message.text
                .font(Typography.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                // 대답이 바뀔 때마다 살짝 튀며 바뀐다
                .id(message.id)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.92, anchor: .leading).combined(with: .opacity))
            if canSaveQuestion {
                Button(action: onSaveQuestion) {
                    Label("coach.saveQuestion", systemImage: "text.badge.plus")
                        .font(Typography.label)
                        .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.s1)
            }
            if message.line.isHealthTip {
                Text("coach.notice")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.s3 + 2)
        .padding(.vertical, Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: bubble)
        .background(Color.frost.opacity(0.6), in: bubble)
        .overlay(
            bubble.strokeBorder(
                LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        )
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        .contentShape(bubble)
        .onTapGesture {
            // 말 걸기 중에는 말풍선을 눌러도 닫히지 않는다 (주제 버튼을 고르는 중)
            if !isTalking { onDismiss() }
        }
        .accessibilityElement(children: .combine)
    }
}

/// D35 얼굴 움직임 값과 세 가지 움직임의 박자. 모든 움직임이 같은 다섯 박자를 쓰고 값만 다르다
struct FaceMotion {
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var rotation: Double = 0
    var offsetY: CGFloat = 0

    /// 다섯 박자 길이 (합 약 0.6초)
    static let beats: [TimeInterval] = [0.07, 0.16, 0.14, 0.11, 0.14]

    struct Pattern {
        var scaleX: [CGFloat]
        var scaleY: [CGFloat]
        var rotation: [Double]
        var offsetY: [CGFloat]
    }

    static func pattern(_ entrance: CoachEntrance?) -> Pattern {
        let still = Pattern(scaleX: [1, 1, 1, 1, 1], scaleY: [1, 1, 1, 1, 1], rotation: [0, 0, 0, 0, 0], offsetY: [0, 0, 0, 0, 0])
        switch entrance {
        case .pop?:
            // 작게 → 크게 → 살짝 작게 → 제자리
            return Pattern(scaleX: [0.7, 1.18, 0.95, 1.02, 1], scaleY: [0.7, 1.18, 0.95, 1.02, 1], rotation: [0, 0, 0, 0, 0], offsetY: [0, 0, 0, 0, 0])
        case .wiggle?:
            // 살짝 커지며 좌우로 부르르
            return Pattern(scaleX: [1.05, 1.08, 1.05, 1.02, 1], scaleY: [1.05, 1.08, 1.05, 1.02, 1], rotation: [-12, 11, -8, 5, 0], offsetY: [0, 0, 0, 0, 0])
        case .bounce?:
            // 눌렸다가 위로 통, 한 번 더 작게 통
            return Pattern(scaleX: [1.12, 0.94, 1.1, 0.98, 1], scaleY: [0.88, 1.08, 0.92, 1.03, 1], rotation: [0, 0, 0, 0, 0], offsetY: [0, -20, 0, -8, 0])
        case nil:
            return still
        }
    }

    @KeyframesBuilder<FaceMotion>
    static func keyframes(_ entrance: CoachEntrance?) -> some Keyframes<FaceMotion> {
        let p = pattern(entrance)
        let d = beats
        KeyframeTrack(\.scaleX) {
            CubicKeyframe(p.scaleX[0], duration: d[0])
            CubicKeyframe(p.scaleX[1], duration: d[1])
            CubicKeyframe(p.scaleX[2], duration: d[2])
            CubicKeyframe(p.scaleX[3], duration: d[3])
            SpringKeyframe(p.scaleX[4], duration: d[4])
        }
        KeyframeTrack(\.scaleY) {
            CubicKeyframe(p.scaleY[0], duration: d[0])
            CubicKeyframe(p.scaleY[1], duration: d[1])
            CubicKeyframe(p.scaleY[2], duration: d[2])
            CubicKeyframe(p.scaleY[3], duration: d[3])
            SpringKeyframe(p.scaleY[4], duration: d[4])
        }
        KeyframeTrack(\.rotation) {
            LinearKeyframe(p.rotation[0], duration: d[0])
            LinearKeyframe(p.rotation[1], duration: d[1])
            LinearKeyframe(p.rotation[2], duration: d[2])
            LinearKeyframe(p.rotation[3], duration: d[3])
            SpringKeyframe(p.rotation[4], duration: d[4])
        }
        KeyframeTrack(\.offsetY) {
            CubicKeyframe(p.offsetY[0], duration: d[0])
            CubicKeyframe(p.offsetY[1], duration: d[1])
            CubicKeyframe(p.offsetY[2], duration: d[2])
            CubicKeyframe(p.offsetY[3], duration: d[3])
            SpringKeyframe(p.offsetY[4], duration: d[4])
        }
    }
}

/// 마선생 얼굴 원 (팝업·말 걸기 버튼)
struct CoachFace: View {
    var size: CGFloat
    var mood: CoachMood = .smile
    /// N-G2: 나타날 때·표정이 바뀔 때 한 번 눈을 깜빡인다 (동작 줄이기면 생략). 눈을 감은 표정에서는 깜빡이지 않는다
    var blinks = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var eyesClosed = false

    private var assetName: String {
        switch mood {
        case .smile: return "MasenseCoach"
        case .happy: return "MasenseCoachHappy"
        case .gentle: return "MasenseCoachGentle"
        case .thinking: return "MasenseCoachThinking"
        case .wink: return "MasenseCoachWink"
        }
    }

    /// 그림(512 기준)의 눈 위치·크기. 눈꺼풀은 피부색 캡슐로 덮는다
    private static let eyes: [(x: CGFloat, y: CGFloat)] = [(204, 264), (308, 264)]
    private static let eyeSize = CGSize(width: 44, height: 40)
    private static let skin = Color(red: 1.0, green: 0.90, blue: 0.83)

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .overlay {
                if eyesClosed {
                    let k = size / 512
                    ForEach(Array(Self.eyes.enumerated()), id: \.offset) { _, eye in
                        Capsule(style: .continuous)
                            .fill(Self.skin)
                            .frame(width: Self.eyeSize.width * k, height: Self.eyeSize.height * k)
                            .position(x: eye.x * k, y: eye.y * k)
                    }
                }
            }
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: size > 40 ? 1.5 : 1))
            .shadow(color: .black.opacity(0.35), radius: size > 40 ? 10 : 3, y: size > 40 ? 5 : 1)
            .task(id: mood) { await blinkIfNeeded() }
    }

    private func blinkIfNeeded() async {
        guard blinks, !reduceMotion, mood != .happy, mood != .wink else { return }
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        eyesClosed = true
        try? await Task.sleep(for: .milliseconds(110))
        eyesClosed = false
    }
}

// MARK: 화면에 붙이기

extension View {
    /// 탭 화면 맨 아래에 팝업 자리. `appearSpot`이 있으면 화면이 열릴 때 그 자리에 닿은 것으로 본다 (기록·리포트 탭)
    func coachPopupOverlay(appearSpot: CoachSpot? = nil) -> some View {
        modifier(CoachPopupOverlay(appearSpot: appearSpot))
    }

    /// 스크롤 안의 카드에 붙인다. 카드 윗부분이 화면 아래쪽 3할 위로 올라오면 그 자리에 닿은 것
    func coachSpot(_ spot: CoachSpot, viewport: CGRect, context: CoachContext) -> some View {
        modifier(CoachSpotModifier(spot: spot, viewport: viewport, context: context))
    }
}

private struct CoachPopupOverlay: ViewModifier {
    let appearSpot: CoachSpot?

    @Environment(\.coach) private var coach
    @Environment(\.calendar) private var calendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .onChange(of: voiceOver, initial: true) { _, on in coach.holdsForVoiceOver = on }
            .overlay(alignment: .bottom) {
                ZStack {
                    if let message = coach.current {
                        CoachPopup(
                            message: message,
                            isTalking: coach.isTalking,
                            topics: coach.topics,
                            canSaveQuestion: message.line == .askDoctor && coach.pendingQuestion != nil,
                            isThinking: coach.isThinking,
                            onTalk: { coach.talk() },
                            onAsk: { coach.ask($0, now: .now, calendar: calendar) },
                            onSend: { text in Task { await coach.ask(text: text, now: .now, calendar: calendar) } },
                            onSaveQuestion: { coach.saveQuestion(in: modelContext) },
                            onDismiss: { coach.dismiss() }
                        )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .scale(scale: 0.2, anchor: .bottomLeading).combined(with: .opacity),
                                    removal: .opacity.combined(with: .offset(y: 24))
                                )
                        )
                    }
                }
                .animation(
                    reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.6),
                    value: coach.current?.id
                )
                .animation(.easeOut(duration: 0.2), value: coach.isTalking)
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: coach.current?.id) { _, new in new != nil }
            .onAppear { reachAppearSpot() }
            .onChange(of: coach.isPaused) { _, paused in
                if !paused { reachAppearSpot() }
            }
            .onDisappear { coach.dismiss() }
    }

    private func reachAppearSpot() {
        if let appearSpot {
            coach.reach(appearSpot, context: CoachContext(), now: .now, calendar: calendar)
        }
    }
}

private struct CoachSpotModifier: ViewModifier {
    let spot: CoachSpot
    let viewport: CGRect
    let context: CoachContext

    @Environment(\.coach) private var coach
    @Environment(\.calendar) private var calendar
    @State private var frame: CGRect = .zero

    private var isReached: Bool {
        guard viewport.height > 0, frame.height > 0 else { return false }
        return frame.minY < viewport.minY + viewport.height * 0.7 && frame.maxY > viewport.minY + 60
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onChange(of: isReached && !coach.isPaused, initial: true) { _, reached in
                if reached {
                    coach.reach(spot, context: context, now: .now, calendar: calendar)
                }
            }
    }
}
