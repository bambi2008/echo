import EchoAI
import SwiftData
import SwiftUI
import UIKit

private enum APIConnectionState { case notTested, connected(String), failed }

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("echo.relationship.onboarding.stage") private var onboardingStage = OnboardingStage.completed.rawValue
    @AppStorage("echo.relationship.weeklyReminder") private var weeklyReminder = false
    @AppStorage("echo.relationship.reminderWeekday") private var reminderWeekday = 1
    @AppStorage("echo.relationship.reminderHour") private var reminderHour = 10
    @AppStorage(RelationshipReminderCoordinator.actionReminderKey) private var actionReminder = false
    @AppStorage(RelationshipReminderCoordinator.reviewReminderKey) private var reviewReminder = false
    @AppStorage("echo.relationship.businessTools") private var businessTools = false
    @State private var apiKey = ""
    @State private var fastModel = "deepseek-v4-flash"
    @State private var advancedModel = "deepseek-v4-pro"
    @State private var statusMessage: String?
    @State private var apiKeyPresence: APIKeyPresence?
    @State private var apiConnectionState: APIConnectionState = .notTested
    @State private var isTestingAPIConnection = false
    @State private var isImporting = false
    @State private var confirmingRestart = false
    private let diagnostics = APIKeyDiagnosticService()

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Reflection journey")) {
                    Toggle(String(localized: "Weekly reflection reminder"), isOn: $weeklyReminder)
                        .onChange(of: weeklyReminder) { _, enabled in updateReminder(enabled) }
                    Picker(String(localized: "Day"), selection: $reminderWeekday) {
                        ForEach(1...7, id: \.self) { day in Text(weekdayName(day)).tag(day) }
                    }
                    .onChange(of: reminderWeekday) { _, _ in if weeklyReminder { updateReminder(true) } }
                    Picker(String(localized: "Time"), selection: $reminderHour) {
                        ForEach(7...22, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                    }
                    .onChange(of: reminderHour) { _, _ in if weeklyReminder { updateReminder(true) } }
                    Toggle(String(localized: "Action reminders"), isOn: $actionReminder)
                        .onChange(of: actionReminder) { _, enabled in validateReminderPermission(enabled, value: $actionReminder) }
                    Toggle(String(localized: "Weekend review reminders"), isOn: $reviewReminder)
                        .onChange(of: reviewReminder) { _, enabled in validateReminderPermission(enabled, value: $reviewReminder) }
                    Button(String(localized: "Restart the four-week reflection")) { confirmingRestart = true }
                    Button(String(localized: "Replay the opening reflection")) { onboardingStage = OnboardingStage.philosophy.rawValue }
                }

                Section {
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
                footer: { Text(String(localized: "The reflective flow imports only people you select. Full address-book import is optional here.")) }

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
                footer: { Text(String(localized: "Core reflection, relationship mapping, and local insights work without an API key. The key remains in Apple Keychain.")) }

                Section(String(localized: "Model routing")) {
                    TextField(String(localized: "Fast model"), text: $fastModel).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField(String(localized: "Advanced model"), text: $advancedModel).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(String(localized: "Apply models")) { applyModels() }
                }

                Section {
                    Toggle(String(localized: "Show business tools"), isOn: $businessTools)
                    if businessTools {
                        NavigationLink { PipelineView() } label: { Label(String(localized: "Pipeline"), systemImage: "rectangle.3.group.fill") }
                    }
                } header: { Text(String(localized: "Business tools")) }
                footer: { Text(String(localized: "Pipeline stays available for existing business data, but it is not part of the default relationship experience.")) }

                Section(String(localized: "Privacy")) {
                    Label(String(localized: "Relationship data remains on this device"), systemImage: "iphone.gen3")
                    Label(String(localized: "No automatic Gmail sync at launch"), systemImage: "envelope.badge.shield.half.filled")
                    Label(String(localized: "Local insights do not call an AI service"), systemImage: "lock.shield.fill")
                }
            }
            .navigationTitle(String(localized: "Settings"))
            .task { refreshAPIKeyPresence(); await loadModels() }
            .confirmationDialog(String(localized: "Start a new four-week reflection?"), isPresented: $confirmingRestart) {
                Button(String(localized: "Restart")) { _ = try? RelationshipJourneyService().restartJourney(in: modelContext) }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: { Text(String(localized: "Your contacts, notes, history, actions, and business data will stay intact.")) }
            .alert(String(localized: "Echo"), isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) {
                Button(String(localized: "OK")) { statusMessage = nil }
            } message: { Text(statusMessage ?? "") }
        }
    }

    private func weekdayName(_ day: Int) -> String { Calendar.current.weekdaySymbols[max(0, min(6, day - 1))] }
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
        Task { do { let router = AIModelRouter(); for task in [AITask.generalChat, .conversationOpener, .relationshipInsight, .dailyBriefing] { try await router.setModel(AIModelID(rawValue: fastModel), for: task, fallbacks: [AIModelID(rawValue: advancedModel)]) }; for task in [AITask.relationshipHealth, .businessCardOCR, .policyOCR, .salesCoach] { try await router.setModel(AIModelID(rawValue: advancedModel), for: task, fallbacks: [AIModelID(rawValue: fastModel)]) }; statusMessage = String(localized: "Model routing updated.") } catch { statusMessage = String(localized: "Model IDs could not be saved.") } }
    }
    private func loadModels() async {
        let router = AIModelRouter()
        fastModel = (try? await router.policy(for: .generalChat).primary.rawValue) ?? fastModel
        advancedModel = (try? await router.policy(for: .salesCoach).primary.rawValue) ?? advancedModel
    }
}
