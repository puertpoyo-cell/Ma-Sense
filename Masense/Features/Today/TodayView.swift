import SwiftUI

/// S1 오늘 (홈). M0에서는 빈 상태만 그린다. 카드 스택은 M1-c에서 채운다.
struct TodayView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.cardGap) {
                FrostCard {
                    Text("today.empty.noPrescription")
                        .font(Typography.body)
                        .foregroundStyle(Color.ink)
                        .lineSpacing(Typography.bodyLineSpacing)
                }
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.vertical, Spacing.s4)
        }
        .midnightBackground()
        .navigationTitle("tab.today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("settings.title")
            }
        }
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .modelContainer(ModelContainer.preview)
    .preferredColorScheme(.dark)
}
