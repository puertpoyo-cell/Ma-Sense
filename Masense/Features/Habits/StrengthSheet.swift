import SwiftData
import SwiftUI

/// S8 운동 기록. 근력 선택 시 접힌 "맨몸 15~20분 예시" (일반 건강관리 정보, COMPLIANCE.md 2.2).
struct StrengthSheet: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model: StrengthLogModel
    @State private var showsRoutine = false

    init(isLowCondition: Bool, onSaved: @escaping () -> Void = {}) {
        _model = State(initialValue: StrengthLogModel(isLowCondition: isLowCondition))
        self.onSaved = onSaved
    }

    /// 예시 루틴 문구 키. 내용은 사람 검토 대상 (MILESTONES M2-b)
    static let routineKeys = (1...5).map { "exercise.routine.\($0)" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("strength.kind", selection: $model.kind) {
                        ForEach(model.kindOrder) { kind in
                            Text(LocalizedStringKey(kind.titleKey)).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if model.takesDetails {
                    Section {
                        DatePicker("strength.time", selection: $model.startedAt, in: ...model.openedAt, displayedComponents: [.date, .hourAndMinute])
                        Stepper(value: $model.durationMinutes, in: StrengthLogModel.durationRange, step: StrengthLogModel.durationStep) {
                            LabeledContent("strength.duration") {
                                Text("strength.minutes \(model.durationMinutes)").monospacedDigit()
                            }
                        }
                        Picker("strength.intensity", selection: $model.intensity) {
                            ForEach(Intensity.allCases) { level in
                                Text(LocalizedStringKey(level.titleKey)).tag(level)
                            }
                        }
                    }
                    .frostRow()
                } else {
                    Section {
                        Text("strength.restNote")
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .frostRow()
                }

                if model.kind == .strength {
                    Section {
                        DisclosureGroup("exercise.routine.title", isExpanded: $showsRoutine) {
                            VStack(alignment: .leading, spacing: Spacing.s2) {
                                Text("exercise.general")
                                    .font(Typography.caption)
                                    .foregroundStyle(Color.notice)
                                ForEach(Self.routineKeys, id: \.self) { key in
                                    Text(LocalizedStringKey(key))
                                }
                                Text("exercise.routine.repeat")
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            .font(Typography.body)
                            .padding(.vertical, Spacing.s2)
                        }
                    }
                    .frostRow()
                }

                Section {
                    TextField("field.memo", text: $model.note, axis: .vertical)
                }
                .frostRow()
            }
            .scrollContentBackground(.hidden)
            .background(Color.midnightElevated)
            .foregroundStyle(Color.ink)
            .navigationTitle("strength.title")
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
        guard (try? model.save(in: context)) != nil else { return }
        dismiss()
        onSaved()
    }
}
