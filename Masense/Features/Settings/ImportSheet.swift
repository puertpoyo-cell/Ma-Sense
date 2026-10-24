import SwiftData
import SwiftUI

/// 설정 > 데이터 > 기록 가져오기 (SCREENS.md S6, EXPORT_FORMAT.md 가져오기 규칙 4·8·9).
/// 파일에 담긴 기록과 방식(기본 교체)을 보여 주고, 한 번 더 확인한 뒤 저장한다. 결과는 같은 시트에 담담하게 보여 준다.
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @Environment(\.calendar) private var calendar
    @State private var model: DataImportModel

    init(document: ExportDocument, result: ExportCodec.ImportResult? = nil) {
        _model = State(initialValue: DataImportModel(document: document, result: result))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result = model.result {
                    resultForm(result)
                } else {
                    choiceForm
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(Color.ink)
            .background(Color.midnightElevated)
            .navigationTitle("import.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.result == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("import.action") { model.confirms = true }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("action.done") { dismiss() }
                    }
                }
            }
            .alert(confirmTitle, isPresented: $model.confirms) {
                Button(confirmFinal, action: importRecords)
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text(confirmMessage)
            }
            .alert("import.error.title", isPresented: $model.savingFailed) {
                Button("action.ok") {}
            } message: {
                Text("import.error.saveFailed")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    // MARK: 고르기

    private var choiceForm: some View {
        Form {
            Section {
                LabeledContent("import.file.exportedAt") {
                    Text(model.document.exportedAt.formatted(.dateTime.year().month(.defaultDigits).day()))
                        .monospacedDigit()
                }
                ForEach(model.fileRows, id: \.titleKey) { row in
                    LabeledContent(LocalizedStringKey(row.titleKey)) {
                        Text("import.result.count \(row.count.imported)")
                            .monospacedDigit()
                    }
                }
            } header: {
                SectionHeaderText("import.file.section")
            }
            .frostRow()

            Section {
                Picker("import.mode.section", selection: $model.mode) {
                    Text("import.mode.replace").tag(ExportCodec.ImportMode.replace)
                    Text("import.mode.add").tag(ExportCodec.ImportMode.add)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                SectionHeaderText("import.mode.section")
            } footer: {
                Text(modeFooter)
            }
            .frostRow()
        }
    }

    private var modeFooter: LocalizedStringKey {
        model.mode == .replace ? "import.mode.replace.footer" : "import.mode.add.footer"
    }

    private var confirmTitle: LocalizedStringKey {
        model.mode == .replace ? "import.confirm.replace.title" : "import.confirm.add.title"
    }

    private var confirmMessage: LocalizedStringKey {
        model.mode == .replace ? "import.confirm.replace.message" : "import.confirm.add.message"
    }

    private var confirmFinal: LocalizedStringKey {
        model.mode == .replace ? "import.confirm.replace.final" : "import.confirm.add.final"
    }

    /// 저장 뒤 알림 전부 재등록(R4), 건강 앱 연동 중이면 다시 읽는다 (규칙 8)
    private func importRecords() {
        model.importRecords(context: context, calendar: calendar)
        guard model.result != nil else { return }
        Task {
            await services.refreshReminders(context: context)
            if (try? UserSettings.current(in: context))?.healthKitAuthorized == true {
                try? await HealthSyncService.syncAll(reader: services.healthKit, context: context)
            }
        }
    }

    // MARK: 결과 (성공 애니메이션 없음)

    private func resultForm(_ result: ExportCodec.ImportResult) -> some View {
        Form {
            Section {
                if model.resultRows.isEmpty {
                    Text("import.result.empty")
                        .foregroundStyle(Color.inkSecondary)
                }
                ForEach(model.resultRows, id: \.titleKey) { row in
                    LabeledContent(LocalizedStringKey(row.titleKey)) {
                        Group {
                            if row.count.skipped > 0 {
                                Text("import.result.countSkipped \(row.count.imported) \(row.count.skipped)")
                            } else {
                                Text("import.result.count \(row.count.imported)")
                            }
                        }
                        .monospacedDigit()
                    }
                }
            } header: {
                SectionHeaderText("import.result.section")
            } footer: {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    if result.totalSkipped > 0 {
                        Text("import.result.skippedNote")
                    }
                    if result.leftToHealthApp > 0 {
                        Text("import.result.healthApp \(result.leftToHealthApp)")
                    }
                }
            }
            .frostRow()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("toast.recorded")
                .font(Typography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.s4)
        }
    }
}

#Preview {
    Color.midnight
        .sheet(isPresented: .constant(true)) {
            ImportSheet(document: ExportDocument(
                appVersion: "1.0.0 (1)",
                schemaVersion: "1.0.0",
                exportedAt: .now,
                device: ExportDocument.Device(model: "iPhone16,2", systemVersion: "18.1")
            ))
        }
        .modelContainer(ModelContainer.preview)
        .preferredColorScheme(.dark)
}
