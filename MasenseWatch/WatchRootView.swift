import SwiftData
import SwiftUI

/// 워치 첫 화면: 다음 투약 한눈에 + 투약 기록 + 마선생에게 묻기
struct WatchRootView: View {
    @Query(filter: #Predicate<Prescription> { $0.isActive }) private var active: [Prescription]
    @Query private var allDoses: [Dose]
    @Environment(\.calendar) private var calendar
    @State private var router = WatchRouter.shared

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                List {
                    if let prescription = active.first {
                        WatchNextDoseCard(prescription: prescription, allDoses: allDoses.map(\.snapshot), now: timeline.date)
                        NavigationLink {
                            WatchDoseLogView(prescription: prescription)
                        } label: {
                            Label("action.logDose", systemImage: "plus.circle.fill")
                        }
                    } else {
                        Text("watch.noPrescription")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        WatchCoachView()
                    } label: {
                        HStack(spacing: 8) {
                            WatchCoachFace(size: 28)
                            Text("watch.coach.ask")
                        }
                    }
                }
            }
            .navigationTitle("watch.title")
            .navigationDestination(isPresented: $router.opensDoseLog) {
                if let prescription = active.first {
                    WatchDoseLogView(prescription: prescription)
                }
            }
        }
    }
}

/// 다음 투약 카드: "D-3 · 목 오후 8:00" / "오늘" / "예정일이 지났습니다" / "이번 주 기록 완료". 지난 부위
struct WatchNextDoseCard: View {
    let prescription: Prescription
    let allDoses: [DoseSnapshot]
    let now: Date
    @Environment(\.calendar) private var calendar

    var body: some View {
        let p = prescription.snapshot
        let doses = prescription.doseSnapshots
        let cycles = CycleRules.cycles(for: p, doses: doses, now: now, until: now.addingTimeInterval(28 * 86_400), calendar: calendar)
        VStack(alignment: .leading, spacing: 4) {
            Text("watch.nextDose")
                .font(.caption2)
                .foregroundStyle(.secondary)
            switch CycleRules.nextDose(cycles: cycles, doses: doses, now: now) {
            case let .due(cycle, _)?:
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: cycle.scheduledDate)).day ?? 0
                Text(days == 0 ? String(localized: "watch.today") : String(format: L10n.string("watch.dMinus %lld"), days))
                    .font(.title2.weight(.semibold))
                Text(verbatim: cycle.scheduledDate.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(.footnote)
            case .overdue?:
                Text("watch.overdue")
                    .font(.headline)
            case let .done(_, next)?:
                Text("watch.done")
                    .font(.headline)
                if let next {
                    Text(verbatim: next.scheduledDate.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))
                        .font(.footnote)
                }
            case nil:
                Text("watch.exhausted")
                    .font(.headline)
            }
            if let last = SiteRules.siteHistory(doses: allDoses).first {
                Text(String(format: L10n.string("watch.lastSite %@"), last.site.localizedName))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(String(format: L10n.string("watch.remaining %lld"), PrescriptionRules.remainingDoses(p: p, doses: doses)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
