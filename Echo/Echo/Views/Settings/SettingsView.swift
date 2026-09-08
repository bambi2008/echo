import EchoAI
import SwiftData
import SwiftUI
import UIKit

private enum APIConnectionState { case notTested, connected(String), failed }

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [EchoContact]
    @AppStorage("echo.relationship.onboarding.stage") private var onboardingStage = OnboardingStage.completed.rawValue
    @AppStorage("echo.relationship.weeklyReminder") private var weeklyReminder = false
    @AppStorage("echo.relationship.reminderWeekday") private var reminderWeekday = 1
    @AppStorage("echo.relationship.reminderHour") private var reminderHour = 10
    @AppStorage(RelationshipReminderCoordinator.actionReminderKey) private var actionReminder = false
    @AppStorage(RelationshipReminderCoordinator.reviewReminderKey) private var reviewReminder = false
    @AppStorage("echo.contacts.autoSync") private var autoSyncContacts = false
    @State private var apiKey = ""
    @State private var fastModel = "deepseek-v4-flash"
    @State private var advancedModel = "deepseek-v4-pro"
    @State private var statusMessage: String?
    @State private var apiKeyPresence: APIKeyPresence?
    @State private var apiConnectionState: APIConnectionState = .notTested
    @State private var isTestingAPIConnection = false
    @State private var isImporting = false
    @State private var confirmingWorkspaceReset = false
    @State private var gmailStatus: GmailConnectionStatus?
    @State private var isWorkingWithGoogle = false
    private let diagnostics = APIKeyDiagnosticService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Follow-up reminders", isOn: $actionReminder)
                        .onChange(of: actionReminder) { _, enabled in validateReminderPermission(enabled, value: $actionReminder) }
                    Button("Replay business onboarding") {
                        UserDefaults.standard.set(false, forKey: "echo.onboarding.v2.complete")
                        onboardingStage = OnboardingStage.businessWelcome.rawValue
                    }
                    Button("Start with an empty workspace", role: .destructive) { confirmingWorkspaceReset = true }
                } header: {
                    Text("Business workspace")
                } footer: {
                    Text("Reset removes contacts, notes, interactions, opportunities, and local business records saved by Echo. It never deletes iPhone Contacts, Gmail, or other source data.")
                }

                Section {
                    Toggle("Refresh iPhone Contacts on launch", isOn: $autoSyncContacts)
                    Button { importAllContacts() } label: {
                        if isImporting { ProgressView() }
                        else { Label(String(localized: "Import full iPhone address book"), systemImage: "person.2.badge.plus") }
                    }
                    .disabled(isImporting)
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: settingsURL) {
                            Label(String(localized: "Manage Contacts access"), systemImage: "hand.raised.fill")
                        }
                    }
                } header: { Text(String(localized: "Contact management")) }
                footer: { Text("Echo can refresh the iPhone address book when the Contacts tab opens. No source contacts are deleted or uploaded by this setting.") }

                Section {
                    if let gmailStatus {
                        LabeledContent("Account", value: gmailStatus.email)
                        LabeledContent("Contact import", value: gmailStatus.canImportContacts ? "Ready" : "Reconnect required")
                        LabeledContent("Send email", value: gmailStatus.canSendEmail ? "Ready" : "Reconnect required")
                        Button("Import Google contacts") { importGoogleContacts() }.disabled(isWorkingWithGoogle)
                        Button("Sync Gmail history") { syncGmail() }.disabled(isWorkingWithGoogle)
                        if !gmailStatus.canSendEmail {
                            Button("Reconnect Google for email sending") { connectGoogle() }.disabled(isWorkingWithGoogle)
                        }
                        Button("Disconnect Google", role: .destructive) { disconnectGoogle() }.disabled(isWorkingWithGoogle)
                    } else {
                        Button { connectGoogle() } label: {
                            if isWorkingWithGoogle { ProgressView() }
                            else { Label("Connect Google", systemImage: "envelope.badge") }
                        }
                        .disabled(isWorkingWithGoogle)
                    }
                } header: {
                    Text("Google and Gmail")
                } footer: {
                    Text("Echo requests contact and Gmail metadata access. Email sending is used only after you review a draft and confirm Send.")
                }

                Section {
                    LabeledContent(String(localized: "API Key")) {
                        Label(apiKeyStatusTitle, systemImage: apiKeyStatusSymbol).foregroundStyle(apiKeyStatusColor)
                    }
                    if case .connected(let model) = apiConnectionState {
                        LabeledContent(String(localized: "Connection")) { Label("Connected · \(model)", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    } else if case .failed = apiConnectionState {
                        LabeledContent(String(localized: "Connection")) { Label(String(localized: "Test failed"), systemImage: "xmark.circle.fill").foregroundStyle(.red) }
                    }
                    SecureField(String(localized: "API key"), text: $apiKey).textContentType(.password)
                    Button(String(localized: "Save API key")) { saveAPIKey() }.disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { testAPIConnection() } label: {
                        if isTestingAPIConnection { ProgressView() }
                        else { Label(String(localized: "Test connection"), systemImage: "network.badge.shield.half.filled") }
                    }.disabled(apiKeyPresence != .configured || isTestingAPIConnection)
                    Button(String(localized: "Remove API key"), role: .destructive) { removeAPIKey() }
                } header: { Text(String(localized: "Optional AI")) }
                footer: { Text("Business contact ranking and local follow-up tools work without an API key. The key remains in Apple Keychain.") }

                Section(String(localized: "Model routing")) {
                    TextField(String(localized: "Fast model"), text: $fastModel).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField(String(localized: "Advanced model"), text: $advancedModel).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(String(localized: "Apply models")) { applyModels() }
                }

                Section(String(localized: "Privacy")) {
                    Label(String(localized: "Business data remains on this device"), systemImage: "iphone.gen3")
                    Label(String(localized: "No automatic Gmail sync at launch"), systemImage: "envelope.badge.shield.half.filled")
                    Label(String(localized: "Local insights do not call an AI service"), systemImage: "lock.shield.fill")
                }
            }
            .navigationTitle(String(localized: "Settings"))
            .task { refreshAPIKeyPresence(); gmailStatus = GmailSyncService.shared.status(); await loadModels() }
            .confirmationDialog("Start with an empty Echo workspace?", isPresented: $confirmingWorkspaceReset) {
                Button("Clear Echo workspace", role: .destructive) { clearWorkspace() }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: { Text("This clears only data saved inside Echo. Your iPhone Contacts and Gmail account are not changed.") }
            .alert(String(localized: "Echo"), isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) {
                Button(String(localized: "OK")) { statusMessage = nil }
            } message: { Text(statusMessage ?? "") }
        }
    }

    private func weekdayName(_ day: Int) -> String { Calendar.current.weekdaySymbols[max(0, min(6, day - 1))] }

    private func clearWorkspace() {
        // Delete Echo-owned records only. Source address books and Gmail are
        // intentionally outside this operation.
        (try? modelContext.fetch(FetchDescriptor<Deal>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<Interaction>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<EchoNote>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<RelationshipReflection>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<RelationshipAction>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<ReflectionJourney>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<AgentIntelligence>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<AgentAction>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<Evidence>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<Pipeline>()))?.forEach(modelContext.delete)
        (try? modelContext.fetch(FetchDescriptor<Organization>()))?.forEach(modelContext.delete)
        contacts.forEach(modelContext.delete)
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: "echo.business.workspace.reset.v1")
        onboardingStage = OnboardingStage.businessWelcome.rawValue
        UserDefaults.standard.set(false, forKey: "echo.onboarding.v2.complete")
        statusMessage = "Echo is ready for a fresh business workspace."
    }
    private func updateReminder(_ enabled: Bool) {
        Task {
            let reminders = ReminderService()
            if enabled {
                guard (try? await reminders.requestPermission()) == true else { weeklyReminder = false; return }
                try? await reminders.scheduleWeekly(weekday: reminderWeekday, hour: reminderHour, minute: 0)
            } else { reminders.cancelWeekly() }
        }
    }
    private func validateReminderPermission(_ enabled: Bool, value: Binding<Bool>) {
        guard enabled else { return }
        Task {
            guard (try? await ReminderService().requestPermission()) == true else {
                value.wrappedValue = false
                statusMessage = String(localized: "Notifications remain off. Echo still works without them.")
                return
            }
        }
    }
    private func importAllContacts() {
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                let result = try await ContactImportService().importContacts(into: modelContext)
                statusMessage = String(localized: "Imported \(result.added) and updated \(result.updated) contacts.")
            } catch { statusMessage = String(localized: "iPhone contacts could not be imported.") }
        }
    }
    private func connectGoogle() {
        isWorkingWithGoogle = true
        Task {
            defer { isWorkingWithGoogle = false }
            do {
                gmailStatus = try await GmailSyncService.shared.connect()
                statusMessage = "Google connected. Contact import, history sync, and approved Gmail sending are ready."
            } catch { statusMessage = error.localizedDescription }
        }
    }
    private func disconnectGoogle() {
        do {
            try GmailSyncService.shared.disconnect()
            gmailStatus = nil
            statusMessage = "Google disconnected from this device."
        } catch { statusMessage = error.localizedDescription }
    }
    private func importGoogleContacts() {
        isWorkingWithGoogle = true
        Task {
            defer { isWorkingWithGoogle = false }
            do {
                let result = try await GmailSyncService.shared.importGoogleContacts(in: modelContext)
                statusMessage = "Imported \(result.added), updated \(result.updated), and skipped \(result.skipped) Google contacts."
            } catch { statusMessage = error.localizedDescription }
        }
    }
    private func syncGmail() {
        isWorkingWithGoogle = true
        Task {
            defer { isWorkingWithGoogle = false }
            do {
                let result = try await GmailSyncService.shared.sync(contacts: contacts, in: modelContext)
                gmailStatus = GmailSyncService.shared.status()
                statusMessage = "Gmail sync added \(result.importedInteractions) business interactions."
            } catch { statusMessage = error.localizedDescription }
        }
    }
    private func saveAPIKey() {
        do { try KeychainAPIKeyStore().saveAPIKey(apiKey); apiKey = ""; refreshAPIKeyPresence(); apiConnectionState = .notTested; statusMessage = String(localized: "API key saved securely.") }
        catch { apiKeyPresence = .unavailable; statusMessage = String(localized: "The API key could not be saved.") }
    }
    private func removeAPIKey() {
        do { try KeychainAPIKeyStore().deleteAPIKey(); apiKey = ""; refreshAPIKeyPresence(); apiConnectionState = .notTested; statusMessage = String(localized: "API key removed.") }
        catch { statusMessage = String(localized: "The API key could not be removed.") }
    }
    private func refreshAPIKeyPresence() { apiKeyPresence = diagnostics.presence() }
    private func testAPIConnection() {
        isTestingAPIConnection = true
        Task { defer { isTestingAPIConnection = false }; do { let model = try await diagnostics.testConnection(); apiConnectionState = .connected(model.rawValue); statusMessage = String(localized: "Connection successful.") } catch { refreshAPIKeyPresence(); apiConnectionState = .failed; statusMessage = EchoAIEnvironment.message(for: error) } }
    }
    private var apiKeyStatusTitle: String { switch apiKeyPresence { case .configured: String(localized: "Configured"); case .notConfigured: String(localized: "Not configured"); case .unavailable: String(localized: "Unavailable"); case nil: String(localized: "Checking…") } }
    private var apiKeyStatusSymbol: String { switch apiKeyPresence { case .configured: "checkmark.circle.fill"; case .notConfigured: "minus.circle"; case .unavailable: "exclamationmark.triangle.fill"; case nil: "hourglass" } }
    private var apiKeyStatusColor: Color { switch apiKeyPresence { case .configured: .green; case .unavailable: .orange; default: .secondary } }
    private func applyModels() {
        Task { do { let router = AIModelRouter(); for task in [AITask.generalChat, .conversationOpener, .relationshipInsight, .dailyBriefing, .pipelineOutreach] { try await router.setModel(AIModelID(rawValue: fastModel), for: task, fallbacks: [AIModelID(rawValue: advancedModel)]) }; for task in [AITask.relationshipHealth, .businessCardOCR, .policyOCR, .salesCoach, .pipelineIntelligence] { try await router.setModel(AIModelID(rawValue: advancedModel), for: task, fallbacks: [AIModelID(rawValue: fastModel)]) }; statusMessage = String(localized: "Model routing updated.") } catch { statusMessage = String(localized: "Model IDs could not be saved.") } }
    }
    private func loadModels() async {
        let router = AIModelRouter()
        fastModel = (try? await router.policy(for: .generalChat).primary.rawValue) ?? fastModel
        advancedModel = (try? await router.policy(for: .salesCoach).primary.rawValue) ?? advancedModel
    }
}
