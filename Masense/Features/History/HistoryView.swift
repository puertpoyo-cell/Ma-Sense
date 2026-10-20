import SwiftUI

/// S4 기록. M0에서는 빈 상태만. 세그먼트(투약/컨디션/체중)는 M1-c에서.
struct HistoryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.cardGap) {
                Text("history.empty")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("tab.history")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(ModelContainer.preview)
    .preferredColorScheme(.dark)
}
