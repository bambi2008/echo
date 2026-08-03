import EchoAI
import SwiftData
import SwiftUI

struct ContactDetailView: View {
    @Environment(\.dismiss) private var dismissDetail
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deal.createdAt, order: .reverse) private var deals: [Deal]
    @Bindable var contact: EchoContact
    @State private var note = ""
    @State private var selectedType: InteractionType = .messaged
    @State private var outreachChannel: OutreachChannel?
    @State private var showingEditContact = false
    @State private var showingNewDeal = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.indigo.opacity(0.14))
                        .frame(width: 88, height: 88)
                        .overlay(Text(contact.initials).font(.largeTitle.bold()).foregroundStyle(.indigo))
                    Text(contact.fullName).font(.title2.bold())
                    if let subtitle { Text(subtitle).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            if contact.phoneNumber != nil || contact.emailAddress != nil {
                Section("Contact") {
                    HStack(spacing: 12) {
                        if contact.phoneNumber != nil {
                            Button {
                                outreachChannel = .message
                            } label: {
                                Label("Message", systemImage: "message.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                        }
                        if contact.emailAddress != nil {
                            Button {
                                outreachChannel = .email
                            } label: {
                                Label("Email", systemImage: "envelope.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.indigo)
                        }
                    }
                    Text("Echo drafts a personalized opener only after you choose how to reach out.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                RelationshipBriefCard(contact: contact)
            } header: {
                Label("Relationship brief", systemImage: "sparkles")
            }

            Section("Profile") {
                LabeledContent {
                    Label(contact.relationshipDomain.title, systemImage: contact.relationshipDomain.symbol)
                        .foregroundStyle(.indigo)
                } label: {
                    Text("Relationship")
                }
                if let phoneNumber = contact.phoneNumber {
                    LabeledContent("Phone", value: phoneNumber)
                }
                if let emailAddress = contact.emailAddress {
                    LabeledContent("Email", value: emailAddress)
                }
                if let jobTitle = contact.jobTitle {
                    LabeledContent("Role", value: jobTitle)
                }
                if let companyName = contact.companyName {
                    LabeledContent("Company", value: companyName)
                }
                if !contact.tags.isEmpty {
                    LabeledContent("Identity", value: contact.tags.joined(separator: " · "))
                }
                if let priority = contact.priority {
                    LabeledContent {
                        Label(priority.title, systemImage: priority.symbol)
                            .foregroundStyle(priority == .hot ? .orange : .indigo)
                    } label: {
                        Text("Priority")
                    }
                }
            }

            if contact.isBusinessRelationship || !businessDeals.isEmpty {
                Section("Business") {
                    if businessDeals.isEmpty {
                        Text("No business opportunity is linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(businessDeals) { deal in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(deal.title).font(.headline)
                                    Spacer()
                                    Text(deal.stage.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.indigo)
                                }
                                Text(deal.value, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.subheadline.weight(.semibold))
                                if let nextActionDate = deal.nextActionDate {
                                    Label {
                                        Text(nextActionDate, format: .dateTime.month().day().year())
                                    } icon: {
                                        Image(systemName: "calendar")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    Button {
                        showingNewDeal = true
                    } label: {
                        Label("Add opportunity", systemImage: "plus.circle.fill")
                    }
                }
            }

            Section("Contact history") {
                if contact.interactions.isEmpty {
                    Text("Past calls, messages, meetings, and emails will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(contact.interactions.sorted { $0.date > $1.date }) { interaction in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: interaction.type.symbol)
                                .frame(width: 24)
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(interactionTitle(interaction))
                                        .font(.subheadline.weight(.semibold))
                                    if interaction.sourceRawValue == "gmail" {
                                        Text("Gmail")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.indigo)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.indigo.opacity(0.1), in: Capsule())
                                    }
                                }
                                if !interaction.summary.isEmpty {
                                    Text(interaction.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(interaction.date, format: .dateTime.month().day().year().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("Log a moment") {
                Picker("How did you connect?", selection: $selectedType) {
                    ForEach(InteractionType.allCases) { type in
                        Label(type.title, systemImage: type.symbol).tag(type)
                    }
                }
                TextField("A note to remember…", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                Button("Save interaction") {
                    EchoEngine.markReachedOut(to: contact, type: selectedType, note: note, in: modelContext)
                    note = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }

            Section("Memory") {
                if contact.notes.isEmpty {
                    Text("Notes from your conversations will appear here.").foregroundStyle(.secondary)
                } else {
                    ForEach(contact.notes.sorted { $0.createdAt > $1.createdAt }) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.content)
                            Text(item.createdAt, format: .dateTime.month().day().year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(contact.givenName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditContact = true }
            }
        }
        .sheet(item: $outreachChannel) { channel in
            OutreachComposerView(contact: contact, channel: channel)
        }
        .sheet(isPresented: $showingEditContact) {
            EditContactView(contact: contact) {
                dismissDetail()
            }
        }
        .sheet(isPresented: $showingNewDeal) {
            NewDealView(contact: contact)
        }
    }

    private var subtitle: String? {
        [contact.jobTitle, contact.companyName].compactMap { $0 }.joined(separator: " at ").nilIfEmpty
    }

    private var businessDeals: [Deal] {
        deals.filter { $0.contact?.systemIdentifier == contact.systemIdentifier }
    }

    private func interactionTitle(_ interaction: Interaction) -> String {
        guard interaction.type == .emailed, let isIncoming = interaction.isIncoming else {
            return interaction.type.title
        }
        return isIncoming ? "Received email" : "Sent email"
    }
}

private struct RelationshipBriefCard: View {
    let contact: EchoContact

    @State private var brief: RelationshipBrief
    @State private var isAIResult = false
    @State private var isLoading = false
    @State private var model: String?
    @State private var errorMessage: String?

    init(contact: EchoContact) {
        self.contact = contact
        _brief = State(initialValue: Self.localBrief(for: contact))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: momentumSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(momentumColor)
                    .frame(width: 40, height: 40)
                    .background(momentumColor.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(brief.headline)
                        .font(.headline)
                    Text(brief.momentum.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(momentumColor)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                } else {
                    Button {
                        enrichWithAI()
                    } label: {
                        Image(systemName: isAIResult ? "arrow.clockwise" : "sparkles")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(isAIResult ? "Refresh relationship brief" : "Ask Echo AI")
                }
            }

            Label {
                Text(brief.whyNow)
                    .font(.subheadline)
            } icon: {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Evidence")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ForEach(Array(brief.evidence.prefix(3)), id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Label(brief.nextAction, systemImage: "arrow.turn.down.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.indigo)

            HStack(spacing: 8) {
                Text(isAIResult ? "AI enriched" : "On-device preview")
                Text("·")
                Text("Confidence \(brief.confidence)%")
                if let model {
                    Text("· \(model)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var momentumColor: Color {
        switch brief.momentum.lowercased() {
        case "active": .green
        case "cooling": .orange
        case "dormant": .red
        default: .indigo
        }
    }

    private var momentumSymbol: String {
        switch brief.momentum.lowercased() {
        case "active": "arrow.up.right"
        case "cooling": "thermometer.snowflake"
        case "dormant": "pause.circle"
        default: "wave.3.right"
        }
    }

    private func enrichWithAI() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let features = try EchoAIEnvironment.features()
                let privacy = AIPrivacyContext(
                    people: [contact.fullName],
                    companies: contact.companyName.map { [$0] } ?? []
                )
                let alias = privacy.alias(for: contact.fullName) ?? "Person A"
                let interactions = contact.interactions
                    .sorted { $0.date > $1.date }
                    .prefix(5)
                    .map { interaction in
                        let direction = interaction.isIncoming.map { $0 ? "incoming" : "outgoing" } ?? "recorded"
                        return "\(interaction.type.title) (\(direction), \(interaction.date.formatted(date: .abbreviated, time: .omitted))): \(interaction.summary)"
                    }
                    .joined(separator: "; ")
                let memories = contact.notes
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(3)
                    .map(\.content)
                    .joined(separator: "; ")
                let response = try await features.relationshipBrief(
                    personAlias: alias,
                    relationship: contact.relationshipDomain.title,
                    lastContact: contact.daysSinceContact.map { "\($0) days ago" } ?? "unknown",
                    interactionSummary: privacy.anonymize(interactions.nilIfEmpty ?? "No recorded interactions"),
                    memorySummary: privacy.anonymize(memories.nilIfEmpty ?? "No saved memories")
                )
                let value = response.value
                brief = RelationshipBrief(
                    momentum: privacy.restoreAliases(in: value.momentum),
                    headline: privacy.restoreAliases(in: value.headline),
                    whyNow: privacy.restoreAliases(in: value.whyNow),
                    nextAction: privacy.restoreAliases(in: value.nextAction),
                    evidence: value.evidence.map { privacy.restoreAliases(in: $0) },
                    confidence: min(100, max(0, value.confidence))
                )
                model = response.model.rawValue
                isAIResult = true
            } catch {
                errorMessage = "AI is temporarily unavailable. Your on-device preview is still here."
            }
        }
    }

    private static func localBrief(for contact: EchoContact) -> RelationshipBrief {
        let days = contact.daysSinceContact
        let momentum: String
        let headline: String
        if days == nil {
            momentum = "unknown"
            headline = "Echo is still learning this relationship"
        } else if let days, days <= 30 {
            momentum = "active"
            headline = "This relationship has recent momentum"
        } else if let days, days <= 60 {
            momentum = "steady"
            headline = "This relationship may be ready for a light touch"
        } else {
            momentum = "cooling"
            headline = "This relationship may be cooling"
        }

        let gap = days.map { "Last recorded contact was \($0) days ago" } ?? "There is no recorded contact date yet"
        let interactions = "\(contact.interactions.count) interaction\(contact.interactions.count == 1 ? "" : "s") recorded"
        let memory = "\(contact.notes.count) saved memor\(contact.notes.count == 1 ? "y" : "ies")"
        let nextAction = contact.isBusinessRelationship
            ? "Review the next business step before reaching out"
            : "Send a low-pressure check-in when it feels natural"
        return RelationshipBrief(
            momentum: momentum,
            headline: headline,
            whyNow: days.map { $0 > 30 ? "It has been \($0) days since the last recorded contact." : "Your latest recorded contact was \($0) days ago." } ?? "Echo needs one more interaction to understand the rhythm.",
            nextAction: nextAction,
            evidence: [gap, interactions, memory],
            confidence: contact.interactions.isEmpty ? 42 : min(92, 52 + contact.interactions.count * 5)
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
