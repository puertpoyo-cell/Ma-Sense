import Observation
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
        guard !isPaused else { return }
        isTalking = false
        current = Self.message(line, avoiding: current)
        scheduleDismiss()
    }

    /// 말 걸기: 인사와 주제 버튼. 오늘 화면에서 부르면 그 화면의 사실을 함께 받는다
    @MainActor
    func talk(context: CoachContext? = nil) {
        if let context { lastContext = context }
        dismissTask?.cancel()
        talkKeys = []
        isTalking = true
        current = Self.message(.greeting, avoiding: current)
    }

    /// 주제 버튼을 눌렀을 때
    @MainActor
    func ask(_ topic: CoachTopic, now: Date, calendar: Calendar) {
        let line = CoachRules.reply(to: topic, context: lastContext, shownKeys: talkKeys, now: now, calendar: calendar)
        talkKeys.insert(line.key)
        current = Self.message(line, avoiding: current)
    }

    @MainActor
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        isTalking = false
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
        case let .recorded(kind):
            return plain("coach.recorded." + kind.rawValue)
        case let .answer(topic, index):
            // 고정 대답은 말투 하나
            return Text(LocalizedStringKey("coach.answer." + topic.rawValue + "." + String(index)))
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
    var onTalk: () -> Void
    var onAsk: (CoachTopic) -> Void
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    private var bubble: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6, bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(alignment: .bottom, spacing: Spacing.s2) {
                Button(action: onTalk) {
                    CoachFace(size: 64, mood: message.line.mood)
                        // 표정이 바뀌면 살짝 튄다
                        .id(message.line.mood)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                        .rotationEffect(.degrees(settled || reduceMotion ? 0 : -16), anchor: .bottom)
                        .scaleEffect(settled || reduceMotion ? 1 : 0.6, anchor: .bottom)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("coach.talk.button"))
                bubbleContent
            }
            if isTalking {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s2) {
                        ForEach(CoachTopic.allCases, id: \.self) { topic in
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
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.s3)
        .gesture(
            DragGesture(minimumDistance: 12).onEnded { value in
                if value.translation.height > 16 { onDismiss() }
            }
        )
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.42).delay(0.06)) {
                settled = true
            }
        }
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

/// 마선생 얼굴 원 (팝업·말 걸기 버튼)
struct CoachFace: View {
    var size: CGFloat
    var mood: CoachMood = .smile

    private var assetName: String {
        switch mood {
        case .smile: return "MasenseCoach"
        case .happy: return "MasenseCoachHappy"
        case .gentle: return "MasenseCoachGentle"
        case .thinking: return "MasenseCoachThinking"
        case .wink: return "MasenseCoachWink"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: size > 40 ? 1.5 : 1))
            .shadow(color: .black.opacity(0.35), radius: size > 40 ? 10 : 3, y: size > 40 ? 5 : 1)
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

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                ZStack {
                    if let message = coach.current {
                        CoachPopup(
                            message: message,
                            isTalking: coach.isTalking,
                            onTalk: { coach.talk() },
                            onAsk: { coach.ask($0, now: .now, calendar: calendar) },
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
