import SwiftUI

/// 증상 칩. 라벨 + 현재 강도. 선택 시 `accentSoft` 배경 (DESIGN_SYSTEM.md 5.7).
/// 심각도 3은 색이 아니라 굵기와 텍스트로만 구분한다.
struct SymptomChip: View {
    let title: String
    /// 0 없음 ~ 3 심함
    let severity: Int
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s1) {
                Text(title)
                    .fontWeight(severity >= 3 ? .bold : .medium)
                    .lineLimit(2)
                Spacer(minLength: Spacing.s1)
                if severity > 0 {
                    Text(severityLabel)
                        .font(Typography.caption)
                        .fontWeight(severity >= 3 ? .bold : .regular)
                }
            }
            .font(Typography.label)
            .foregroundStyle(Color.ink)
            .padding(Spacing.s3)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                severity > 0 || isFocused ? Color.accentSoft : Color.frost,
                in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .stroke(isFocused ? Color.accent : Color.frostBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(severityLabel)
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private var severityLabel: String {
        Self.severityLabel(severity)
    }

    static func severityLabel(_ severity: Int) -> String {
        L10n.string("severity." + String(severity))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s2) {
        SymptomChip(title: Symptom.nausea.localizedName, severity: 2, isFocused: true) {}
        SymptomChip(title: Symptom.fatigue.localizedName, severity: 0, isFocused: false) {}
        SymptomChip(title: Symptom.injectionSiteReaction.localizedName, severity: 3, isFocused: false) {}
    }
    .padding(.horizontal, Spacing.screenHorizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .midnightBackground()
    .preferredColorScheme(.dark)
}
