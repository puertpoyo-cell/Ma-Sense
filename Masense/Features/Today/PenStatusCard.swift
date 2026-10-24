import SwiftUI

/// 펜 그림 (R13-1, D7). 남은 것은 채우고 쓴 것은 테두리만.
/// - 1회용 펜: 패키지(펜 4개, 약 한 달)마다 상자 하나, 펜 하나 = 막대 하나
/// - 여러 회 쓰는 펜: 펜 하나 = 막대 하나, 칸 하나 = 회차 하나
/// 주사기 모양을 그리지 않는다 (DESIGN_SYSTEM.md 7). 용량 수치 없음
struct PenGauge: View {
    let status: PenStatus
    /// 처방 구간 색 (R13-2, D7)
    var tint: Color = .accent

    var body: some View {
        Group {
            if status.isSingleUse {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: Spacing.s3)], alignment: .leading, spacing: Spacing.s3) {
                    ForEach(Array(status.packages.enumerated()), id: \.offset) { index, pens in
                        package(number: index + 1, pens: pens)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 64), spacing: Spacing.s3)], alignment: .leading, spacing: Spacing.s3) {
                    ForEach(Array(status.usedPerPen.enumerated()), id: \.offset) { _, used in
                        pen(used: used)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("pen.a11y \(status.penCount) \(status.remainingPens) \(status.remainingDoses)"))
    }

    /// 1회용 펜 패키지 하나: 펜을 나란히 세우고 아래에 "패키지 1 · 3개 남음"
    private func package(number: Int, pens: [Int]) -> some View {
        let remaining = pens.filter { $0 == 0 }.count
        return VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(spacing: 6) {
                ForEach(Array(pens.enumerated()), id: \.offset) { _, used in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(used > 0 ? Color.clear : tint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(used > 0 ? Color.inkTertiary : tint, lineWidth: 1)
                        )
                        .frame(width: 16, height: 52)
                }
            }
            .padding(Spacing.s2)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(remaining > 0 ? Color.frostBorder : Color.inkTertiary.opacity(0.5), lineWidth: 1)
            )
            Text("pen.package \(number) \(remaining)")
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(remaining > 0 ? Color.inkSecondary : Color.inkTertiary)
        }
    }

    private func pen(used: Int) -> some View {
        let remaining = status.dosesPerPen - used
        return VStack(spacing: Spacing.s1) {
            VStack(spacing: 2) {
                // 위에서부터 쓴 칸, 아래에 남은 칸 (남은 양이 바닥에 고인 모양)
                ForEach(0..<status.dosesPerPen, id: \.self) { slot in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(slot < used ? Color.clear : tint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(slot < used ? Color.inkTertiary : tint, lineWidth: 1)
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
    /// 지금 처방의 구간 색 (R13-2)
    var tint: Color = .accent

    var body: some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("pen.title")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                PenGauge(status: status, tint: tint)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text("pen.summary \(status.penCount) \(status.remainingPens)")
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Group {
                        let date = exhaustionDate?.formatted(.dateTime.month(.defaultDigits).day())
                        switch (status.isSingleUse, date) {
                        case let (true, date?):
                            Text("pen.detail.packages \(status.packages.count) \(date)")
                        case (true, nil):
                            Text("pen.detail.packages.noEstimate \(status.packages.count)")
                        case let (false, date?):
                            Text("pen.detail \(status.remainingDoses) \(date)")
                        case (false, nil):
                            Text("pen.detail.noEstimate \(status.remainingDoses)")
                        }
                    }
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                    if let memo = memo?.trimmingCharacters(in: .whitespacesAndNewlines), !memo.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
                            // 처방 구간 색 점 + 메모 그대로 (색은 처방 구분일 뿐)
                            Circle().fill(tint).frame(width: 6, height: 6).accessibilityHidden(true)
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
}

#Preview {
    PenStatusCard(status: PenStatus(usedPerPen: [1, 1, 1, 1, 1, 0, 0, 0], dosesPerPen: 1), exhaustionDate: .now.addingTimeInterval(21 * 86_400), memo: "처방 메모")
        .padding()
        .background(Color.midnight)
}
