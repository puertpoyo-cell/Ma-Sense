import SwiftData
import SwiftUI

/// 투약 고치기 (D6 부위 → D33 시각·회차·부위, 2026-11-01 사람 요청 "꼬였을 때 쉽게 고치는 방법"). 기록 탭 투약 줄을 길게 눌러 연다.
struct SiteEditSheet: View {
    let dose: Dose
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allDoses: [Dose]
    @Environment(\.services) private var services
    @Environment(\.calendar) private var calendar
    @State private var site: BodySite?
    @State private var administeredAt: Date
    @State private var sequence: Int
    @State private var showsTimeWheel = false

    init(dose: Dose, onSaved: @escaping () -> Void = {}) {
        self.dose = dose
        self.onSaved = onSaved
        _site = State(initialValue: dose.site)
        _administeredAt = State(initialValue: dose.administeredAt)
        _sequence = State(initialValue: dose.sequence)
    }

    var body: some View {
        // 부위는 몸 기준이라 모든 처방의 기록을 본다 (R6)
        let snapshots = allDoses.map(\.snapshot)
        NavigationStack {
            Form {
                // D33 시각: 글자로 크게, 누르면 30분 단위 휠
                Section {
                    Button {
                        withAnimation { showsTimeWheel.toggle() }
                    } label: {
                        HStack {
                            Text(administeredAt.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute()))
                                .font(Typography.metricLarge.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Image(systemName: showsTimeWheel ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.inkSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if showsTimeWheel {
                        HalfHourDatePicker(selection: $administeredAt, maximum: DoseTimeRules.roundedDown(.now, calendar: calendar))
                            .frame(maxWidth: .infinity)
                    }
                    // D33 회차: "저번 패키지의 4번째 펜"처럼 바로잡기
                    Stepper(value: $sequence, in: 1...max(dose.prescription?.totalDoses ?? 1, sequence, 1)) {
                        LabeledContent("dose.sequence.label") {
                            Text("dose.edit.sequence \(sequence)")
                                .monospacedDigit()
                        }
                    }
                } header: {
                    SectionHeaderText("dose.time")
                }
                .frostRow()

                Section {
                    BodyMapView(
                        selection: $site,
                        history: SiteRules.siteHistory(doses: snapshots),
                        lastUseBySite: SiteRules.lastUseBySite(doses: snapshots)
                    )
                    .padding(.vertical, Spacing.s3)
                } header: {
                    SectionHeaderText("dose.site")
                } footer: {
                    Text("bodymap.hint")
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("site.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save", action: save)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func save() {
        if let site { dose.site = site }
        dose.administeredAt = administeredAt
        dose.sequence = sequence
        try? context.save()
        Task { await services.refreshReminders(context: context) }
        dismiss()
        onSaved()
    }
}
