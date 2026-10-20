import SwiftData
import SwiftUI

/// S5 리포트. M0에서는 빈 상태만. 기간 선택·미리보기·내보내기는 M1-d에서.
struct ReportView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.cardGap) {
                Text("report.empty")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                NoticeLine("report.disclaimer")
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("tab.report")
    }
}

#Preview {
    NavigationStack {
        ReportView()
    }
    .modelContainer(ModelContainer.preview)
    .preferredColorScheme(.dark)
}
