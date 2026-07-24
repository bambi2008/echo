import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [EchoContact]
    @AppStorage("echo.onboarding.complete") private var completedOnboarding = false

    var body: some View {
        TabView {
            PersonalHomeView()
                .tabItem { Label("People", systemImage: "person.2.fill") }

            AIInsightsView()
                .tabItem { Label("Echo AI", systemImage: "sparkles") }

            PipelineView()
                .tabItem { Label("Pipeline", systemImage: "rectangle.3.group.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.indigo)
        .task {
            DemoData.seedIfNeeded(in: modelContext)
            guard GmailSyncService.shared.status() != nil,
                  GmailSyncService.shared.shouldSync()
            else { return }
            _ = try? await GmailSyncService.shared.sync(contacts: contacts, in: modelContext)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !completedOnboarding },
            set: { if !$0 { completedOnboarding = true } }
        )) {
            OnboardingView { completedOnboarding = true }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [EchoContact.self, Interaction.self, EchoNote.self, Deal.self], inMemory: true)
}
