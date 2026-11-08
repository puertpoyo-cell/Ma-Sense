import SwiftData
import SwiftUI

/// 투약 고치기 (D6 부위 → D33 시각·회차·부위, 2026-11-01 사람 요청 "꼬였을 때 쉽게 고치는 방법").
/// D45: 오늘 화면 "지난 투약 고치기"·지난 부위 줄, 기록 탭 투약 줄(누르기·길게 누르기)에서 연다. 날짜까지 고칠 수 있고,
/// 가장 최근 기록을 예정과 다른 날로 고치면 "다음부터 이 요일로"를 함께 고른다
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
    @State private var shiftsSchedule = false

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

                if let offset = scheduleOffset {
                    ScheduleShiftSection(offset: offset, administeredAt: administeredAt, preview: shiftPreview, isOn: $shiftsSchedule)
                }

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

    // MARK: D45 일정 옮기기 (이 처방의 가장 최근 기록일 때만)

    private var others: [DoseSnapshot] {
        (dose.prescription?.doseSnapshots ?? []).filter { $0.id != dose.id }
    }

    private var isLatest: Bool {
        !others.contains { !$0.isCancelled && $0.administeredAt > administeredAt }
    }

    private var editedSnapshot: DoseSnapshot {
        DoseSnapshot(id: dose.id, administeredAt: administeredAt, scheduledFor: dose.scheduledFor, site: site, sequence: sequence, isCancelled: dose.isCancelled)
    }

    private var scheduleOffset: Int? {
        guard let p = dose.prescription, isLatest, !dose.isCancelled else { return nil }
        let offset = ScheduleShiftRules.dayOffset(administeredAt: administeredAt, prescription: p.snapshot, doses: others, calendar: calendar)
        return offset == 0 ? nil : offset
    }

    private func shifted(_ p: Prescription) -> PrescriptionSnapshot {
        ScheduleShiftRules.shifted(
            p.snapshot, doses: others + [editedSnapshot],
            weekday: calendar.component(.weekday, from: administeredAt),
            hour: p.scheduledHour, minute: p.scheduledMinute,
            anchor: administeredAt, calendar: calendar
        )
    }

    private var shiftPreview: Date? {
        guard let p = dose.prescription else { return nil }
        return ScheduleShiftRules.upcoming(shifted(p), doses: others + [editedSnapshot], now: max(.now, administeredAt), calendar: calendar)
    }

    private func save() {
        if let site { dose.site = site }
        if shiftsSchedule, scheduleOffset != nil, let p = dose.prescription {
            let snapshot = shifted(p)
            p.applySchedule(snapshot)
            dose.scheduledFor = calendar.date(bySettingHour: snapshot.scheduledHour, minute: snapshot.scheduledMinute, second: 0, of: administeredAt) ?? administeredAt
        }
        dose.administeredAt = administeredAt
        dose.sequence = sequence
        try? context.save()
        Task { await services.refreshReminders(context: context) }
        dismiss()
        onSaved()
    }
}
