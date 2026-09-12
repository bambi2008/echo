import Combine
import SwiftData
import SwiftUI

enum AppStartupPolicy {
    static let seedsDemoData = false
    static let automaticallySyncsGmail = false
}

struct ContentView: View {
    @EnvironmentObject private var kipHandoffRouter: KipHandoffRouter
    @AppStorage("echo.onboarding.v2.complete") private var legacyOnboardingComplete = false
    @AppStorage("echo.relationship.onboarding.stage") private var onboardingStage = ""
    @State private var selectedTab: EchoTab = .home

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
        TabView(selection: $selectedTab) {
            BusinessHomeView()
                .tabItem { Label("Home", systemImage: "briefcase.fill") }
                .tag(EchoTab.home)

            RelationshipsView()
                .tabItem { Label("Contacts", systemImage: "person.2.fill") }
                .tag(EchoTab.contacts)

            AIInsightsView()
                .tabItem { Label("AI Brief", systemImage: "sparkles") }
                .tag(EchoTab.insights)

            NavigationStack {
                PipelineView()
            }
                .tabItem { Label(String(localized: "Pipeline"), systemImage: "rectangle.3.group.fill") }
                .tag(EchoTab.pipeline)

            SettingsView()
                .tabItem { Label(String(localized: "Settings"), systemImage: "gearshape.fill") }
                .tag(EchoTab.settings)
        }
        .tint(.indigo)
        .onOpenURL { url in
            if kipHandoffRouter.handle(url) {
                selectedTab = .contacts
            }
        }
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
        .environmentObject(KipHandoffRouter())
}

private enum EchoTab: Hashable {
    case home, contacts, insights, pipeline, settings
}

enum KipHandoffAction: String, Equatable {
    case contact, call, message, email, meet

    var title: String {
        switch self {
        case .contact: "Contact"
        case .call: "Call"
        case .message: "Message"
        case .email: "Email"
        case .meet: "Meet"
        }
    }

    var symbol: String {
        switch self {
        case .contact: "person.crop.circle.badge.checkmark"
        case .call: "phone.fill"
        case .message: "message.fill"
        case .email: "envelope.fill"
        case .meet: "person.2.fill"
        }
    }
}

struct KipHandoff: Identifiable, Equatable {
    let id = UUID()
    let itemID: String
    let person: String
    let action: KipHandoffAction
    let note: String
    let eventAt: Date?
}

@MainActor
final class KipHandoffRouter: ObservableObject {
    @Published private(set) var handoff: KipHandoff?
    @Published private(set) var assignedContactIdentifier: String?

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "com.bambi2008.echo",
              url.host?.lowercased() == "kip-handoff",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let itemID = components.value(for: "kipItemId")?.trimmed(limit: 200),
              itemID.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
              let person = components.value(for: "person")?.trimmed(limit: 120)
        else { return false }

        let action = components.value(for: "action")
            .flatMap(KipHandoffAction.init(rawValue:)) ?? .contact
        let note = components.value(for: "note")?.trimmed(limit: 600) ?? ""
        let eventAt = components.value(for: "eventAt").flatMap(ISO8601DateFormatter().date(from:))
        handoff = KipHandoff(
            itemID: itemID,
            person: person,
            action: action,
            note: note,
            eventAt: eventAt
        )
        assignedContactIdentifier = nil
        return true
    }

    func assign(_ contact: EchoContact) {
        assignedContactIdentifier = contact.systemIdentifier
    }

    func handoff(for contact: EchoContact) -> KipHandoff? {
        guard assignedContactIdentifier == contact.systemIdentifier else { return nil }
        return handoff
    }

    func completionURL() -> URL? {
        guard let itemID = handoff?.itemID else { return nil }
        var components = URLComponents()
        components.scheme = "com.bambi2008.kip"
        components.host = "echo"
        components.path = "/complete"
        components.queryItems = [URLQueryItem(name: "itemId", value: itemID)]
        return components.url
    }

    func clear() {
        handoff = nil
        assignedContactIdentifier = nil
    }
}

enum KipContactMatcher {
    static func matches(person: String, contacts: [EchoContact]) -> [EchoContact] {
        let target = normalize(person)
        guard !target.isEmpty else { return [] }
        let exact = contacts.filter { normalize($0.fullName) == target }
        if !exact.isEmpty { return exact }
        return contacts.filter {
            let name = normalize($0.fullName)
            return name.contains(target) || target.contains(name)
        }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }
}

private extension URLComponents {
    func value(for name: String) -> String? {
        queryItems?.first(where: { $0.name == name })?.value
    }
}

private extension String {
    func trimmed(limit: Int) -> String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= limit else { return nil }
        return value
    }
}
