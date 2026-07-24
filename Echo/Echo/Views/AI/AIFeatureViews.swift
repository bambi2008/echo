import EchoAI
import PhotosUI
import SwiftData
import SwiftUI

enum EchoAIEnvironment {
    static func features() throws -> EchoAIFeatures {
        let keyStore = KeychainAPIKeyStore()
        guard try keyStore.readAPIKey()?.isEmpty == false else {
            throw AIServiceError.noAPIKey
        }
        return EchoAIFeatures(
            service: AIService(client: DeepSeekClient(apiKeyStore: keyStore))
        )
    }

    static func message(for error: Error) -> String {
        guard let error = error as? AIServiceError else {
            return "Unexpected error: \(error.localizedDescription)"
        }
        switch error {
        case .noAPIKey:
            return "Add your DeepSeek API key in Settings first."
        case .http(statusCode: 401, _), .http(statusCode: 403, _):
            return "DeepSeek rejected the API key. Check the key in Settings and save it again."
        case .http(statusCode: 402, _):
            return "Your DeepSeek account has insufficient balance. Add credit, then try again."
        case .http(statusCode: 404, _):
            return "The selected model is unavailable. Use deepseek-v4-flash and deepseek-v4-pro in Settings."
        case .http(statusCode: 429, _):
            return "DeepSeek is rate-limiting requests. Wait briefly and try again."
        case .transport(let message):
            return "Could not reach DeepSeek: \(message)"
        default:
            return error.localizedDescription
        }
    }
}

enum RelationshipAnalysisMode {
    case insight
    case health

    var title: String {
        switch self {
        case .insight: "Relationship insight"
        case .health: "Relationship health"
        }
    }

    var symbol: String {
        switch self {
        case .insight: "person.text.rectangle"
        case .health: "heart.text.clipboard"
        }
    }
}

struct RelationshipAnalysisView: View {
    let mode: RelationshipAnalysisMode
    let contacts: [EchoContact]

    @State private var selectedContactID = ""
    @State private var result: String?
    @State private var model: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var selectedContact: EchoContact? {
        contacts.first { $0.systemIdentifier == selectedContactID } ?? contacts.first
    }

    var body: some View {
        Form {
            Section("Person") {
                Picker("Contact", selection: $selectedContactID) {
                    ForEach(contacts.sorted { $0.fullName < $1.fullName }) { contact in
                        Text(contact.fullName).tag(contact.systemIdentifier)
                    }
                }
            }

            if let contact = selectedContact {
                Section("Context") {
                    LabeledContent("Role", value: contact.jobTitle ?? "Not set")
                    LabeledContent("Company", value: contact.companyName ?? "Not set")
                    LabeledContent(
                        "Last contact",
                        value: contact.daysSinceContact.map { "\($0) days ago" } ?? "Unknown"
                    )
                    LabeledContent("Interactions", value: "\(contact.interactions.count)")
                }
            }

            Section {
                Button {
                    generate()
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Label("Generate \(mode.title.lowercased())", systemImage: "sparkles")
                    }
                }
                .disabled(isLoading || selectedContact == nil)
            }

            if let result {
                Section {
                    AITextResultView(text: result, model: model, symbol: mode.symbol)
                }
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if selectedContactID.isEmpty {
                selectedContactID = contacts.first?.systemIdentifier ?? ""
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

    private func generate() {
        guard let contact = selectedContact else { return }
        isLoading = true
        result = nil
        Task {
            defer { isLoading = false }
            do {
                let features = try EchoAIEnvironment.features()
                let privacy = AIPrivacyContext(
                    people: [contact.fullName],
                    companies: [contact.companyName ?? ""]
                )
                let alias = privacy.alias(for: contact.fullName) ?? "Person A"
                let interactions = contact.interactions
                    .sorted { $0.date > $1.date }
                    .prefix(8)
                    .map { "\($0.typeRawValue): \($0.summary)" }
                    .joined(separator: "\n")
                let notes = contact.notes
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(4)
                    .map(\.content)
                    .joined(separator: "\n")

                let response: AIResult
                switch mode {
                case .insight:
                    response = try await features.relationshipInsight(
                        personAlias: alias,
                        interactionSummary: privacy.anonymize(
                            [interactions, notes].filter { !$0.isEmpty }.joined(separator: "\n")
                        )
                    )
                case .health:
                    let frequency = "\(contact.interactions.count) recorded interactions; last contact \(contact.daysSinceContact.map { "\($0) days ago" } ?? "unknown")."
                    response = try await features.relationshipHealth(
                        personAlias: alias,
                        frequencyTrend: frequency,
                        recentInteractions: privacy.anonymize(interactions.isEmpty ? "No recent interactions recorded." : interactions),
                        notableChanges: privacy.anonymize(notes.isEmpty ? "No notable changes recorded." : notes)
                    )
                }
                result = privacy.restoreAliases(in: response.text)
                model = response.model.rawValue
            } catch {
                errorMessage = EchoAIEnvironment.message(for: error)
            }
        }
    }
}

struct DailyBriefingView: View {
    let contacts: [EchoContact]

    @State private var result: String?
    @State private var model: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var priorityContacts: [EchoContact] {
        Array(contacts.sorted {
            EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1)
        }.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AIHero(
                    title: "Start with the people who matter",
                    subtitle: "Echo weighs time since contact, relationship context, and your latest notes.",
                    symbol: "sun.max.fill",
                    color: .orange
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Needs attention").font(.headline)
                    ForEach(priorityContacts) { contact in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(contact.fullName).font(.subheadline.bold())
                                Text(contact.jobTitle ?? contact.tags.first ?? "Contact")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(contact.daysSinceContact.map { "\($0)d" } ?? "—")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))

                Button(action: generate) {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        Text("Create today's briefing")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isLoading || priorityContacts.isEmpty)

                if let result {
                    AITextResultView(text: result, model: model, symbol: "sun.max.fill")
                }
            }
            .padding()
        }
        .navigationTitle("Daily briefing")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Echo AI", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func generate() {
        isLoading = true
        result = nil
        Task {
            defer { isLoading = false }
            do {
                let features = try EchoAIEnvironment.features()
                let privacy = AIPrivacyContext(
                    people: priorityContacts.map(\.fullName),
                    companies: priorityContacts.compactMap(\.companyName)
                )
                let summary = priorityContacts.map { contact in
                    let alias = privacy.alias(for: contact.fullName) ?? "Person"
                    let note = contact.notes.sorted { $0.createdAt > $1.createdAt }.first?.content ?? "No recent note"
                    return "\(alias): \(contact.jobTitle ?? "contact"), \(contact.daysSinceContact.map { "\($0) days since contact" } ?? "last contact unknown"), note: \(privacy.anonymize(note))"
                }.joined(separator: "\n")
                let response = try await features.dailyBriefing(
                    dateDescription: Date.now.formatted(date: .long, time: .omitted),
                    attentionSummary: summary
                )
                result = privacy.restoreAliases(in: response.text)
                model = response.model.rawValue
            } catch {
                errorMessage = EchoAIEnvironment.message(for: error)
            }
        }
    }
}

struct SalesCoachingView: View {
    let deals: [Deal]

    @State private var selectedIndex = 0
    @State private var transcript = ""
    @State private var result: String?
    @State private var model: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var selectedDeal: Deal? {
        deals.indices.contains(selectedIndex) ? deals[selectedIndex] : nil
    }

    var body: some View {
        Form {
            if deals.isEmpty {
                ContentUnavailableView(
                    "No deals yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Add a deal in Pipeline first.")
                )
            } else {
                Section("Deal") {
                    Picker("Opportunity", selection: $selectedIndex) {
                        ForEach(Array(deals.enumerated()), id: \.offset) { index, deal in
                            Text(deal.title).tag(index)
                        }
                    }
                    if let deal = selectedDeal {
                        LabeledContent("Stage", value: deal.stage.title)
                        LabeledContent(
                            "Value",
                            value: deal.value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                        )
                        if let contact = deal.contact {
                            LabeledContent("Contact", value: contact.fullName)
                        }
                    }
                }

                Section("Conversation or follow-up notes") {
                    TextEditor(text: $transcript)
                        .frame(minHeight: 150)
                    Text("Paste a call summary, message thread, or your planned follow-up.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(action: generate) {
                        HStack {
                            if isLoading { ProgressView() }
                            Label("Get follow-up advice", systemImage: "sparkles")
                        }
                    }
                    .disabled(isLoading || transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let result {
                    Section {
                        AITextResultView(text: result, model: model, symbol: "chart.line.uptrend.xyaxis")
                    }
                }
            }
        }
        .navigationTitle("Sales follow-up")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadDefaultTranscript() }
        .onChange(of: selectedIndex) { _, _ in loadDefaultTranscript() }
        .alert("Echo AI", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadDefaultTranscript() {
        guard let contact = selectedDeal?.contact else {
            transcript = ""
            return
        }
        transcript = (
            contact.interactions.sorted { $0.date > $1.date }.prefix(4).map(\.summary) +
            contact.notes.sorted { $0.createdAt > $1.createdAt }.prefix(3).map(\.content)
        )
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    private func generate() {
        guard let deal = selectedDeal else { return }
        isLoading = true
        result = nil
        Task {
            defer { isLoading = false }
            do {
                let features = try EchoAIEnvironment.features()
                let contact = deal.contact
                let privacy = AIPrivacyContext(
                    people: contact.map { [$0.fullName] } ?? [],
                    companies: contact?.companyName.map { [$0] } ?? []
                )
                let response = try await features.salesCoaching(
                    transcript: privacy.anonymize(transcript),
                    dealStage: deal.stage.title,
                    productType: deal.title
                )
                result = privacy.restoreAliases(in: response.text)
                model = response.model.rawValue
            } catch {
                errorMessage = EchoAIEnvironment.message(for: error)
            }
        }
    }
}

enum DocumentRecognitionKind {
    case businessCard
    case policy

    var title: String {
        switch self {
        case .businessCard: "Business card"
        case .policy: "Policy scan"
        }
    }

    var symbol: String {
        switch self {
        case .businessCard: "person.crop.rectangle"
        case .policy: "doc.text.viewfinder"
        }
    }
}

struct DocumentRecognitionView: View {
    let kind: DocumentRecognitionKind

    @Environment(\.modelContext) private var modelContext
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var extractedText = ""
    @State private var card: BusinessCardInfo?
    @State private var policy: PolicyDocumentInfo?
    @State private var model: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AIHero(
                    title: kind == .businessCard ? "Turn a card into a contact" : "Understand a policy at a glance",
                    subtitle: "Text recognition happens on this device. DeepSeek structures the extracted text after you choose a photo.",
                    symbol: kind.symbol,
                    color: kind == .businessCard ? .blue : .teal
                )

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(
                        extractedText.isEmpty ? "Choose photo" : "Choose another photo",
                        systemImage: "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(kind == .businessCard ? .blue : .teal)
                .disabled(isLoading)

                if isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Reading and structuring the document…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }

                if !extractedText.isEmpty {
                    DisclosureGroup("Recognized text") {
                        Text(extractedText)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                            .padding(.top, 8)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }

                if let card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Card details").font(.headline)
                        ResultRow("Name", card.name)
                        ResultRow("Company", card.company)
                        ResultRow("Title", card.title)
                        ResultRow("Phone", card.phone)
                        ResultRow("Email", card.email)
                        ResultRow("Website", card.website)
                        if let model {
                            Text(model).font(.caption2).foregroundStyle(.tertiary)
                        }
                        Button(saved ? "Saved to People" : "Save to People", action: saveCard)
                            .buttonStyle(.borderedProminent)
                            .disabled(saved || card.name.isEmpty)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }

                if let policy {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Policy details").font(.headline)
                        ResultRow("Policy number", policy.policyNumber)
                        ResultRow("Insured", policy.insuredName)
                        ResultRow("Type", policy.insuranceType)
                        ResultRow("Premium", policy.premiumAmount)
                        ResultRow("Coverage", policy.coverageAmount)
                        ResultRow("Effective", policy.effectiveDate)
                        ResultRow("Expiry", policy.expiryDate)
                        ResultRow("Beneficiary", policy.beneficiary)
                        ResultRow("Notes", policy.notes)
                        if let model {
                            Text(model).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding()
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            recognize(item)
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

    private func recognize(_ item: PhotosPickerItem) {
        isLoading = true
        card = nil
        policy = nil
        saved = false
        Task {
            defer { isLoading = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw LocalTextRecognitionError.noText
                }
                extractedText = try await LocalTextRecognitionService.recognizeText(in: data)
                let features = try EchoAIEnvironment.features()
                switch kind {
                case .businessCard:
                    let response = try await features.businessCard(extractedText: extractedText)
                    card = response.value
                    model = response.model.rawValue
                case .policy:
                    let response = try await features.policyDocument(extractedText: extractedText)
                    policy = response.value
                    model = response.model.rawValue
                }
            } catch {
                errorMessage = EchoAIEnvironment.message(for: error)
            }
        }
    }

    private func saveCard() {
        guard let card, !card.name.isEmpty else { return }
        let parts = card.name.split(separator: " ", maxSplits: 1).map(String.init)
        let contact = EchoContact(
            givenName: parts.first ?? card.name,
            familyName: parts.count > 1 ? parts[1] : "",
            phoneNumber: card.phone.nilIfEmpty,
            emailAddress: card.email.nilIfEmpty,
            companyName: card.company.nilIfEmpty,
            jobTitle: card.title.nilIfEmpty
        )
        modelContext.insert(contact)
        try? modelContext.save()
        saved = true
    }
}

private struct AIHero: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 32))
                .foregroundStyle(color)
            Text(title).font(.title2.bold())
            Text(subtitle).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct AITextResultView: View {
    let text: String
    let model: String?
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Echo AI", systemImage: symbol)
                .font(.caption.bold())
                .foregroundStyle(.indigo)
            Text(text).textSelection(.enabled)
            if let model {
                Text(model).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ResultRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        if !value.isEmpty {
            HStack(alignment: .top) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .leading)
                Text(value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
