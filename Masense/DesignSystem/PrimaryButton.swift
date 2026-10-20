import SwiftUI

/// `accent` 채움, `midnight` 텍스트, 높이 52 (DESIGN_SYSTEM.md 5).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.label)
            .foregroundStyle(Color.midnight)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Color.accent.opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
            )
    }
}

/// 테두리만 있는 버튼.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.label)
            .foregroundStyle(Color.ink.opacity(configuration.isPressed ? 0.7 : 1))
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(Color.frostBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

struct PrimaryButton: View {
    private let titleKey: LocalizedStringKey
    private let action: () -> Void

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    var body: some View {
        Button(titleKey, action: action)
            .buttonStyle(.primary)
    }
}

struct GhostButton: View {
    private let titleKey: LocalizedStringKey
    private let action: () -> Void

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    var body: some View {
        Button(titleKey, action: action)
            .buttonStyle(.ghost)
    }
}

#Preview {
    VStack(spacing: Spacing.s4) {
        PrimaryButton("action.logDose") {}
        GhostButton("action.cancel") {}
    }
    .padding(.horizontal, Spacing.screenHorizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .midnightBackground()
    .preferredColorScheme(.dark)
}
