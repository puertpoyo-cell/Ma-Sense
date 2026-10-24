import Foundation
import SwiftUI

/// 설정 > 처방의 "이전 처방" 접힌 목록 (SCREENS.md S6). 시작일~종료일, 메모, 회차 수. 처방은 지우지 않고 이력으로 남는다 (R13)
enum PrescriptionHistory {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let startDate: Date
        /// 종료일이 없는 보관 처방(D4 이전 데이터)은 nil
        let endDate: Date?
        /// 사용자 메모 그대로. 공백만 있으면 nil (앱은 해석하지 않는다, COMPLIANCE.md 2.2)
        let memo: String?
        /// 취소하지 않은 투약 기록 수
        let recordedDoses: Int
        let totalDoses: Int
        /// 처방 구간 색 자리 (R13-2). 활성 처방까지 넘겨야 순서가 맞는다
        var colorSlot: Int = 0
    }

    /// 활성이 아닌 처방을 최근 시작 순으로. 색 자리는 넘긴 처방 전체(활성 포함)의 시작 순서로 센다
    static func rows(_ prescriptions: [Prescription]) -> [Row] {
        let slots = prescriptions.colorSlots
        return prescriptions
            .filter { !$0.isActive }
            .sorted { $0.startDate > $1.startDate }
            .map { p in
                let memo = p.doseLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
                return Row(
                    id: p.id,
                    startDate: p.startDate,
                    endDate: p.endDate,
                    memo: memo?.isEmpty == false ? memo : nil,
                    recordedDoses: p.usedDoses,
                    totalDoses: p.totalDoses,
                    colorSlot: slots[p.id] ?? 0
                )
            }
    }
}

/// 이전 처방 한 줄
struct PrescriptionHistoryRowView: View {
    let row: PrescriptionHistory.Row

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Group {
                if let endDate = row.endDate {
                    Text("settings.prescription.history.range \(dayText(row.startDate)) \(dayText(endDate))")
                } else {
                    Text("settings.prescription.history.since \(dayText(row.startDate))")
                }
            }
            .monospacedDigit()
            if let memo = row.memo {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
                    Circle().fill(Color.prescription(slot: row.colorSlot)).frame(width: 6, height: 6).accessibilityHidden(true)
                    Text(verbatim: memo)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Text("settings.prescription.history.doses \(row.recordedDoses) \(row.totalDoses)")
                .monospacedDigit()
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.vertical, Spacing.s1)
        .accessibilityElement(children: .combine)
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.defaultDigits).day())
    }
}
