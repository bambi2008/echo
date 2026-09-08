import Contacts
import SwiftData
import SwiftUI

/// Business-first onboarding. It deliberately avoids personal relationship
/// language and lets a new user enter the workspace with zero contacts.
@MainActor
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("echo.relationship.onboarding.stage") private var stageRawValue = OnboardingStage.businessWelcome.rawValue
    @AppStorage("echo.business.ownerRole") private var ownerRole = ""
    @AppStorage("echo.business.industry") private var industry = ""
    @State private var showingContactPicker = false
    @State private var showingManualContact = false
    @State private var showingCompletion = false
    @State private var statusMessage: String?

    let finish: () -> Void

    private var stage: OnboardingStage {
        OnboardingStage(rawValue: stageRawValue) ?? .businessWelcome
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Group {
                if showingCompletion {
                    completionView
                } else {
                    switch stage {
                    case .businessWelcome: welcomeView
                    case .businessSetup: setupView
                    case .businessContacts: contactsView
                    case .businessTour: tourView
                    case .completed: completionView
                    default: welcomeView
                    }
                }
            }
            .transition(reduceMotion ? .identity : .opacity)
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showingContactPicker) {
            SystemContactPicker { selected in
                showingContactPicker = false
                importSelectedContacts(selected)
            } onCancel: { showingContactPicker = false }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingManualContact) {
            ManualRelationshipContactView { _ in }
        }
        .alert("Echo", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button(String(localized: "OK")) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
        .task { seedUITestContactsIfNeeded() }
    }

    private var welcomeView: some View {
        ReflectionPage {
            Spacer()
            Image(systemName: "briefcase.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.indigo)
            Text("Build a stronger business network")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("onboarding.businessWelcome.title")
            Text("Echo keeps partners, prospects, clients, and follow-ups in one focused workspace.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton("Set up my business workspace", identifier: "onboarding.continue") {
                move(to: .businessSetup)
            }
        }
    }

    private var setupView: some View {
        NavigationStack {
            Form {
                Section {
                    Text("A few choices help Echo rank follow-ups and tailor the workspace.")
                        .foregroundStyle(.secondary)
                }
                Section("Your role") {
                    TextField("Founder, advisor, sales lead…", text: $ownerRole)
                }
                Section("Industry") {
                    TextField("Technology, finance, services…", text: $industry)
                }
                Section("What do you want to manage first?") {
                    ForEach(BusinessContactRole.allCases) { role in
                        Button {
                            UserDefaults.standard.set(role.rawValue, forKey: "echo.business.defaultRole")
                        } label: {
                            Label(role.title, systemImage: role.symbol)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Business setup")
            .safeAreaInset(edge: .bottom) {
                PrimaryButton("Continue", identifier: "onboarding.setupContinue") {
                    move(to: .businessContacts)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var contactsView: some View {
        NavigationStack {
            List {
                Section {
                    Label("Start with a clean workspace", systemImage: "checkmark.shield.fill")
                        .font(.headline)
                    Text("Import only the business contacts you want to work with. Echo will not delete or change the source contacts.")
                        .foregroundStyle(.secondary)
                }
                Section("Add business contacts") {
                    Button { showingContactPicker = true } label: {
                        Label("Choose from iPhone Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                    Button { showingManualContact = true } label: {
                        Label("Add a partner or prospect manually", systemImage: "square.and.pencil")
                    }
                }
                if !contacts.isEmpty {
                    Section("Ready in Echo · \(contacts.filter(\.isInEchoLayer).count)") {
                        ForEach(contacts.filter(\.isInEchoLayer).prefix(8)) { contact in
                            ContactChoiceRow(contact: contact, isSelected: true)
                        }
                    }
                }
            }
            .navigationTitle("Bring in your network")
            .safeAreaInset(edge: .bottom) {
                PrimaryButton("See how Echo works", identifier: "onboarding.contactsContinue") {
                    move(to: .businessTour)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var tourView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your commercial command center")
                        .font(.largeTitle.bold())
                    Text("Everything is designed around a simple loop: capture the context, decide the next step, and follow up at the right time.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    onboardingFeature("Business contacts", "Classify people as prospects, clients, partners, suppliers, investors, or advisors.", "person.2.fill")
                    onboardingFeature("Pipeline", "Track opportunities, stages, value, next actions, and the people involved.", "rectangle.3.group.fill")
                    onboardingFeature("AI follow-up", "Rank a small group, create a daily business brief, and draft outreach only when you choose to send.", "sparkles")
                    onboardingFeature("Private by default", "Your contact records stay on this device. Imports never delete the source address book.", "lock.shield.fill")
                }
                .padding()
            }
            .navigationTitle("How Echo helps")
            .safeAreaInset(edge: .bottom) {
                PrimaryButton("Enter Echo", identifier: "onboarding.enterEcho") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        showingCompletion = true
                    }
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var completionView: some View {
        ReflectionPage {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Your business workspace is ready")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Add a contact, open Pipeline, or ask Echo AI for the next best follow-up.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton("Start working", identifier: "onboarding.finish") {
                stageRawValue = OnboardingStage.completed.rawValue
                finish()
            }
        }
    }

    private func onboardingFeature(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func move(to value: OnboardingStage) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            stageRawValue = value.rawValue
        }
    }

    private func importSelectedContacts(_ selected: [CNContact]) {
        do {
            _ = try SelectedContactImportService().importSelected(selected, into: modelContext)
        } catch {
            statusMessage = "The selected contacts could not be added."
        }
    }

    private func seedUITestContactsIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--echo-ui-testing"), contacts.isEmpty else { return }
        for name in ["Alex Chen", "Maya Lin"] {
            let parts = name.split(separator: " ").map(String.init)
            let contact = EchoContact(givenName: parts[0], familyName: parts[1], relationshipDomain: .business, businessRole: .prospect)
            modelContext.insert(contact)
        }
        try? modelContext.save()
        #endif
    }
}

struct ReflectionPage<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(spacing: 24) { content }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
    }
}

struct PrimaryButton: View {
    let title: String
    let identifier: String?
    let action: () -> Void

    init(_ title: String, identifier: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .accessibilityIdentifier(identifier ?? "")
    }
}

struct ContactChoiceRow: View {
    let contact: EchoContact
    let isSelected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.indigo.opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay(Text(contact.initials).font(.subheadline.bold()).foregroundStyle(.indigo))
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName).foregroundStyle(.primary)
                Text(contact.businessRole.title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .indigo : .secondary)
        }
        .contentShape(Rectangle())
    }
}

struct IntentChoiceRow: View {
    let intent: RelationshipIntent
    let isSelected: Bool
    var body: some View {
        HStack {
            Label(intent.title, systemImage: intent.symbol).foregroundStyle(.primary)
            Spacer()
            if isSelected { Image(systemName: "checkmark").foregroundStyle(.indigo) }
        }
        .contentShape(Rectangle())
        .accessibilityLabel(intent.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
