import EchoAI
import SwiftData
import SwiftUI

struct AIInsightsView: View {
    @Query private var contacts: [EchoContact]
    @State private var insights: [InsightCardData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if insights.isEmpty && !isLoading {
                        intro
                    }
                    ForEach(insights) { insight in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(insight.kind, systemImage: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.indigo)
                                Spacer()
                                Text(insight.model)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(insight.person).font(.headline)
                            Text(insight.message).font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding()
            }
            .navigationTitle("Echo AI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: generateInsights) {
                        if isLoading { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Generate insights")
                }
            }
            .alert("Echo AI", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
        }
    }

    private var intro: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 58))
                .foregroundStyle(.indigo)
            Text("A little help finding the right words")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Echo uses anonymized relationship context to suggest one warm, specific opening message.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Generate today's insights", action: generateInsights)
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }

    private func generateInsights() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let keyStore = KeychainAPIKeyStore()
                guard try keyStore.readAPIKey()?.isEmpty == false else {
                    throw AIServiceError.noAPIKey
                }
                let service = AIService(client: DeepSeekClient(apiKeyStore: keyStore))
                let features = EchoAIFeatures(service: service)
                var generated: [InsightCardData] = []

                for contact in contacts.sorted(by: {
                    EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1)
                }).prefix(3) {
                    let privacy = AIPrivacyContext(
                        people: [contact.fullName],
                        companies: [contact.companyName ?? ""]
                    )
                    let alias = privacy.alias(for: contact.fullName) ?? "Person A"
                    let safeNote = contact.notes.last.map { privacy.anonymize($0.content) }
                    let result = try await features.conversationOpener(
                        personAlias: alias,
                        recentNote: safeNote,
                        daysSinceContact: contact.daysSinceContact,
                        relationship: contact.jobTitle ?? "personal relationship"
                    )
                    generated.append(InsightCardData(
                        person: contact.fullName,
                        kind: "What to say",
                        message: privacy.restoreAliases(in: result.text),
                        model: result.model.rawValue
                    ))
                }
                insights = generated
            } catch AIServiceError.noAPIKey {
                errorMessage = "Add your DeepSeek API key in Settings first. It stays in Keychain on this device."
            } catch {
                errorMessage = "AI insights are temporarily unavailable. Your contact data remains on this device."
            }
        }
    }
}

private struct InsightCardData: Identifiable {
    let id = UUID()
    let person: String
    let kind: String
    let message: String
    let model: String
}
