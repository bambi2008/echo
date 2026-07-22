import EchoAI
import SwiftUI

struct SettingsView: View {
    @AppStorage("echo.onboarding.complete") private var completedOnboarding = true
    @State private var apiKey = ""
    @State private var fastModel = "deepseek-v4-flash"
    @State private var advancedModel = "deepseek-v4-pro"
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API key", text: $apiKey)
                        .textContentType(.password)
                    Button("Save API key") { saveAPIKey() }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove API key", role: .destructive) { removeAPIKey() }
                } header: {
                    Text("DeepSeek")
                } footer: {
                    Text("The key is stored in Apple Keychain and is never written to app logs.")
                }

                Section {
                    TextField("Fast model", text: $fastModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Advanced model", text: $advancedModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Apply models") { applyModels() }
                } header: {
                    Text("Model routing")
                } footer: {
                    Text("You can enter any current or future compatible model ID. OCR and coaching use the advanced model; frequent tasks use the fast model.")
                }

                Section("Privacy") {
                    Label("Contacts remain on this device", systemImage: "iphone.gen3")
                    Label("Cloud prompts use local aliases", systemImage: "person.badge.shield.checkmark.fill")
                    Label("Operational logs contain no prompts", systemImage: "text.badge.xmark")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Button("Show onboarding again") { completedOnboarding = false }
                }
            }
            .navigationTitle("Settings")
            .task { await loadModels() }
            .alert("Echo", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) { Button("OK") { statusMessage = nil } } message: { Text(statusMessage ?? "") }
        }
    }

    private func saveAPIKey() {
        do {
            try KeychainAPIKeyStore().saveAPIKey(apiKey)
            apiKey = ""
            statusMessage = "API key saved securely."
        } catch {
            statusMessage = "The API key could not be saved."
        }
    }

    private func removeAPIKey() {
        do {
            try KeychainAPIKeyStore().deleteAPIKey()
            apiKey = ""
            statusMessage = "API key removed."
        } catch {
            statusMessage = "The API key could not be removed."
        }
    }

    private func applyModels() {
        Task {
            do {
                let router = AIModelRouter()
                for task in [AITask.generalChat, .conversationOpener, .relationshipInsight, .dailyBriefing] {
                    try await router.setModel(AIModelID(rawValue: fastModel), for: task, fallbacks: [AIModelID(rawValue: advancedModel)])
                }
                for task in [AITask.relationshipHealth, .businessCardOCR, .policyOCR, .salesCoach] {
                    try await router.setModel(AIModelID(rawValue: advancedModel), for: task, fallbacks: [AIModelID(rawValue: fastModel)])
                }
                statusMessage = "Model routing updated."
            } catch {
                statusMessage = "Model IDs could not be saved."
            }
        }
    }

    private func loadModels() async {
        let router = AIModelRouter()
        fastModel = (try? await router.policy(for: .generalChat).primary.rawValue) ?? fastModel
        advancedModel = (try? await router.policy(for: .salesCoach).primary.rawValue) ?? advancedModel
    }
}
