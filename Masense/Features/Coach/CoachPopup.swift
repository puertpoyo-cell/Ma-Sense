import Observation
import SwiftUI

/// 마선생 한마디 팝업 (R20, D18). 화면 맨 위에 늘 떠 있지 않고, 스크롤하다 자리(`CoachSpot`)에 닿으면
/// 그 자리에 맞는 한 줄이 아래에서 통 튀어나왔다가 몇 초 뒤 들어간다.
/// - 한 번에 하나만. 자리마다 하루 한 번, 같은 한 줄은 하루 한 번 (기기 화면 상태라 UserDefaults)
/// - 과정만 다정하게 권하고 체중 결과를 평가하지 않는다 (COMPLIANCE.md 3.1). 건강관리 한마디에는 고지를 붙인다
@Observable
final class CoachPopupCenter {
    private(set) var current: CoachLine?
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
            current = line
            scheduleDismiss()
        }
    }

    @MainActor
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        guard current != nil else { return }
        current = nil
        lastDismissedAt = .now
    }

    @MainActor
    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.visibleSeconds))
            guard !Task.isCancelled else { return }
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

extension CoachLine {
    var text: Text {
        switch self {
        case let .fact(.doseDay(site?)):
            return Text("coach.doseDay \(site.localizedName)")
        case .fact(.doseDay(nil)):
            return Text("coach.doseDay.noSite")
        case let .fact(.lowSupply(remaining, true)):
            return Text("coach.lowPens \(remaining)")
        case let .fact(.lowSupply(remaining, false)):
            return Text("coach.lowDoses \(remaining)")
        case .fact(.noRecentWeight):
            return Text("coach.noWeight")
        case .lowCondition:
            return Text("coach.lowCondition")
        case .lowAppetite:
            return Text("coach.lowAppetite")
        case .proteinNotYet:
            return Text("coach.proteinNotYet")
        case .strengthNotYet:
            return Text("coach.strengthNotYet")
        case let .tip(index):
            // 보간하면 키가 "coach.tip.%lld"가 되므로 이어 붙인 String으로
            return Text(LocalizedStringKey("coach.tip." + String(index)))
        case let .place(spot):
            return Text(LocalizedStringKey("coach.place." + spot.rawValue))
        }
    }
}

// MARK: 팝업 그림

/// 캐릭터 얼굴 + 유리 말풍선. 얼굴이 살짝 기울었다가 통 튀며 바로 선다
struct CoachPopup: View {
    let line: CoachLine
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    private var bubble: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6, bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.s2) {
            Image("MasenseCoach")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
                .rotationEffect(.degrees(settled || reduceMotion ? 0 : -16), anchor: .bottom)
                .scaleEffect(settled || reduceMotion ? 1 : 0.6, anchor: .bottom)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.s1) {
                HStack(alignment: .firstTextBaseline) {
                    Text("coach.name")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(Color.accent)
                    Spacer(minLength: 0)
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.inkTertiary)
                        .accessibilityHidden(true)
                }
                line.text
                    .font(Typography.body)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if line.isHealthTip {
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
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.bottom, Spacing.s3)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("coach.popup.dismissHint"))
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
                    if let line = coach.current {
                        CoachPopup(line: line) { coach.dismiss() }
                            .id(line.key)
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
                    value: coach.current?.key
                )
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: coach.current?.key) { _, new in new != nil }
            .onAppear { reachAppearSpot() }
            .onChange(of: coach.isPaused) { _, paused in
                if !paused { reachAppearSpot() }
            }
            .onDisappear { coach.dismiss() }
    }
}

private extension CoachPopupOverlay {
    func reachAppearSpot() {
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
