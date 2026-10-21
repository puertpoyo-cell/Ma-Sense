import SwiftUI

/// 증상 한 줄: 좌측 증상 이름, 우측 강도 `0 | 1 | 2 | 3` 세그먼트 트랙 (DESIGN_SYSTEM.md 5.4).
/// 색으로 판단하지 않는다: 1·2는 `accentSoft` 배경 + `accent` 글자, 3은 빨강 대신 `ink` 볼드 + `frostHighlightTop` 1.5px 테두리.
struct SymptomChip: View {
    let title: String
    /// 0 없음 ~ 3 심함
    let severity: Int
    let onChange: (Int) -> Void

    var body: some View {
        AdaptiveStack(spacing: Spacing.s3) {
            Text(title)
                .font(Typography.label)
                .fontWeight(severity >= 3 ? .bold : .medium)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Spacing.s1) {
                ForEach(SymptomEntry.severityRange, id: \.self) { value in
                    segment(value)
                }
            }
        }
        .padding(.vertical, Spacing.s2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: title))
    }

    private func segment(_ value: Int) -> some View {
        let isSelected = value == severity
        return Button {
            onChange(value)
        } label: {
            Text(verbatim: String(value))
                .font(Typography.label)
                .fontWeight(isSelected && value >= 3 ? .bold : .medium)
                .monospacedDigit()
                .foregroundStyle(foreground(value, isSelected: isSelected))
                .frame(width: 40, height: 36)
                .background(background(value, isSelected: isSelected), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .strokeBorder(border(value, isSelected: isSelected), lineWidth: isSelected && value >= 3 ? 1.5 : 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: Self.severityLabel(value)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func foreground(_ value: Int, isSelected: Bool) -> Color {
        guard isSelected else { return Color.inkTertiary }
        switch value {
        case 0: return Color.inkSecondary
        case 1, 2: return Color.accent
        default: return Color.ink
        }
    }

    private func background(_ value: Int, isSelected: Bool) -> Color {
        isSelected && (value == 1 || value == 2) ? Color.accentSoft : Color.clear
    }

    private func border(_ value: Int, isSelected: Bool) -> Color {
        guard isSelected else { return Color.gridHairline }
        switch value {
        case 1, 2: return Color.clear
        case 3: return Color.frostHighlightTop
        default: return Color.frostBorder
        }
    }

    static func severityLabel(_ severity: Int) -> String {
        L10n.string("severity." + String(severity))
    }
}

#Preview {
    struct Demo: View {
        @State private var values: [Symptom: Int] = [.nausea: 2, .injectionSiteReaction: 3]
        var body: some View {
            VStack(spacing: 0) {
                ForEach(Symptom.allCases.prefix(4)) { symptom in
                    SymptomChip(title: symptom.localizedName, severity: values[symptom] ?? 0) { values[symptom] = $0 }
                    BlueprintDivider(crosshair: .none)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.midnightElevated)
        }
    }
    return Demo().preferredColorScheme(.dark)
}
