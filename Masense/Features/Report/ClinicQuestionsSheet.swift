import SwiftData
import SwiftUI

/// 진료 때 물어볼 것 (D6, SCREENS.md S5-1, R15). 적어 두고, 진료에서 물어봤으면 눌러 표시한다.
/// 아직 묻지 않은 것은 진료 전 리포트에 실린다. 앱은 질문을 분류하거나 답하지 않는다.
struct ClinicQuestionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ClinicQuestion.createdAt) private var questions: [ClinicQuestion]
    @State private var draft = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        let snapshots = questions.map(\.snapshot)
        let pending = ClinicQuestionRules.pending(snapshots)
        let asked = ClinicQuestionRules.asked(snapshots)
        NavigationStack {
            Form {
                Section {
                    TextField("clinic.questions.placeholder", text: $draft)
                        .focused($isEditing)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("clinic.questions.add", action: add)
                        .disabled(ClinicQuestionRules.normalized(draft) == nil)
                } footer: {
                    Text("clinic.questions.footer")
                }
                .frostRow()

                if !pending.isEmpty {
                    Section {
                        ForEach(pending) { row($0) }
                    } header: {
                        SectionHeaderText(Text("clinic.questions.pending \(pending.count)"))
                    }
                    .frostRow()
                }

                if !asked.isEmpty {
                    Section {
                        ForEach(asked) { row($0) }
                    } header: {
                        SectionHeaderText("clinic.questions.asked")
                    }
                    .frostRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .navigationTitle("clinic.questions.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func row(_ question: ClinicQuestionSnapshot) -> some View {
        let isAsked = question.askedAt != nil
        return Button {
            toggleAsked(question.id)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
                Image(systemName: isAsked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isAsked ? Color.accent : Color.inkSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(verbatim: question.text)
                        .font(Typography.body)
                        .foregroundStyle(isAsked ? Color.inkSecondary : Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let askedAt = question.askedAt {
                        Text("clinic.questions.askedOn \(askedAt.formatted(.dateTime.month(.defaultDigits).day()))")
                            .font(Typography.caption)
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(LocalizedStringKey(isAsked ? "clinic.questions.a11y.asked" : "clinic.questions.a11y.pending")))
        .swipeActions(edge: .trailing) {
            // 빨강 금지: destructive 역할 대신 중립색
            Button("clinic.questions.delete") { delete(question.id) }
                .tint(Color.inkTertiary)
        }
    }

    private func add() {
        guard let text = ClinicQuestionRules.normalized(draft) else { return }
        context.insert(ClinicQuestion(text: text))
        try? context.save()
        draft = ""
        isEditing = true
    }

    /// 누른 시각이 물어본 시각 (`now` 주입 지점). 다시 누르면 되돌린다
    private func toggleAsked(_ id: UUID) {
        guard let question = questions.first(where: { $0.id == id }) else { return }
        question.askedAt = question.askedAt == nil ? Date() : nil
        try? context.save()
    }

    private func delete(_ id: UUID) {
        guard let question = questions.first(where: { $0.id == id }) else { return }
        context.delete(question)
        try? context.save()
    }
}

#Preview {
    Color.midnight
        .sheet(isPresented: .constant(true)) {
            ClinicQuestionsSheet()
        }
        .modelContainer(ModelContainer.preview)
}
