import SwiftData
import SwiftUI

/// 일반 정보 카드 (D9, SCREENS.md S13). 출처가 있는 일반 건강관리 정보와 진료 준비 목록.
/// 개인 맞춤 안내가 아니며 각 카드는 "의사와 상의하세요"로 끝난다 (COMPLIANCE.md 2.2, CLAUDE.md 톤 규칙)
enum InfoTopic: String, CaseIterable, Identifiable, Hashable {
    case proteinFoods, strengthExamples, clinicPrep

    var id: String { rawValue }
    // 보간을 쓰면 키가 "info.%@.title"이 되므로 이어 붙인 String으로 만든다
    var titleKey: LocalizedStringKey { LocalizedStringKey("info." + rawValue + ".title") }
    var summaryKey: LocalizedStringKey { LocalizedStringKey("info." + rawValue + ".summary") }
    var systemImage: String {
        switch self {
        case .proteinFoods: return "fork.knife"
        case .strengthExamples: return "figure.strengthtraining.functional"
        case .clinicPrep: return "list.clipboard"
        }
    }
}

/// S13 알아 두기 목록. 오늘 화면 맨 아래와 설정 > 정보에서 연다
struct InfoListView: View {
    /// 리포트 탭으로 옮기기. 오늘 화면에서 열 때만 있다
    var openReport: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                ForEach(InfoTopic.allCases) { topic in
                    NavigationLink {
                        InfoTopicView(topic: topic, openReport: openReport)
                    } label: {
                        FrostCard {
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
                                Image(systemName: topic.systemImage)
                                    .foregroundStyle(Color.accent)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: Spacing.s1) {
                                    Text(topic.titleKey)
                                        .font(Typography.sectionHeader)
                                        .foregroundStyle(Color.ink)
                                    Text(topic.summaryKey)
                                        .font(Typography.caption)
                                        .foregroundStyle(Color.inkSecondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.inkTertiary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                NoticeLine("info.general")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("info.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 카드 하나의 본문
struct InfoTopicView: View {
    let topic: InfoTopic
    var openReport: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                switch topic {
                case .proteinFoods: ProteinFoodsInfo()
                case .strengthExamples: StrengthExamplesInfo()
                case .clinicPrep: ClinicPrepInfo(openReport: openReport)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle(topic.titleKey)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: 단백질 식품 예시

/// 기록할 때 쓰는 1회 기준 대략의 g (R9 표)과 일반 권고 범위 (출처 고정)
private struct ProteinFoodsInfo: View {
    private static let foods = ProteinFood.allCases.filter { $0 != .other }

    var body: some View {
        FrostCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("info.proteinFoods.intro")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Spacing.cellPadding)
                BlueprintDivider()
                ForEach(Array(Self.foods.enumerated()), id: \.element) { index, food in
                    HStack {
                        Text(LocalizedStringKey(food.titleKey))
                            .font(Typography.body)
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Text("info.proteinFoods.grams \(food.defaultGrams)")
                            .font(Typography.label)
                            .monospacedDigit()
                            .foregroundStyle(Color.ink)
                    }
                    .padding(.horizontal, Spacing.cellPadding)
                    .padding(.vertical, Spacing.s2)
                    if index < Self.foods.count - 1 {
                        BlueprintDivider(crosshair: .none)
                    }
                }
            }
        }
        InfoNotes(lines: ["info.proteinFoods.estimate", "protein.guide"], source: "protein.source")
    }
}

// MARK: 맨몸 근력 예시

/// S8의 예시 루틴(사람 검토 대상, MILESTONES 사람 확인 7)과 WHO 일반 지침 한 줄
private struct StrengthExamplesInfo: View {
    var body: some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("exercise.routine.title")
                    .font(Typography.sectionHeader)
                    .foregroundStyle(Color.ink)
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    ForEach(StrengthSheet.routineKeys, id: \.self) { key in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                            Circle().fill(Color.accent).frame(width: 5, height: 5).accessibilityHidden(true)
                            Text(LocalizedStringKey(key))
                                .font(Typography.body)
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text("exercise.routine.repeat")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        InfoNotes(lines: ["info.strengthExamples.guideline", "exercise.general", "info.strengthExamples.consult"], source: "info.strengthExamples.source")
    }
}

// MARK: 진료 준비

/// 진료 전에 챙길 것. 앱에 있는 사실(물어볼 것 수, 남은 펜)만 옆에 적고 판단하지 않는다. 체크 표시·완료 보상 없음
private struct ClinicPrepInfo: View {
    var openReport: (() -> Void)?

    @Query(filter: #Predicate<Prescription> { $0.isActive }) private var activePrescriptions: [Prescription]
    @Query(filter: #Predicate<ClinicQuestion> { $0.askedAt == nil }) private var pendingQuestions: [ClinicQuestion]
    @State private var showsQuestions = false

    var body: some View {
        let pens = activePrescriptions.first.map { PrescriptionRules.penStatus(p: $0.snapshot, doses: $0.doseSnapshots) }
        VStack(alignment: .leading, spacing: Spacing.cardGap) {
            item("info.clinicPrep.report", detail: Text("info.clinicPrep.report.detail")) {
                if let openReport {
                    GhostButton("clinic.prepareReport", action: openReport)
                }
            }
            item("info.clinicPrep.questions", detail: pendingQuestions.isEmpty
                 ? Text("info.clinicPrep.questions.none")
                 : Text("info.clinicPrep.questions.count \(pendingQuestions.count)")) {
                AdaptiveStack(spacing: Spacing.s2) {
                    GhostButton("clinic.questions.manage") { showsQuestions = true }
                    NavigationLink("symptom.flow.open") { SymptomFlowView() }
                        .buttonStyle(.ghost)
                }
            }
            if let pens {
                item("info.clinicPrep.pens", detail: pens.isSingleUse
                     ? Text("info.clinicPrep.pens.single \(pens.remainingPens)")
                     : Text("info.clinicPrep.pens.doses \(pens.remainingDoses)")) { EmptyView() }
            }
            item("info.clinicPrep.otherMeds", detail: Text("info.clinicPrep.otherMeds.detail")) { EmptyView() }
            NoticeLine("info.clinicPrep.consult")
        }
        .sheet(isPresented: $showsQuestions) {
            ClinicQuestionsSheet()
        }
    }

    private func item<Actions: View>(_ title: LocalizedStringKey, detail: Text, @ViewBuilder actions: () -> Actions) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(title)
                        .font(Typography.sectionHeader)
                        .foregroundStyle(Color.ink)
                    detail
                        .font(Typography.body)
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actions()
            }
        }
    }
}

// MARK: 공용

/// 카드 아래 안내 문장들과 출처 한 줄
private struct InfoNotes: View {
    let lines: [LocalizedStringKey]
    let source: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                NoticeLine(line)
            }
            Text(source)
                .font(Typography.caption)
                .foregroundStyle(Color.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        InfoListView()
    }
    .modelContainer(ModelContainer.previewWithSampleData)
    .preferredColorScheme(.dark)
}
