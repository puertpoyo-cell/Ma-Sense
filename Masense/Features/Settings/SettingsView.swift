import SwiftUI

/// S6 설정. M0에서는 섹션 자리만 잡는다. 항목은 M1-c에서.
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                Text("settings.empty")
                    .font(Typography.body)
                    .foregroundStyle(Color.inkSecondary)
            }
            Section {
                NoticeLine("data.local")
            }
        }
        .scrollContentBackground(.hidden)
        .midnightBackground()
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(ModelContainer.preview)
    .preferredColorScheme(.dark)
}
