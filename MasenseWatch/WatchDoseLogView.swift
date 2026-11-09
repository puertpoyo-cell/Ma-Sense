import SwiftData
import SwiftUI
import WatchKit

/// 워치에서 투약 기록: 부위만 고르면 지금(30분 단위 내림) 시각으로 저장. iCloud로 iPhone에 넘어간다.
/// 바디맵 대신 부위 목록과 마지막 사용 날짜 (R6 추천 없음)
struct WatchDoseLogView: View {
    let prescription: Prescription

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Query private var allDoses: [Dose]
    @State private var saved = false

    var body: some View {
        let lastUse = SiteRules.lastUseBySite(doses: allDoses.map(\.snapshot))
        List {
            if saved {
                Label("toast.recorded", systemImage: "checkmark.circle.fill")
            }
            ForEach(BodySite.allCases) { site in
                Button { save(site) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: site.localizedName)
                        if let date = lastUse[site] {
                            Text(verbatim: date.formatted(.dateTime.month(.defaultDigits).day()))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(saved)
            }
            Button { save(nil) } label: {
                Text("site.unknown")
            }
            .disabled(saved)
        }
        .navigationTitle("action.logDose")
    }

    private func save(_ site: BodySite?) {
        let now = Date.now
        let at = DoseTimeRules.roundedDown(now, calendar: calendar)
        let doses = prescription.doseSnapshots
        let cycles = CycleRules.cycles(for: prescription.snapshot, doses: doses, now: now, until: .distantFuture, calendar: calendar)
        let dose = Dose(
            administeredAt: at,
            scheduledFor: CycleRules.cycle(containing: at, in: cycles)?.scheduledDate ?? at,
            site: site,
            sequence: PrescriptionRules.nextSequence(doses: doses)
        )
        context.insert(dose)
        dose.prescription = prescription
        try? context.save()
        WKInterfaceDevice.current().play(.success)
        saved = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        }
    }
}
