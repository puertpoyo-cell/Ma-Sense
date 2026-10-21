import SwiftData
import SwiftUI

/// S1 오늘 (홈). 지금은 처방 없음 빈 상태만 그린다. 카드 스택은 M1-c 다음 단계에서 채운다.
struct TodayView: View {
    @Query(filter: #Predicate<Prescription> { $0.isActive })
    private var activePrescriptions: [Prescription]
    @State private var showsPrescriptionSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.cardGap) {
                if activePrescriptions.isEmpty {
                    FrostCard {
                        VStack(alignment: .leading, spacing: Spacing.s4) {
                            Text("today.empty.noPrescription")
                                .font(Typography.body)
                                .foregroundStyle(Color.ink)
                                .lineSpacing(Typography.bodyLineSpacing)
                            PrimaryButton("today.enterPrescription") {
                                showsPrescriptionSheet = true
                            }
                        }
                    }
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
        .sheet(isPresented: $showsPrescriptionSheet) {
            PrescriptionSheet()
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
