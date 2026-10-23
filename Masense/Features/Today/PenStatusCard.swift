import SwiftUI

/// 펜 그림 (R13-1, D7). 펜 하나 = 둥근 막대 하나, 칸 하나 = 회차 하나. 남은 회차는 채우고 쓴 회차는 테두리만.
/// 주사기 모양을 그리지 않는다 (DESIGN_SYSTEM.md 7). 용량 수치 없음
struct PenGauge: View {
    let status: PenStatus

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 64), spacing: Spacing.s3)], alignment: .leading, spacing: Spacing.s3) {
            ForEach(Array(status.usedPerPen.enumerated()), id: \.offset) { _, used in
                pen(used: used)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("pen.a11y \(status.penCount) \(status.remainingPens) \(status.remainingDoses)"))
    }

    private func pen(used: Int) -> some View {
        let remaining = status.dosesPerPen - used
        return VStack(spacing: Spacing.s1) {
            VStack(spacing: 2) {
                // 위에서부터 쓴 칸, 아래에 남은 칸 (남은 양이 바닥에 고인 모양)
                ForEach(0..<status.dosesPerPen, id: \.self) { slot in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(slot < used ? Color.clear : Color.accent)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(slot < used ? Color.inkTertiary : Color.accent, lineWidth: 1)
                        )
                        .frame(height: max(48 / CGFloat(status.dosesPerPen), 6))
                }
            }
            .padding(3)
            .frame(width: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(remaining > 0 ? Color.frostBorder : Color.inkTertiary.opacity(0.5), lineWidth: 1)
            )
            Text(verbatim: "\(remaining)/\(status.dosesPerPen)")
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(remaining > 0 ? Color.inkSecondary : Color.inkTertiary)
        }
    }
}

/// 오늘 1-1b "남은 펜" 카드 (SCREENS.md, D7). 처방 메모는 사용자가 적은 그대로만 (해석·계산 없음)
struct PenStatusCard: View {
    let status: PenStatus
    let exhaustionDate: Date?
    let memo: String?

    var body: some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("pen.title")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                PenGauge(status: status)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("pen.summary \(status.penCount) \(status.remainingPens)")
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Group {
                        if let exhaustionDate {
                            Text("pen.detail \(status.remainingDoses) \(exhaustionDate.formatted(.dateTime.month(.defaultDigits).day()))")
                        } else {
                            Text("pen.detail.noEstimate \(status.remainingDoses)")
                        }
                    }
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                    if let memo = memo?.trimmingCharacters(in: .whitespacesAndNewlines), !memo.isEmpty {
                        Text("pen.memo \(memo)")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }
}

#Preview {
    PenStatusCard(status: PenStatus(usedPerPen: [4, 2, 0, 0], dosesPerPen: 4), exhaustionDate: .now.addingTimeInterval(70 * 86_400), memo: "처방 메모")
        .padding()
        .background(Color.midnight)
}
