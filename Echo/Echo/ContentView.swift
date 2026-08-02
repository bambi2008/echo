import SwiftUI
import SwiftData
struct ContentView: View {
    @State private var selectedTab = 0; @State private var showTour = false; @State private var surveyResult: SurveyResult?
    @AppStorage("hasLaunched") private var hasLaunchedStored = false; @AppStorage("hasSeenConstellation") private var hasSeenConstellation = false
    @StateObject private var storeManager = StoreManager.shared; @StateObject private var authManager = AuthManager.shared; @StateObject private var trialManager = TrialManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }) private var echoContacts: [EchoContact]
    init() { let a = UITabBarAppearance(); a.configureWithOpaqueBackground(); a.backgroundColor = UIColor(red: 0.035, green: 0.039, blue: 0.055, alpha: 0.95); UITabBar.appearance().standardAppearance = a; UITabBar.appearance().scrollEdgeAppearance = a; let n = UINavigationBarAppearance(); n.configureWithOpaqueBackground(); n.backgroundColor = UIColor(red: 0.035, green: 0.039, blue: 0.055, alpha: 0.95); UINavigationBar.appearance().standardAppearance = n; UINavigationBar.appearance().scrollEdgeAppearance = n }
    var body: some View {
        Group {
            if !hasSeenConstellation { MagicMomentView(hasLaunched: Binding(get: { hasSeenConstellation }, set: { hasSeenConstellation = $0; hasLaunchedStored = $0 })) }
            else if !hasLaunchedStored { LaunchView(hasLaunched: Binding(get: { hasLaunchedStored }, set: { hasLaunchedStored = $0 })) }
            else if OnboardingState.isComplete { mainApp }
            else { onboardingFlow }
        }.preferredColorScheme(.dark).environmentObject(storeManager).environmentObject(authManager).environmentObject(trialManager).modelContainer(for: [EchoContact.self, Interaction.self, Note.self, Deal.self])
    }
    private var mainApp: some View {
        ZStack {
            EchoBackground()
            switch selectedTab {
            case 0: EchoLayerView()
            case 1: PeopleLibraryView()
            case 2: AchievementsView(contacts: echoContacts)
            case 3: SettingsView()
            default: EchoLayerView()
            }
            FloatingTabBar(selectedTab: $selectedTab) { EchoHaptics.selection() }
        }.overlay { if showTour { OnboardingTour(isActive: $showTour).transition(.opacity) } }.animation(.easeInOut(duration: 0.25), value: showTour).onAppear { loadDemoIfNeeded() }
    }
    private func loadDemoIfNeeded() { let desc = FetchDescriptor<EchoContact>(); let existing = (try? modelContext.fetch(desc)) ?? []; if existing.isEmpty { DemoDataManager.loadDemoData(context: modelContext) } }
    private var onboardingFlow: some View {
        Group {
            switch OnboardingState.currentStep {
            case .survey: SurveyView { r in surveyResult = r; OnboardingState.complete(.survey) }
            case .registration: RegistrationView { p in AuthManager.shared.saveUser(p); OnboardingState.complete(.registration) }
            case .valueProp: ValuePropView { OnboardingState.complete(.valueProp) }
            case .paywall: PaywallView { OnboardingState.complete(.paywall) }
            case .importContacts: OnboardingView(hasImported: .constant(false)) { _ in OnboardingState.complete(.importContacts); OnboardingState.complete(.done); DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showTour = true } }
            case .done: mainApp
            }
        }
    }
}