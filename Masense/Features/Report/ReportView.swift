import SwiftData
import SwiftUI

/// S5 리포트. 기간 선택 → A4 미리보기 → PDF 내보내기(구매 시 공유, 미구매 시 구매 시트).
struct ReportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @Query(sort: \Prescription.startDate) private var prescriptions: [Prescription]
    @Query(sort: \ConditionCheck.checkedAt) private var checks: [ConditionCheck]
    @Query(sort: \WeightSample.measuredAt) private var weights: [WeightSample]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \ProteinEntry.date) private var proteins: [ProteinEntry]
    @Query(sort: \StrengthSession.startedAt) private var sessions: [StrengthSession]

    @State private var period: ReportPeriod?
    @State private var pdfURL: URL?
    @State private var showsPurchase = false

    private var activePrescription: Prescription? { prescriptions.first { $0.isActive } }
    private var settings: UserSettings? { settingsList.first }
    private var isPurchased: Bool { settings?.hasPurchasedPro ?? false }
    private var accent: Color { ReportPage.accent(forTheme: settings?.reportTheme ?? "midnight") }

    private var selectedPeriod: ReportPeriod {
        period ?? ReportBuilder.defaultPeriod(hasNextClinicDate: activePrescription?.nextClinicDate != nil)
    }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    if prescriptions.isEmpty {
                        Text("report.empty")
                            .font(Typography.body)
                            .foregroundStyle(Color.inkSecondary)
                    } else {
                        let report = makeReport(now: timeline.date)
                        periodPicker
                        ReportPreviewView(report: report, accent: accent)
                        exportControls
                            .task(id: ExportKey(report: report, isPurchased: isPurchased)) {
                                await renderIfPurchased(report)
                            }
                    }
                    NoticeLine("report.disclaimer")
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s4)
            }
        }
        .midnightBackground()
        .navigationTitle("tab.report")
        .sheet(isPresented: $showsPurchase) {
            if let settings {
                ReportPurchaseSheet(settings: settings)
            }
        }
    }

    // MARK: 기간 (R12)

    private var periodPicker: some View {
        Picker("report.periodPicker", selection: Binding(get: { selectedPeriod }, set: { period = $0 })) {
            if activePrescription != nil {
                Text("report.period.sinceClinic").tag(ReportPeriod.sinceClinic)
            }
            ForEach(ReportPeriod.weekChoices, id: \.self) { weeks in
                Text("report.period.weeks \(weeks)").tag(ReportPeriod.weeks(weeks))
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: 내보내기

    @ViewBuilder
    private var exportControls: some View {
        if isPurchased {
            if let pdfURL {
                ShareLink(item: pdfURL, preview: SharePreview(pdfURL.lastPathComponent)) {
                    Text("report.export")
                }
                .buttonStyle(.primary)
            } else {
                PrimaryButton("report.export") {}
                    .disabled(true)
                    .opacity(0.4)
            }
        } else {
            PrimaryButton("report.export") { showsPurchase = true }
        }
    }

    private struct ExportKey: Equatable {
        let report: ClinicReport
        let isPurchased: Bool
    }

    private func renderIfPurchased(_ report: ClinicReport) async {
        guard isPurchased else {
            pdfURL = nil
            return
        }
        pdfURL = try? ReportRenderer.writePDF(report: report, accent: accent, calendar: calendar)
    }

    private func makeReport(now: Date) -> ClinicReport {
        let interval = ReportBuilder.interval(
            for: selectedPeriod,
            activePrescriptionStart: activePrescription?.startDate,
            now: now,
            calendar: calendar
        )
        return ReportBuilder.build(
            period: interval,
            prescriptions: prescriptions.map {
                ReportBuilder.PrescriptionData(prescription: $0.snapshot, doses: $0.doseSnapshots, isActive: $0.isActive)
            },
            checks: checks.compactMap(\.snapshot),
            weights: weights.map(\.snapshot),
            proteins: proteins.map(\.snapshot),
            sessions: sessions.map(\.snapshot),
            proteinTarget: settings?.proteinTargetGrams,
            now: now,
            calendar: calendar,
            appVersion: DataExportService.appVersion
        )
    }
}

#Preview {
    NavigationStack {
        ReportView()
    }
    .modelContainer(ModelContainer.preview)
    .preferredColorScheme(.dark)
}
