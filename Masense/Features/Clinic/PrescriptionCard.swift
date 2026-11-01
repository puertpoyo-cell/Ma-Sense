import SwiftData
import SwiftUI

/// D29 지금 처방 카드 (2026-11-01 사람 요청 "설정에만 있던 처방 정보는 중요 정보라 진료 탭에 제대로").
/// 투약 요일·시각, 남은 회차와 펜 그림, 소진 예상일, 처방 메모(적은 그대로)를 한 장에.
/// 여기서 새 펜 받음·처방 수정·새 처방 시작까지. 다음 진료일은 위 다음 진료 카드에 있다
struct PrescriptionCard: View {
    let prescription: Prescription?
    var tint: Color = .accent
    var onRefill: () -> Void
    /// D33 남은 수 맞추기
    var onAdjust: () -> Void = {}
    var onEdit: () -> Void
    var onNew: () -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("clinic.prescription.title")
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    Spacer()
                    if prescription != nil {
                        Menu {
                            Button("settings.prescription.edit", action: onEdit)
                            Button("settings.prescription.new", action: onNew)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        .accessibilityLabel(Text("clinic.prescription.more"))
                    }
                }
                if let prescription {
                    content(prescription)
                } else {
                    Text("today.empty.noPrescription")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                    PrimaryButton("settings.prescription.new", action: onNew)
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ p: Prescription) -> some View {
        let status = PrescriptionRules.penStatus(p: p.snapshot, doses: p.doseSnapshots)
        let remaining = status.isSingleUse ? status.remainingPens : status.remainingDoses
        let total = status.isSingleUse ? status.penCount : status.penCount * status.dosesPerPen
        HStack(alignment: .top, spacing: Spacing.s4) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("clinic.prescription.schedule")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                Text(verbatim: scheduleText(p))
                    .font(Typography.label.weight(.semibold))
                    .foregroundStyle(Color.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.s1) {
                Text(status.isSingleUse ? "glance.pens" : "glance.doses")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                (Text(verbatim: "\(remaining)/\(total)").font(Typography.metricLarge)
                    + Text(status.isSingleUse ? "glance.unit.pens" : "unit.times").font(Typography.caption).foregroundColor(Color.inkSecondary))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
            }
        }
        PenGauge(status: status, tint: tint)
        if remaining > 0, let exhaustion = PrescriptionRules.exhaustionEstimate(p: p.snapshot, doses: p.doseSnapshots, now: .now, calendar: calendar) {
            Text("glance.exhaustion \(exhaustion.formatted(.dateTime.month(.defaultDigits).day()))")
                .font(Typography.caption)
                .foregroundStyle(Color.inkSecondary)
        }
        if let memo = p.doseLabel {
            // 메모는 해석하지 않고 적은 그대로 (COMPLIANCE.md 2.2)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                Text("prescription.memo")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                Text(verbatim: memo)
                    .font(Typography.label.weight(.semibold))
                    .foregroundStyle(Color.ink)
            }
        }
        if remaining == 0 {
            PrimaryButton("refill.title", action: onRefill)
        }
        AdaptiveStack(spacing: Spacing.s2) {
            if remaining > 0 {
                GhostButton("refill.title", action: onRefill)
            }
            GhostButton("remaining.title", action: onAdjust)
        }
    }

    private func scheduleText(_ p: Prescription) -> String {
        let symbols = calendar.weekdaySymbols
        let day = symbols.indices.contains(p.scheduledWeekday - 1) ? symbols[p.scheduledWeekday - 1] : ""
        let time = calendar.date(bySettingHour: p.scheduledHour, minute: p.scheduledMinute, second: 0, of: p.startDate)
        return [day, time?.formatted(date: .omitted, time: .shortened) ?? ""].joined(separator: " ")
    }
}
