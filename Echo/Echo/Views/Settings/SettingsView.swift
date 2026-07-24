import EchoAI
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [EchoContact]
    @AppStorage("echo.onboarding.complete") private var completedOnboarding = true
    @State private var apiKey = ""
    @State private var fastModel = "deepseek-v4-flash"
    @State private var advancedModel = "deepseek-v4-pro"
    @State private var statusMessage: String?
    @State private var gmailAccount: String?
    @State private var isWorkingWithGmail = false

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

                Section {
                    if let gmailAccount {
                        LabeledContent {
                            Text(gmailAccount)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Button {
                            syncGmail()
                        } label: {
                            if isWorkingWithGmail {
                                ProgressView()
                            } else {
                                Label("Sync Gmail now", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(isWorkingWithGmail)
                        Button("Disconnect Gmail", role: .destructive) {
                            disconnectGmail()
                        }
                        .disabled(isWorkingWithGmail)
                    } else {
                        Button {
                            connectGmail()
                        } label: {
                            if isWorkingWithGmail {
                                ProgressView()
                            } else {
                                Label("Connect Gmail", systemImage: "envelope.badge")
                            }
                        }
                        .disabled(isWorkingWithGmail)
                    }
                } header: {
                    Text("Email sync")
                } footer: {
                    Text("Echo reads message headers only—sender, recipients, subject, and time. Email bodies and attachments are not downloaded.")
                }

                Section("Privacy") {
                    Label("Contacts remain on this device", systemImage: "iphone.gen3")
                    Label("Gmail bodies are never downloaded", systemImage: "envelope.badge.shield.half.filled")
                    Label("Cloud prompts use local aliases", systemImage: "person.badge.shield.checkmark.fill")
                    Label("Operational logs contain no prompts", systemImage: "text.badge.xmark")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Button("Show onboarding again") { completedOnboarding = false }
                }
            }
            .navigationTitle("Settings")
            .task {
                await loadModels()
                gmailAccount = GmailSyncService.shared.status()?.email
            }
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

    private func connectGmail() {
        isWorkingWithGmail = true
        Task {
            defer { isWorkingWithGmail = false }
            do {
                let status = try await GmailSyncService.shared.connect()
                gmailAccount = status.email
                let count = try await GmailSyncService.shared.sync(contacts: contacts, in: modelContext)
                statusMessage = "Gmail connected. Imported \(count) matched email interactions."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func syncGmail() {
        isWorkingWithGmail = true
        Task {
            defer { isWorkingWithGmail = false }
            do {
                let count = try await GmailSyncService.shared.sync(contacts: contacts, in: modelContext)
                statusMessage = count == 0
                    ? "Gmail is up to date. No new matched interactions were found."
                    : "Imported \(count) new matched email interactions."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func disconnectGmail() {
        do {
            try GmailSyncService.shared.disconnect()
            gmailAccount = nil
            statusMessage = "Gmail disconnected. Existing interaction history remains on this device."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
