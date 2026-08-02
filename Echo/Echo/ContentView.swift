import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var hasImported: Bool = UserDefaults.standard.bool(forKey: "echo_has_imported")
    @State private var showTour = false
    @State private var ahaContact: EchoContact?
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.035, green: 0.039, blue: 0.055, alpha: 0.95)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.035, green: 0.039, blue: 0.055, alpha: 0.95)
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
    var body: some View {
        TabView(selection: $selectedTab) {
            EchoLayerView(ahaContact: $ahaContact).tabItem { Label("Echo", systemImage: "person.3.sequence") }.tag(0)
            PeopleLibraryView().tabItem { Label("All", systemImage: "person.2.circle") }.tag(1)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
        }
        .tint(EchoTheme.accent)
        .fullScreenCover(isPresented: .constant(!hasImported)) {
            OnboardingView(hasImported: $hasImported) { contact in ahaContact = contact; showTour = true }
        }
        .overlay { if showTour { OnboardingTour(isActive: $showTour).transition(.opacity) } }
        .animation(.easeInOut(duration: 0.25), value: showTour)
    }
}
