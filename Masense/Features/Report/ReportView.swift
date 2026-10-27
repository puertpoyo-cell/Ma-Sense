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
    @Query(sort: \ClinicQuestion.createdAt) private var questions: [ClinicQuestion]
    @Query(sort: \LabResult.measuredAt) private var labResults: [LabResult]

    @State private var period: ReportPeriod?
    @State private var showsQuestions = false
    @State private var pdfURL: URL?
    @State private var showsPurchase = false
    @State private var overflows = false

    private var activePrescription: Prescription? { prescriptions.first { $0.isActive } }
    private var settings: UserSettings? { settingsList.first }
    private var isPurchased: Bool { settings?.hasPurchasedPro ?? false }
    private var accent: Color { ReportPage.accent(forTheme: settings?.reportTheme ?? "midnight") }

    /// 이번에 고른 기간, 없으면 설정에 저장한 기본 기간, 없으면 R12 기본값
    private var selectedPeriod: ReportPeriod {
        period ?? ReportBuilder.defaultPeriod(
            saved: settings?.reportDefaultPeriod.flatMap(ReportPeriod.init(storageValue:)),
            hasActivePrescription: activePrescription != nil,
            hasNextClinicDate: activePrescription?.nextClinicDate != nil
        )
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
                        questionsCard
                        periodPicker
                        ReportPreviewView(report: report, accent: accent)
                            .task(id: report) {
                                overflows = !ReportRenderer.fitsOnePage(report, calendar: calendar)
                            }
                        if overflows {
                            NoticeLine("report.overflow")
                        }
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
        .sheet(isPresented: $showsQuestions) {
            ClinicQuestionsSheet()
        }
    }

    // MARK: 진료 때 물어볼 것 (D6, R15)

    /// 아직 묻지 않은 것 앞 3개와 나머지 수. 적은 내용은 리포트 G 위에 실린다
    private var questionsCard: some View {
        let pending = ClinicQuestionRules.pending(questions.map(\.snapshot))
        return FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("clinic.questions.title")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                if pending.isEmpty {
                    Text("clinic.questions.empty")
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        ForEach(pending.prefix(3)) { question in
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                                Image(systemName: "circle")
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.inkSecondary)
                                    .accessibilityHidden(true)
                                Text(verbatim: question.text)
                                    .font(Typography.body)
                                    .foregroundStyle(Color.ink)
                                    .lineLimit(2)
                            }
                        }
                        if pending.count > 3 {
                            Text("clinic.questions.more \(pending.count - 3)")
                                .font(Typography.caption)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                }
                AdaptiveStack(spacing: Spacing.s2) {
                    GhostButton("clinic.questions.manage") { showsQuestions = true }
                    // 증상 기록을 보고 물어볼 것으로 옮긴다 (D9)
                    NavigationLink("symptom.flow.open") { SymptomFlowView() }
                        .buttonStyle(.ghost)
                }
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
            heightCm: settings?.heightCm,
            questions: questions.map(\.snapshot),
            labs: labResults.map(\.snapshot),
            now: now,
            calendar: calendar,
            appVersion: AppConfig.appVersion
        )
    }
}

#Preview {
    NavigationStack {
        ReportView()
    }
    .modelContainer(ModelContainer.previewWithSampleData)
    .preferredColorScheme(.dark)
}
