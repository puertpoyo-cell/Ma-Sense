import SwiftData
import SwiftUI

/// S0 온보딩. 4페이지, 건너뛰기 없음. 각 페이지의 완료 조건을 채워야 다음으로 간다.
struct OnboardingView: View {
    let onFinish: () -> Void

    private enum Page: Int, CaseIterable {
        case role, age, prescription, permissions
    }

    private enum PermissionState {
        case idle, granted, denied
    }

    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var page: Page = .role
    @State private var adultChecked = false
    @State private var prescriptionForm = PrescriptionFormModel()
    @State private var notificationState: PermissionState = .idle
    @State private var healthState: PermissionState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            Text(verbatim: "\(page.rawValue + 1) / \(Page.allCases.count)")
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, Spacing.screenHorizontal)

            Group {
                switch page {
                case .role: rolePage
                case .age: agePage
                case .prescription: prescriptionPage
                case .permissions: permissionsPage
                }
            }
            .transition(.opacity.combined(with: .offset(y: 8)))
        }
        .padding(.top, Spacing.s5)
        .padding(.bottom, Spacing.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .midnightBackground()
        .animation(.easeOut(duration: 0.25), value: page)
    }

    // MARK: 0-1 역할 고지

    private var rolePage: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            Text("onboarding.role.title")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.ink)
            VStack(alignment: .leading, spacing: Spacing.s3) {
                bullet("onboarding.role.noJudgment")
                bullet("onboarding.role.noAdvice")
                bullet("data.local")
            }
            Spacer()
            PrimaryButton("onboarding.role.accept") {
                updateSettings { $0.hasAcceptedRoleNotice = true }
                page = .age
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    // MARK: 0-2 연령 확인

    private var agePage: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            FrostCard {
                Text("age.notice")
                    .font(Typography.body)
                    .lineSpacing(Typography.bodyLineSpacing)
                    .foregroundStyle(Color.ink)
            }
            Toggle("onboarding.age.check", isOn: $adultChecked)
                .toggleStyle(CheckboxToggleStyle())
            Spacer()
            PrimaryButton("onboarding.age.confirm") {
                updateSettings { $0.hasConfirmedAdult = true }
                page = .prescription
            }
            .disabled(!adultChecked)
            .opacity(adultChecked ? 1 : 0.4)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    // MARK: 0-3 처방 설정

    private var prescriptionPage: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("onboarding.prescription.title")
                .font(Typography.title)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Spacing.screenHorizontal)
            PrescriptionForm(model: prescriptionForm)
            PrimaryButton("action.save") {
                guard (try? prescriptionForm.save(in: context)) != nil else { return }
                page = .permissions
            }
            .disabled(!prescriptionForm.isValid)
            .padding(.horizontal, Spacing.screenHorizontal)
        }
    }

    // MARK: 0-4 연동·알림 (권한을 거부해도 통과)

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            Text("onboarding.permissions.title")
                .font(Typography.title)
                .foregroundStyle(Color.ink)
            Text("onboarding.permissions.body")
                .font(Typography.body)
                .lineSpacing(Typography.bodyLineSpacing)
                .foregroundStyle(Color.inkSecondary)

            permissionRow("onboarding.permissions.notifications", state: notificationState) {
                let granted = await services.notifications.requestAuthorization()
                notificationState = granted ? .granted : .denied
            }

            if services.healthKit.isAvailable {
                permissionRow("onboarding.permissions.health", state: healthState) {
                    let granted = (try? await services.healthKit.requestReadAuthorization()) ?? false
                    healthState = granted ? .granted : .denied
                    updateSettings { $0.healthKitAuthorized = granted }
                }
            }

            Spacer()
            PrimaryButton("onboarding.start") {
                Task {
                    await services.refreshNotifications(context: context)
                    onFinish()
                }
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    // MARK: 공용

    private func bullet(_ key: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
            Rectangle()
                .fill(Color.inkTertiary)
                .frame(width: 8, height: 1)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(key)
                .font(Typography.body)
                .lineSpacing(Typography.bodyLineSpacing)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private func permissionRow(
        _ titleKey: LocalizedStringKey,
        state: PermissionState,
        request: @escaping () async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            GhostButton(titleKey) {
                Task { await request() }
            }
            .disabled(state != .idle)
            switch state {
            case .idle:
                EmptyView()
            case .granted:
                Text("onboarding.permissions.granted")
                    .font(Typography.caption)
                    .foregroundStyle(Color.inkSecondary)
            case .denied:
                NoticeLine("onboarding.permissions.denied")
            }
        }
    }

    private func updateSettings(_ change: (UserSettings) -> Void) {
        guard let settings = try? UserSettings.current(in: context) else { return }
        change(settings)
        try? context.save()
    }
}

/// 체크박스 모양 토글. 색만이 아니라 아이콘 모양으로도 상태를 구분한다.
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Spacing.s3) {
                Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                    .foregroundStyle(configuration.isOn ? Color.accent : Color.inkSecondary)
                configuration.label
                    .font(Typography.body)
                    .foregroundStyle(Color.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}

#Preview {
    OnboardingView {}
        .modelContainer(ModelContainer.preview)
        .preferredColorScheme(.dark)
}
