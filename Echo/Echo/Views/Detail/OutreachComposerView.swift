import EchoAI
import SwiftUI

enum OutreachChannel: String, Identifiable {
    case message
    case email

    var id: String { rawValue }

    var title: String {
        switch self {
        case .message: "Message"
        case .email: "Email"
        }
    }

    var symbol: String {
        switch self {
        case .message: "message.fill"
        case .email: "envelope.fill"
        }
    }
}

struct OutreachComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let contact: EchoContact
    let channel: OutreachChannel

    @State private var draft = ""
    @State private var isLoading = false
    @State private var model: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: channel.symbol)
                            .font(.title2)
                            .foregroundStyle(.indigo)
                            .frame(width: 44, height: 44)
                            .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(channel.title) \(contact.fullName)")
                                .font(.headline)
                            Text(destination)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Writing from your relationship context…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextEditor(text: $draft)
                            .frame(minHeight: 150)
                    }

                    if let model {
                        Label(model, systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Suggested outreach")
                } footer: {
                    Text("Names and companies are anonymized before AI processing. Review and edit before opening \(channel.title).")
                }

                Section {
                    Button {
                        launch()
                    } label: {
                        Label("Open \(channel.title)", systemImage: channel.symbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .navigationTitle("Reach out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        generate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Regenerate suggestion")
                }
            }
            .task {
                if draft.isEmpty {
                    generate()
                }
            }
            .alert("Echo AI", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var destination: String {
        switch channel {
        case .message: contact.phoneNumber ?? ""
        case .email: contact.emailAddress ?? ""
        }
    }

    private func generate() {
        isLoading = true
        model = nil
        Task {
            defer { isLoading = false }
            do {
                let features = try EchoAIEnvironment.features()
                let privacy = AIPrivacyContext(
                    people: [contact.fullName],
                    companies: contact.companyName.map { [$0] } ?? []
                )
                let alias = privacy.alias(for: contact.fullName) ?? "Person A"
                let context = (contact.notes.sorted { $0.createdAt > $1.createdAt }.first?.content)
                    .map(privacy.anonymize)
                let response = try await features.conversationOpener(
                    personAlias: alias,
                    recentNote: context,
                    daysSinceContact: contact.daysSinceContact,
                    relationship: contact.jobTitle ?? contact.tags.first ?? "personal relationship"
                )
                draft = privacy.restoreAliases(in: response.text)
                model = response.model.rawValue
            } catch {
                draft = EchoAIFeatures.openerFallback(personAlias: contact.givenName)
                errorMessage = "\(EchoAIEnvironment.message(for: error)) A local starter was added instead."
            }
        }
    }

    private func launch() {
        var components = URLComponents()
        components.scheme = channel == .message ? "sms" : "mailto"
        components.path = destination
        var queryItems = [URLQueryItem(name: "body", value: draft)]
        if channel == .email {
            queryItems.insert(URLQueryItem(name: "subject", value: "Checking in"), at: 0)
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            errorMessage = "Echo could not open \(channel.title). Check this person's contact details."
            return
        }
        openURL(url)
    }
}
