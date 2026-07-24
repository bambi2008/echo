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

private enum RelationshipScope: String, CaseIterable, Identifiable {
    case all
    case personal
    case business

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .personal: "Personal"
        case .business: "Business"
        }
    }

    func includes(_ contact: EchoContact) -> Bool {
        switch self {
        case .all: true
        case .personal: contact.isPersonalRelationship
        case .business: contact.isBusinessRelationship
        }
    }
}

private enum RelationshipSelectionRule: String, CaseIterable, Identifiable {
    case opportunity
    case contextRich
    case cooling
    case overdue
    case priority
    case business
    case quiet
    case active
    case all

    var id: String { rawValue }

    static func options(for mode: RelationshipAnalysisMode) -> [Self] {
        switch mode {
        case .insight:
            [.opportunity, .priority, .business, .contextRich, .all]
        case .health:
            [.cooling, .overdue, .quiet, .active, .all]
        }
    }

    var title: String {
        switch self {
        case .opportunity: "Best opportunities"
        case .contextRich: "Enough context"
        case .cooling: "Cooling unusually"
        case .overdue: "Long time no contact"
        case .priority: "Priority relationships"
        case .business: "Business relationships"
        case .quiet: "Low interaction"
        case .active: "Healthy momentum"
        case .all: "Everyone"
        }
    }

    func description(for mode: RelationshipAnalysisMode) -> String {
        switch self {
        case .opportunity: "Combines Hot/Warm priority, business relevance, saved context, and current attention."
        case .contextRich: "People with at least three interactions or two notes, so the analysis has useful evidence."
        case .cooling: "Ranks people whose current gap is unusually long compared with your past rhythm with them."
        case .overdue: "People you have not contacted for at least 60 days."
        case .priority: "People marked Hot or Warm, sorted by urgency."
        case .business: "Clients, prospects, partners, investors, and professional contacts."
        case .quiet: "Relationships with two or fewer recorded interactions."
        case .active: "Relationships with at least three interactions and contact within the last 30 days."
        case .all:
            mode == .insight
                ? "The full contact list, ranked by relationship opportunity."
                : "The full contact list, ranked by health risk relative to past cadence."
        }
    }

    func includes(_ contact: EchoContact) -> Bool {
        switch self {
        case .all:
            true
        case .opportunity:
            contact.priority == .hot
                || contact.priority == .warm
                || isBusiness(contact)
                || !contact.notes.isEmpty
        case .contextRich:
            contact.interactions.count >= 3 || contact.notes.count >= 2
        case .cooling:
            RelationshipMetrics.averageCadenceDays(for: contact) != nil
                && RelationshipMetrics.gapRatio(for: contact) >= 1.5
        case .overdue:
            (contact.daysSinceContact ?? 365) >= 60
        case .priority:
            contact.priority == .hot || contact.priority == .warm
        case .business:
            isBusiness(contact)
        case .quiet:
            contact.interactions.count <= 2
        case .active:
            contact.interactions.count >= 3 && (contact.daysSinceContact ?? 365) <= 30
        }
    }

    func orders(_ left: EchoContact, before right: EchoContact, mode: RelationshipAnalysisMode) -> Bool {
        let leftDays = left.daysSinceContact ?? 365
        let rightDays = right.daysSinceContact ?? 365
        let leftAttention = EchoEngine.attentionScore(for: left)
        let rightAttention = EchoEngine.attentionScore(for: right)

        switch self {
        case .opportunity, .contextRich:
            let leftOpportunity = RelationshipMetrics.opportunityScore(for: left)
            let rightOpportunity = RelationshipMetrics.opportunityScore(for: right)
            if leftOpportunity != rightOpportunity { return leftOpportunity > rightOpportunity }
        case .cooling:
            let leftRisk = RelationshipMetrics.gapRatio(for: left)
            let rightRisk = RelationshipMetrics.gapRatio(for: right)
            if leftRisk != rightRisk { return leftRisk > rightRisk }
        case .overdue:
            if leftDays != rightDays { return leftDays > rightDays }
        case .priority:
            let priorityRank: (EchoContact) -> Int = {
                switch $0.priority {
                case .hot: 2
                case .warm: 1
                default: 0
                }
            }
            let leftPriority = priorityRank(left)
            let rightPriority = priorityRank(right)
            if leftPriority != rightPriority { return leftPriority > rightPriority }
            if leftAttention != rightAttention { return leftAttention > rightAttention }
            if leftDays != rightDays { return leftDays > rightDays }
        case .quiet:
            if left.interactions.count != right.interactions.count {
                return left.interactions.count < right.interactions.count
            }
            if leftDays != rightDays { return leftDays > rightDays }
        case .active:
            if leftDays != rightDays { return leftDays < rightDays }
            if left.interactions.count != right.interactions.count {
                return left.interactions.count > right.interactions.count
            }
        case .business:
            if leftAttention != rightAttention { return leftAttention > rightAttention }
            if leftDays != rightDays { return leftDays > rightDays }
        case .all:
            switch mode {
            case .insight:
                let leftOpportunity = RelationshipMetrics.opportunityScore(for: left)
                let rightOpportunity = RelationshipMetrics.opportunityScore(for: right)
                if leftOpportunity != rightOpportunity { return leftOpportunity > rightOpportunity }
            case .health:
                let leftRisk = RelationshipMetrics.gapRatio(for: left)
                let rightRisk = RelationshipMetrics.gapRatio(for: right)
                if leftRisk != rightRisk { return leftRisk > rightRisk }
            }
        }
        return left.fullName < right.fullName
    }

    func metric(for contact: EchoContact, mode: RelationshipAnalysisMode) -> String {
        switch self {
        case .opportunity:
            "Score \(RelationshipMetrics.opportunityScore(for: contact))"
        case .contextRich:
            "\(contact.interactions.count + contact.notes.count) records"
        case .cooling:
            RelationshipMetrics.cadenceLabel(for: contact)
        case .overdue:
            contact.daysSinceContact.map { "\($0)d gap" } ?? "Unknown gap"
        case .priority:
            contact.priority?.title ?? "Not set"
        case .business:
            contact.companyName ?? contact.tags.first ?? "Business"
        case .quiet:
            "\(contact.interactions.count) interactions"
        case .active:
            contact.daysSinceContact.map { "\($0)d recent" } ?? "Active"
        case .all:
            mode == .insight
                ? "Score \(RelationshipMetrics.opportunityScore(for: contact))"
                : RelationshipMetrics.cadenceLabel(for: contact)
        }
    }

    private func isBusiness(_ contact: EchoContact) -> Bool {
        contact.isBusinessRelationship
    }
}

private enum RelationshipMetrics {
    static func opportunityScore(for contact: EchoContact) -> Int {
        let priority: Int
        switch contact.priority {
        case .hot: priority = 40
        case .warm: priority = 24
        default: priority = 0
        }
        let business = contact.isBusinessRelationship ? 18 : 0
        let context = min(contact.interactions.count * 3 + contact.notes.count * 4, 24)
        return priority + business + context + min(EchoEngine.attentionScore(for: contact), 25)
    }

    static func averageCadenceDays(for contact: EchoContact) -> Double? {
        let dates = contact.interactions.map(\.date).sorted(by: >)
        guard dates.count >= 2 else { return nil }
        let gaps = zip(dates, dates.dropFirst()).map {
            Double(max(1, Calendar.current.dateComponents([.day], from: $1, to: $0).day ?? 1))
        }
        return gaps.reduce(0, +) / Double(gaps.count)
    }

    static func gapRatio(for contact: EchoContact) -> Double {
        let gap = Double(contact.daysSinceContact ?? 365)
        return gap / max(averageCadenceDays(for: contact) ?? 30, 7)
    }

    static func cadenceLabel(for contact: EchoContact) -> String {
        guard averageCadenceDays(for: contact) != nil else {
            return contact.daysSinceContact.map { "\($0)d gap" } ?? "Limited history"
        }
        return "\(gapRatio(for: contact).formatted(.number.precision(.fractionLength(1))))× cadence"
    }
}

struct RelationshipAnalysisView: View {
    let mode: RelationshipAnalysisMode
    let contacts: [EchoContact]

    @State private var rule: RelationshipSelectionRule
    @State private var scope: RelationshipScope = .all
    @State private var limit = 5
    @State private var result: String?
    @State private var model: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(mode: RelationshipAnalysisMode, contacts: [EchoContact]) {
        self.mode = mode
        self.contacts = contacts
        _rule = State(initialValue: mode == .insight ? .opportunity : .cooling)
    }

    private var selectedContacts: [EchoContact] {
        Array(contacts
            .filter { scope.includes($0) && rule.includes($0) }
            .sorted { rule.orders($0, before: $1, mode: mode) }
            .prefix(limit))
    }

    var body: some View {
        Form {
            Section("Smart selection") {
                Picker("People", selection: $scope) {
                    ForEach(RelationshipScope.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Rule", selection: $rule) {
                    ForEach(RelationshipSelectionRule.options(for: mode)) { option in
                        Text(option.title).tag(option)
                    }
                }
                Text(rule.description(for: mode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Batch size", selection: $limit) {
                    Text("Top 5").tag(5)
                    Text("Top 10").tag(10)
                }
                .pickerStyle(.segmented)
            }

            Section("\(selectedContacts.count) people selected") {
                ForEach(selectedContacts) { contact in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(contact.fullName).font(.subheadline.bold())
                            Text(contact.jobTitle ?? contact.tags.first ?? "Contact")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(rule.metric(for: contact, mode: mode))
                                .font(.caption.bold())
                                .foregroundStyle(.indigo)
                            Text("Attention \(EchoEngine.attentionScore(for: contact))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    generate()
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Label("Analyze \(selectedContacts.count) people", systemImage: "sparkles")
                    }
                }
                .disabled(isLoading || selectedContacts.isEmpty)
            } footer: {
                Text("Echo analyzes the selected group in one DeepSeek request.")
            }

            if let result {
                Section {
                    AITextResultView(text: result, model: model, symbol: mode.symbol)
                }
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 72, for: .scrollContent)
        .onChange(of: scope) { _, _ in result = nil }
        .onChange(of: rule) { _, _ in result = nil }
        .onChange(of: limit) { _, _ in result = nil }
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
        guard !selectedContacts.isEmpty else { return }
        isLoading = true
        result = nil
        Task {
            defer { isLoading = false }
            do {
                let features = try EchoAIEnvironment.features()
                let privacy = AIPrivacyContext(
                    people: selectedContacts.map(\.fullName),
                    companies: selectedContacts.compactMap(\.companyName)
                )
                let peopleSummary = selectedContacts.map { contact in
                    let alias = privacy.alias(for: contact.fullName) ?? "Person"
                    let interactions = contact.interactions
                        .sorted { $0.date > $1.date }
                        .prefix(4)
                        .map {
                            let direction = $0.isIncoming.map { $0 ? "incoming" : "outgoing" } ?? "recorded"
                            return "\($0.typeRawValue) (\(direction)): \($0.summary)"
                        }
                        .joined(separator: "; ")
                    let notes = contact.notes
                        .sorted { $0.createdAt > $1.createdAt }
                        .prefix(2)
                        .map(\.content)
                        .joined(separator: "; ")
                    let cadence = RelationshipMetrics.averageCadenceDays(for: contact)
                        .map { "\($0.formatted(.number.precision(.fractionLength(0)))) days" }
                        ?? "limited history"
                    return """
                    \(alias) | relationship: \(contact.relationshipDomain.title) | role: \(contact.jobTitle ?? contact.tags.first ?? "contact") | priority: \(contact.priority?.title ?? "not set") | last contact: \(contact.daysSinceContact.map { "\($0) days ago" } ?? "unknown") | usual cadence: \(cadence) | gap vs cadence: \(RelationshipMetrics.cadenceLabel(for: contact)) | interactions: \(contact.interactions.count) | recent context: \(privacy.anonymize([interactions, notes].filter { !$0.isEmpty }.joined(separator: "; ")))
                    """
                }.joined(separator: "\n")

                let response: AIResult
                switch mode {
                case .insight:
                    response = try await features.relationshipInsights(
                        peopleSummary: peopleSummary
                    )
                case .health:
                    response = try await features.relationshipHealthReview(
                        peopleSummary: peopleSummary
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

    private var personalPriorityContacts: [EchoContact] {
        Array(contacts.filter {
            $0.relationshipDomain == .personal
        }.sorted {
            EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1)
        }.prefix(3))
    }

    private var businessPriorityContacts: [EchoContact] {
        Array(contacts.filter(\.isBusinessRelationship).sorted {
            EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1)
        }.prefix(3))
    }

    private var priorityContacts: [EchoContact] {
        personalPriorityContacts + businessPriorityContacts
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

                briefingGroup(
                    title: "Personal relationships",
                    symbol: "heart.fill",
                    contacts: personalPriorityContacts
                )
                briefingGroup(
                    title: "Business follow-ups",
                    symbol: "briefcase.fill",
                    contacts: businessPriorityContacts
                )

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

    private func briefingGroup(
        title: String,
        symbol: String,
        contacts: [EchoContact]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline)
            if contacts.isEmpty {
                Text("No relationships need attention here today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(contacts) { contact in
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
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
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
                    let latestInteraction = contact.interactions.sorted { $0.date > $1.date }.first
                    let interactionContext = latestInteraction.map {
                        let direction = $0.isIncoming.map { $0 ? "incoming" : "outgoing" } ?? "recorded"
                        return "\(direction) \($0.typeRawValue), \($0.summary)"
                    } ?? "No recorded interaction"
                    return "\(alias): \(contact.relationshipDomain.title) relationship, \(contact.jobTitle ?? "contact"), \(contact.daysSinceContact.map { "\($0) days since contact" } ?? "last contact unknown"), latest: \(privacy.anonymize(interactionContext)), note: \(privacy.anonymize(note))"
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
