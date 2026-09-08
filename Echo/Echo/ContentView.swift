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
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--echo-ui-reset") {
            UserDefaults.standard.removeObject(forKey: "echo.onboarding.v2.complete")
            UserDefaults.standard.removeObject(forKey: "echo.relationship.onboarding.stage")
            legacyOnboardingComplete = false
            onboardingStage = OnboardingStage.businessWelcome.rawValue
        }
        if arguments.contains("--echo-skip-onboarding") {
            UserDefaults.standard.set(OnboardingStage.completed.rawValue, forKey: "echo.relationship.onboarding.stage")
            onboardingStage = OnboardingStage.completed.rawValue
            legacyOnboardingComplete = true
        }
        #endif
    }

    private var shouldShowOnboarding: Bool {
        onboardingStage.isEmpty ? !legacyOnboardingComplete : onboardingStage != OnboardingStage.completed.rawValue
    }

    var body: some View {
        TabView {
            BusinessHomeView()
                .tabItem { Label("Home", systemImage: "briefcase.fill") }

            RelationshipsView()
                .tabItem { Label("Contacts", systemImage: "person.2.fill") }

            AIInsightsView()
                .tabItem { Label("AI Brief", systemImage: "sparkles") }

            NavigationStack {
                PipelineView()
            }
                .tabItem { Label(String(localized: "Pipeline"), systemImage: "rectangle.3.group.fill") }

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
        .modelContainer(for: [EchoContact.self, Interaction.self, EchoNote.self, Deal.self, RelationshipReflection.self, RelationshipAction.self, ReflectionJourney.self, Pipeline.self, Organization.self, AgentIntelligence.self, AgentAction.self, Evidence.self], inMemory: true)
}
