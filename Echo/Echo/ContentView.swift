import SwiftData
import SwiftUI

enum AppStartupPolicy {
    static let seedsDemoData = false
    static let automaticallySyncsGmail = false
}

struct ContentView: View {
    @AppStorage("echo.onboarding.v2.complete") private var legacyOnboardingComplete = false
    @AppStorage("echo.relationship.onboarding.stage") private var onboardingStage = ""

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--echo-ui-reset") {
            UserDefaults.standard.removeObject(forKey: "echo.onboarding.v2.complete")
            UserDefaults.standard.removeObject(forKey: "echo.relationship.onboarding.stage")
            legacyOnboardingComplete = false
            onboardingStage = ""
        }
        #endif
    }

    private var shouldShowOnboarding: Bool {
        onboardingStage.isEmpty ? !legacyOnboardingComplete : onboardingStage != OnboardingStage.completed.rawValue
    }

    var body: some View {
        TabView {
            PersonalHomeView()
                .tabItem { Label(String(localized: "Echo"), systemImage: "circle.hexagongrid.fill") }

            RelationshipsView()
                .tabItem { Label(String(localized: "Relationships"), systemImage: "person.2.fill") }

            AIInsightsView()
                .tabItem { Label(String(localized: "Insights"), systemImage: "sparkles") }

            SettingsView()
                .tabItem { Label(String(localized: "Settings"), systemImage: "gearshape.fill") }
        }
        .tint(.indigo)
        .fullScreenCover(isPresented: Binding(
            get: { shouldShowOnboarding },
            set: { _ in }
        )) {
            OnboardingView {
                onboardingStage = OnboardingStage.completed.rawValue
                legacyOnboardingComplete = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [EchoContact.self, Interaction.self, EchoNote.self, Deal.self, RelationshipReflection.self, RelationshipAction.self, ReflectionJourney.self], inMemory: true)
}
