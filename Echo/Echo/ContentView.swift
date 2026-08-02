import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var hasImported = false
    @State private var showTour = false
    @State private var ahaContact: EchoContact?
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var trialManager: TrialManager

    init() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(red: 0.035, green: 0.039, blue: 0.055, alpha: 0.95)
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            EchoLayerView()
                .tabItem { Label("Echo", systemImage: "person.3.sequence") }.tag(0)
            PeopleLibraryView()
                .tabItem { Label("All", systemImage: "person.2.circle") }.tag(1)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
        }
        .tint(EchoTheme.accent)
        .fullScreenCover(isPresented: .constant(!hasImported)) {
            OnboardingView(hasImported: $hasImported) { contact in
                ahaContact = contact
                showTour = true
            }
        }
        .overlay {
            if showTour {
                OnboardingTour(isActive: $showTour).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showTour)
    }
}
