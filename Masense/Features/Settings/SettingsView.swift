import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

/// S6 설정. 처방 · 알림 · 연동 · 구매 · 데이터 · 정보. 리포트 섹션(테마·기본 기간)은 M1-d.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [UserSettings]

    var body: some View {
        Group {
            if let settings = settingsList.first {
                SettingsForm(settings: settings)
            } else {
                MidnightBackground()
            }
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 설정 레코드가 없으면 기본값으로 만든다
            if settingsList.isEmpty {
                _ = try? UserSettings.current(in: context)
                try? context.save()
            }
        }
    }
}

private struct SettingsForm: View {
    @Bindable var settings: UserSettings

    private enum Sheet: Identifiable {
        case editPrescription, newPrescription, roleNotice
        /// `result`는 DEBUG 스크린샷용 결과 화면 미리보기
        case importFile(ExportDocument, result: ExportCodec.ImportResult? = nil)

        var id: String {
            switch self {
            case .editPrescription: "editPrescription"
            case .newPrescription: "newPrescription"
            case .roleNotice: "roleNotice"
            case .importFile: "importFile"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @Environment(\.calendar) private var calendar
    @Environment(\.openURL) private var openURL
    @Environment(\.restartOnboarding) private var restartOnboarding
    @Query(filter: #Predicate<Prescription> { $0.isActive })
    private var activePrescriptions: [Prescription]
    @Query(sort: \WeightSample.measuredAt, order: .reverse)
    private var weights: [WeightSample]

    @State private var sheet: Sheet?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var product: StoreProductInfo?
    @State private var storeNotice: LocalizedStringKey?
    @State private var exportURL: URL?
    @State private var confirmsDelete = false
    @State private var confirmsDeleteAgain = false
    @State private var importsFile = false
    @State private var importError: ExportCodec.ImportError?

    private var prescription: Prescription? { activePrescriptions.first }

    /// 알림에 영향을 주는 설정. 바뀌면 알림을 다시 등록한다 (R4)
    private var notificationSignature: [Int] {
        [
            settings.reminderEnabled ? 1 : 0,
            settings.eveningReminderHour,
            settings.conditionCheckEnabled ? 1 : 0,
            settings.clinicReminderDaysBefore,
            settings.exhaustionReminderDosesLeft,
        ]
    }

    var body: some View {
        Form {
            prescriptionSection
            notificationSection
            proteinSection
            if services.healthKit.isAvailable {
                healthSection
            }
            reportSection
            purchaseSection
            dataSection
            infoSection
        }
        .scrollContentBackground(.hidden)
        .midnightBackground()
        .foregroundStyle(Color.ink)
        .onChange(of: notificationSignature) {
            try? context.save()
            Task { await services.refreshNotifications(context: context) }
        }
        .task {
            notificationStatus = await services.notifications.authorizationStatus()
            product = await services.store.loadProduct()
            settings.hasPurchasedPro = await services.store.refreshEntitlement()
            #if DEBUG
            openImportForScreenshot()
            #endif
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .editPrescription: PrescriptionSheet(editing: prescription)
            case .newPrescription: PrescriptionSheet()
            case .roleNotice: RoleNoticeSheet()
            case let .importFile(document, result): ImportSheet(document: document, result: result)
            }
        }
        .fileImporter(isPresented: $importsFile, allowedContentTypes: [.masenseExport, .json]) { selection in
            readImportFile(selection)
        }
        .alert("import.error.title", isPresented: showsImportError) {
            Button("action.ok") {}
        } message: {
            Text(importErrorMessage)
        }
        .confirmationDialog("settings.data.deleteAll.confirm1", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("settings.data.deleteAll.continue") { confirmsDeleteAgain = true }
            Button("action.cancel", role: .cancel) {}
        }
        .alert("settings.data.deleteAll.confirm2", isPresented: $confirmsDeleteAgain) {
            Button("settings.data.deleteAll.final") { deleteAll() }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("settings.data.deleteAll.message")
        }
    }

    // MARK: 처방

    private var prescriptionSection: some View {
        Section {
            if let prescription {
                LabeledContent("prescription.weekday") {
                    Text(scheduleText(prescription))
                }
                LabeledContent("settings.prescription.remaining") {
                    Text("today.remaining \(prescription.remainingDoses) \(prescription.totalDoses)")
                        .monospacedDigit()
                }
                if let clinic = prescription.nextClinicDate {
                    LabeledContent("prescription.nextClinic") {
                        Text(clinic.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated)))
                    }
                }
                if let memo = prescription.doseLabel {
                    // 메모는 해석하지 않고 적은 그대로 보여 준다 (COMPLIANCE.md 2.2)
                    LabeledContent("prescription.memo") {
                        Text(verbatim: memo)
                    }
                }
                Button("settings.prescription.edit") { sheet = .editPrescription }
            } else {
                Text("today.empty.noPrescription")
                    .foregroundStyle(Color.inkSecondary)
            }
            Button("settings.prescription.new") { sheet = .newPrescription }
        } header: {
            SectionHeaderText("settings.section.prescription")
        }
        .frostRow()
    }

    private func scheduleText(_ p: Prescription) -> String {
        let day = calendar.weekdaySymbols[safe: p.scheduledWeekday - 1] ?? ""
        let time = calendar.date(bySettingHour: p.scheduledHour, minute: p.scheduledMinute, second: 0, of: p.startDate)
        return [day, time?.formatted(date: .omitted, time: .shortened) ?? ""].joined(separator: " ")
    }

    // MARK: 알림

    private var notificationSection: some View {
        Section {
            switch notificationStatus {
            case .denied:
                NoticeLine("settings.notifications.denied")
                Button("settings.openSystemSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .notDetermined:
                Button("onboarding.permissions.notifications") {
                    Task {
                        _ = await services.notifications.requestAuthorization()
                        notificationStatus = await services.notifications.authorizationStatus()
                        await services.refreshNotifications(context: context)
                    }
                }
            default:
                EmptyView()
            }

            Toggle("settings.notifications.dose", isOn: $settings.reminderEnabled)
            Stepper(value: $settings.eveningReminderHour, in: 12...23) {
                LabeledContent("settings.notifications.evening") {
                    Text(hourText(settings.eveningReminderHour)).monospacedDigit()
                }
            }
            .disabled(!settings.reminderEnabled)
            Toggle("settings.notifications.condition", isOn: $settings.conditionCheckEnabled)
            Stepper(value: $settings.clinicReminderDaysBefore, in: 0...7) {
                LabeledContent("settings.notifications.clinic") {
                    if settings.clinicReminderDaysBefore == 0 {
                        Text("settings.sameDay")
                    } else {
                        Text("settings.daysBefore \(settings.clinicReminderDaysBefore)").monospacedDigit()
                    }
                }
            }
            Stepper(value: $settings.exhaustionReminderDosesLeft, in: 0...4) {
                LabeledContent("settings.notifications.exhaustion") {
                    Text("settings.dosesLeft \(settings.exhaustionReminderDosesLeft)").monospacedDigit()
                }
            }
            .disabled(!settings.reminderEnabled)
        } header: {
            SectionHeaderText("settings.section.notifications")
        }
        .frostRow()
    }

    private func hourText(_ hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: calendar.startOfDay(for: .now)) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: 단백질 (M2, R9)

    private var proteinSection: some View {
        Section {
            // 목표는 사용자·의료진이 정해 입력한다. 앱이 기본값을 제안하지 않는다
            LabeledContent("settings.protein.target") {
                HStack(spacing: Spacing.s1) {
                    TextField("settings.protein.target.placeholder", value: $settings.proteinTargetGrams, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                    Text(verbatim: "g").foregroundStyle(Color.inkSecondary)
                }
            }
            // 권고 범위는 출처가 정해진 뒤에만 보인다 (COMPLIANCE.md 2.2)
            if let source = AppConfig.proteinGuideSource, let weight = guideWeight {
                let range = ProteinRules.proteinGuideRange(weightKg: weight)
                LabeledContent("settings.protein.guideRange") {
                    Text("protein.range \(range.lowerBound) \(range.upperBound)").monospacedDigit()
                }
                Text("settings.protein.guideWeight \(ReportBuilder.kilograms(weight))")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
                NoticeLine("protein.guide")
                Text(LocalizedStringKey(source))
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkTertiary)
            }
        } header: {
            SectionHeaderText("settings.section.protein")
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("protein.noTarget.hint")
                Text("protein.estimateNote")
            }
        }
        .frostRow()
        .onChange(of: settings.proteinTargetGrams) {
            if let value = settings.proteinTargetGrams, value <= 0 {
                settings.proteinTargetGrams = nil
            }
            try? context.save()
        }
    }

    /// 안내 계산용 체중: 직접 정한 값, 없으면 최근 체중
    private var guideWeight: Double? {
        settings.bodyWeightForGuideKg ?? weights.first?.kilograms
    }

    // MARK: 연동 (Info.plist 키가 있을 때만)

    private var healthSection: some View {
        Section {
            LabeledContent("settings.health.status") {
                Text(LocalizedStringKey(settings.healthKitAuthorized ? "settings.health.connected" : "settings.health.notConnected"))
            }
            Button(LocalizedStringKey(settings.healthKitAuthorized ? "settings.health.sync" : "onboarding.permissions.health")) {
                Task { await connectHealth() }
            }
        } header: {
            SectionHeaderText("settings.section.health")
        }
        .frostRow()
    }

    private func connectHealth() async {
        let granted = (try? await services.healthKit.requestReadAuthorization()) ?? false
        settings.healthKitAuthorized = granted
        if granted {
            try? await HealthSyncService.syncAll(reader: services.healthKit, context: context)
        }
        try? context.save()
    }

    // MARK: 리포트 (테마는 구매 후)

    private var reportSection: some View {
        Section {
            Picker("settings.report.theme", selection: $settings.reportTheme) {
                ForEach(ReportTheme.allCases) { theme in
                    Text(LocalizedStringKey(theme.titleKey)).tag(theme.rawValue)
                }
            }
            .disabled(!settings.hasPurchasedPro)
            LabeledContent("settings.report.accent") {
                RoundedRectangle(cornerRadius: 3)
                    .fill(ReportPage.accent(forTheme: settings.reportTheme))
                    .frame(width: 44, height: 8)
                    .accessibilityHidden(true)
            }
            // 리포트 탭을 열 때 처음 선택되는 기간 (R12). 구매와 무관
            Picker("settings.report.defaultPeriod", selection: reportPeriodSelection) {
                Text("settings.report.defaultPeriod.auto").tag(Self.automaticPeriod)
                Text("report.period.sinceClinic").tag(ReportPeriod.sinceClinic.storageValue)
                ForEach(ReportPeriod.weekChoices, id: \.self) { weeks in
                    Text("report.period.weeks \(weeks)").tag(ReportPeriod.weeks(weeks).storageValue)
                }
            }
        } header: {
            SectionHeaderText("settings.section.report")
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("settings.report.defaultPeriod.footer")
                if !settings.hasPurchasedPro {
                    Text("settings.report.themeLocked")
                }
            }
        }
        .frostRow()
        .onChange(of: settings.reportTheme) { try? context.save() }
        .onChange(of: settings.reportDefaultPeriod) { try? context.save() }
    }

    private static let automaticPeriod = "auto"

    /// nil(자동)을 Picker 태그로 다루기 위한 연결
    private var reportPeriodSelection: Binding<String> {
        Binding(
            get: { settings.reportDefaultPeriod ?? Self.automaticPeriod },
            set: { settings.reportDefaultPeriod = $0 == Self.automaticPeriod ? nil : $0 }
        )
    }

    // MARK: 구매

    private var purchaseSection: some View {
        Section {
            if settings.hasPurchasedPro {
                Text("settings.purchase.owned")
            } else if let product {
                Button {
                    Task { await purchase() }
                } label: {
                    LabeledContent {
                        Text(verbatim: product.displayPrice).monospacedDigit()
                    } label: {
                        Text(verbatim: product.displayName)
                    }
                }
            }
            Button("settings.purchase.restore") {
                Task { await restore() }
            }
            if let storeNotice {
                NoticeLine(storeNotice)
            }
        } header: {
            SectionHeaderText("settings.section.purchase")
        } footer: {
            Text("settings.purchase.footer")
        }
        .frostRow()
    }

    private func purchase() async {
        do {
            settings.hasPurchasedPro = try await services.store.purchase() || settings.hasPurchasedPro
            storeNotice = nil
        } catch {
            storeNotice = "settings.purchase.failed"
        }
        try? context.save()
    }

    private func restore() async {
        do {
            settings.hasPurchasedPro = try await services.store.restore()
            storeNotice = settings.hasPurchasedPro ? nil : "settings.purchase.nothingToRestore"
        } catch {
            storeNotice = "settings.purchase.failed"
        }
        try? context.save()
    }

    // MARK: 데이터

    private var dataSection: some View {
        Section {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("settings.data.share", systemImage: "square.and.arrow.up")
                }
            } else {
                Button("settings.data.export") {
                    exportURL = try? ExportService.writeExportFile(context: context)
                }
            }
            Button("settings.data.import") { importsFile = true }
            // 빨강 금지: destructive 역할 대신 일반 버튼 + 2단계 확인
            Button("settings.data.deleteAll") { confirmsDelete = true }
        } header: {
            SectionHeaderText("settings.section.data")
        } footer: {
            // 내보내기 전 한 줄 안내 (EXPORT_FORMAT.md 보안·프라이버시)
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("settings.data.export.notice")
                Text("data.local")
            }
        }
        .frostRow()
    }

    /// 형식·버전을 먼저 확인하고(규칙 1~3), 맞으면 방식을 고르는 시트를 연다
    private func readImportFile(_ selection: Result<URL, Error>) {
        do {
            let document = try ExportService.readFile(at: selection.get())
            sheet = .importFile(document)
        } catch let error as ExportCodec.ImportError {
            importError = error
        } catch {
            importError = .unreadable
        }
    }

    #if DEBUG
    /// 실행 인자 `-route sheet.import`, `sheet.import.result` (ScreenshotRoute). 표본 데이터를 내보낸 문서로 시트를 연다
    private func openImportForScreenshot() {
        guard let route = ScreenshotRoute.current, route == .importSheet || route == .importResult,
              let document = try? ExportService.makeDocument(context: context, now: Date())
        else { return }
        let result = route == .importResult ? ExportCodec.importPlan(document, mode: .replace, existingIDs: []).result : nil
        sheet = .importFile(document, result: result)
    }
    #endif

    private var showsImportError: Binding<Bool> {
        Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
    }

    private var importErrorMessage: LocalizedStringKey {
        switch importError {
        case .notMasenseExport?: "import.error.notMasense"
        case .needsAppUpdate?: "import.error.needsUpdate"
        case .unreadable?, nil: "import.error.unreadable"
        }
    }

    private func deleteAll() {
        guard (try? ExportService.deleteAll(context: context)) != nil else { return }
        Task {
            await services.notifications.replaceAll(with: [])
            restartOnboarding()
        }
    }

    // MARK: 정보

    private var infoSection: some View {
        Section {
            LabeledContent("settings.info.version") {
                Text(verbatim: AppConfig.appVersion)
            }
            if let url = AppConfig.privacyPolicyURL {
                Link("settings.info.privacy", destination: url)
            }
            Button("settings.info.roleNotice") { sheet = .roleNotice }
            LabeledContent("settings.info.openSource") {
                Text("settings.info.none")
            }
        } header: {
            SectionHeaderText("settings.section.info")
        }
        .frostRow()
    }
}

/// 역할 고지 다시 보기
private struct RoleNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text("onboarding.role.title")
                        .font(.largeTitle.weight(.bold))
                    Text("role.notice")
                    Text("age.notice")
                    Text("data.local")
                }
                .font(Typography.body)
                .lineSpacing(Typography.bodyLineSpacing)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.midnightElevated)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("onboarding.role.accept") { dismiss() }
                }
            }
        }
        .presentationBackground(Color.midnightElevated)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(ModelContainer.preview)
    .preferredColorScheme(.dark)
}
