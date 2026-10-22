import SwiftData
import SwiftUI

/// 리포트 PDF 내보내기 구매 게이트. 기록·알림·컨디션 체크는 전부 무료 (COMPLIANCE.md 4.4).
struct ReportPurchaseSheet: View {
    @Bindable var settings: UserSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.services) private var services
    @State private var product: StoreProductInfo?
    @State private var notice: LocalizedStringKey?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("report.purchase.title")
                    .font(Typography.title)
                    .foregroundStyle(Color.ink)
                Text("settings.purchase.footer")
                    .font(Typography.body)
                    .lineSpacing(Typography.bodyLineSpacing)
                    .foregroundStyle(Color.inkSecondary)
                if let notice {
                    NoticeLine(notice)
                }
                Spacer()
                if let product {
                    Button {
                        Task { await purchase() }
                    } label: {
                        Text(verbatim: "\(product.displayName) · \(product.displayPrice)")
                    }
                    .buttonStyle(.primary)
                    .disabled(isWorking)
                }
                GhostButton("settings.purchase.restore") {
                    Task { await restore() }
                }
                .disabled(isWorking)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.midnightElevated)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
            }
            .task { product = await services.store.loadProduct() }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.midnightElevated)
    }

    private func purchase() async {
        isWorking = true
        defer { isWorking = false }
        do {
            if try await services.store.purchase() {
                settings.hasPurchasedPro = true
                try? context.save()
                dismiss()
            }
        } catch {
            notice = "settings.purchase.failed"
        }
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            settings.hasPurchasedPro = try await services.store.restore()
            try? context.save()
            if settings.hasPurchasedPro {
                dismiss()
            } else {
                notice = "settings.purchase.nothingToRestore"
            }
        } catch {
            notice = "settings.purchase.failed"
        }
    }
}
