import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showTour = false
    @State private var ahaContact: EchoContact?
    @State private var surveyResult: SurveyResult?
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var trialManager = TrialManager.shared
    init() {
        let appearance = UITabBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = UIColor(red: 0.035, green: 0.039, blue: 0.055, alpha: 0.95); UITabBar.appearance().standardAppearance = appearance; UITabBar.appearance().scrollEdgeAppearance = appearance
        let navAppearance = UINavigationBarAppearance(); navAppearance.configureWithOpaqueBackground(); navAppearance.backgroundColor = UIColor(red: 0.035, green: 0.039, blue: 0.055, alpha: 0.95); UINavigationBar.appearance().standardAppearance = navAppearance; UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
    var body: some View {
        Group { if OnboardingState.isComplete { mainApp } else { onboardingFlow } }
        .preferredColorScheme(.dark)
        .environmentObject(storeManager).environmentObject(authManager).environmentObject(trialManager)
        .modelContainer(for: [EchoContact.self, Interaction.self, Note.self, Deal.self])
    }
    private var mainApp: some View {
        TabView(selection: $selectedTab) {
            EchoLayerView(ahaContact: $ahaContact).tabItem { Label("Echo", systemImage: "person.3.sequence") }.tag(0)
            PeopleLibraryView().tabItem { Label("All", systemImage: "person.2.circle") }.tag(1)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
        }.tint(EchoTheme.accent).overlay { if showTour { OnboardingTour(isActive: $showTour).transition(.opacity) } }.animation(.easeInOut(duration: 0.25), value: showTour).onAppear { checkTrialExpiry() }
    }
    private var onboardingFlow: some View {
        Group {
            switch OnboardingState.currentStep {
            case .survey: SurveyView { result in surveyResult = result; OnboardingState.complete(.survey); NotificationCenter.default.post(name: .echoOnboardingStepChanged, object: nil) }
            case .registration: RegistrationView { profile in AuthManager.shared.saveUser(profile); OnboardingState.complete(.registration); NotificationCenter.default.post(name: .echoOnboardingStepChanged, object: nil) }
            case .valueProp: ValuePropView { OnboardingState.complete(.valueProp); NotificationCenter.default.post(name: .echoOnboardingStepChanged, object: nil) }
            case .paywall: PaywallView { OnboardingState.complete(.paywall); NotificationCenter.default.post(name: .echoOnboardingStepChanged, object: nil) }
            case .importContacts: OnboardingView(hasImported: .constant(false)) { contact in ahaContact = contact; OnboardingState.complete(.importContacts); OnboardingState.complete(.done); NotificationCenter.default.post(name: .echoOnboardingStepChanged, object: nil); DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showTour = true } }
            case .done: mainApp
            }
        }
    }
    private func checkTrialExpiry() { guard trialManager.isInTrial else { if !storeManager.isPro { }; return } }
}

extension Notification.Name { static let echoOnboardingStepChanged = Notification.Name("echoOnboardingStepChanged") }
