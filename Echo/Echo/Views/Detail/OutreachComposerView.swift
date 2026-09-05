import EchoAI
import SwiftUI
import SwiftData
import UIKit

enum OutreachChannel: Identifiable, Equatable {
    case message
    case email
    case social(SocialPlatform)

    var id: String {
        switch self {
        case .message: "message"
        case .email: "email"
        case .social(let platform): "social-\(platform.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .message: "Message"
        case .email: "Email"
        case .social(let platform): platform.title
        }
    }

    var symbol: String {
        switch self {
        case .message: "message.fill"
        case .email: "envelope.fill"
        case .social(let platform): platform.symbol
        }
    }
}

struct OutreachComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext

    let contact: EchoContact
    let channel: OutreachChannel

    @State private var draft = ""
    @State private var isLoading = false
    @State private var model: String?
    @State private var errorMessage: String?

    init(contact: EchoContact, channel: OutreachChannel) {
        self.contact = contact
        self.channel = channel
        _draft = State(initialValue: EchoAIFeatures.openerFallback(personAlias: contact.givenName))
    }

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
                    Text("Review and edit before opening \(channel.title). The current starter was created on this device.")
                }

                Section {
                    Text(aiContextDisclosure)
                        .foregroundStyle(.secondary)
                    Button {
                        generate()
                    } label: {
                        Label(
                            model == nil
                                ? String(localized: "Generate with optional AI")
                                : String(localized: "Generate again with AI"),
                            systemImage: "sparkles"
                        )
                    }
                    .disabled(isLoading)
                } header: {
                    Text("Optional AI suggestion")
                } footer: {
                    Text("Nothing is sent unless you tap the AI button. Names and companies are anonymized before processing.")
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
        case .social(let platform): contact.socialIdentifier(for: platform) ?? ""
        }
    }

    private var aiContextDisclosure: String {
        let hasInteraction = contact.interactions.isEmpty == false
        let hasNote = contact.notes.isEmpty == false
        switch (hasInteraction, hasNote) {
        case (true, true):
            return String(localized: "If you ask AI, Echo will use the most recent recorded interaction, one saved note, your chosen relationship direction, and time since contact.")
        case (true, false):
            return String(localized: "If you ask AI, Echo will use the most recent recorded interaction, your chosen relationship direction, and time since contact.")
        case (false, true):
            return String(localized: "If you ask AI, Echo will use one saved note, your chosen relationship direction, and time since contact.")
        case (false, false):
            return String(localized: "If you ask AI, Echo will use only your chosen relationship direction and time since contact.")
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
                let recentNote = contact.notes.sorted { $0.createdAt > $1.createdAt }.first?.content
                let recentInteraction = contact.interactions.sorted { $0.date > $1.date }.first.map {
                    let direction = $0.isIncoming.map { $0 ? "They contacted me" : "I contacted them" }
                        ?? "We interacted"
                    return "\(direction) via \($0.type.title.lowercased()): \($0.summary)"
                }
                let context = [recentInteraction, recentNote]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                    .nilIfEmpty
                    .map(privacy.anonymize)
                let response = try await features.conversationOpener(
                    personAlias: alias,
                    recentNote: context,
                    daysSinceContact: contact.daysSinceContact,
                    relationship: contact.relationshipIntent?.title
                        ?? contact.jobTitle
                        ?? contact.tags.first
                        ?? "personal relationship"
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
        let interactionType: InteractionType = channel == .email ? .emailed : .messaged
        EchoEngine.markReachedOut(to: contact, type: interactionType, note: nil, in: modelContext)
        if case .social(let platform) = channel {
            guard let destination = SocialMessagingService.destination(
                for: platform,
                identifier: self.destination,
                draft: draft
            ) else {
                errorMessage = "Echo could not open \(platform.title). Check this person's saved username or profile URL."
                return
            }
            if !destination.draftWasIncluded {
                UIPasteboard.general.string = draft
                errorMessage = "Your draft was copied. Paste it after \(platform.title) opens."
            }
            openURL(destination.url)
            return
        }

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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
