import SwiftData
import SwiftUI

struct ContactDetailView: View {
    @Environment(\.dismiss) private var dismissDetail
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
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

            Section {
                Picker(String(localized: "Intention"), selection: intentionBinding) {
                    Text(String(localized: "Not sure yet")).tag(RelationshipIntent?.none)
                    ForEach(RelationshipIntent.allCases) { intent in
                        Label(intent.title, systemImage: intent.symbol).tag(Optional(intent))
                    }
                }
                RelationshipCadencePicker(days: cadenceBinding)
                TextField(String(localized: "What do you want to remember about this relationship?"), text: relationshipContextBinding, axis: .vertical)
                    .lineLimit(2...6)
                if let reviewed = contact.lastRelationshipReviewAt {
                    LabeledContent(String(localized: "Last reflected")) { Text(reviewed, style: .relative).foregroundStyle(.secondary) }
                }
                if let action = contact.relationshipActions.first(where: { $0.status == .planned }) {
                    LabeledContent(String(localized: "Planned action")) { Text(action.type.title).foregroundStyle(.indigo) }
                }
            } header: {
                Text(String(localized: "Relationship now"))
            } footer: {
                Text(String(localized: "This is your intention, not a score assigned to the other person."))
            }

            if !contact.relationshipReflections.isEmpty || !contact.relationshipActions.isEmpty {
                Section(String(localized: "Reflection history")) {
                    ForEach(contact.relationshipReflections.sorted { $0.createdAt > $1.createdAt }) { reflection in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reflection.selectedIntent?.title ?? String(localized: "Not sure yet")).font(.subheadline.bold())
                            if let context = reflection.contextText { Text(context).foregroundStyle(.secondary) }
                            if let outcome = reflection.outcome {
                                Label(outcome.title, systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.indigo)
                            }
                            Text(reflection.createdAt, style: .date).font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    ForEach(contact.relationshipActions.sorted { $0.createdAt > $1.createdAt }) { action in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(action.type.title, systemImage: action.type.symbol)
                                .font(.subheadline.bold())
                            Text(action.status.localizedTitle)
                                .foregroundStyle(.secondary)
                            Text(action.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if contact.phoneNumber != nil || contact.emailAddress != nil {
                Section("Contact") {
                    HStack(spacing: 12) {
                        if let phoneNumber = contact.phoneNumber,
                           let callURL = PhoneCallService.destination(for: phoneNumber) {
                            Button {
                                EchoEngine.markReachedOut(to: contact, type: .called, note: nil, in: modelContext)
                                openURL(callURL)
                            } label: {
                                Label("Call", systemImage: "phone.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        if contact.phoneNumber != nil {
                            Button {
                                outreachChannel = .message
                            } label: {
                                Label("Message", systemImage: "message.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
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
                    Text("Call opens the iPhone dialer. Echo drafts a personalized opener for messages and email.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !contact.availableSocialPlatforms.isEmpty {
                Section {
                    ForEach(contact.availableSocialPlatforms) { platform in
                        Button {
                            outreachChannel = .social(platform)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: platform.symbol)
                                    .frame(width: 28)
                                    .foregroundStyle(.indigo)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Message on \(platform.title)")
                                        .foregroundStyle(.primary)
                                    Text(contact.socialIdentifier(for: platform) ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } header: {
                    Text("Social")
                } footer: {
                    Text("Echo prepares a draft, then opens the platform. Some apps require you to paste the copied draft before sending.")
                }
            }

            Section("Profile") {
                Picker("Relationship", selection: relationshipBinding) {
                    ForEach(RelationshipDomain.allCases) { domain in
                        Label(domain.title, systemImage: domain.symbol).tag(domain)
                    }
                }
                .pickerStyle(.menu)
                .tint(.indigo)
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
                if contact.isBusinessRelationship, let priority = contact.priority {
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

            Section("Record a connection") {
                Text("Echo cannot read the iPhone call or Messages history. When you connect outside Echo, record it here so future recommendations have the right context.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("How did you connect?", selection: $selectedType) {
                    ForEach(InteractionType.allCases) { type in
                        Label(type.title, systemImage: type.symbol).tag(type)
                    }
                }
                TextField("A note to remember…", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                Button("Save connection") {
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
            PipelineItemEditor(pipeline: nil, presetContact: contact)
        }
    }

    private var subtitle: String? {
        [contact.jobTitle, contact.companyName].compactMap { $0 }.joined(separator: " at ").nilIfEmpty
    }

    private var businessDeals: [Deal] {
        deals.filter { $0.contact?.systemIdentifier == contact.systemIdentifier }
    }

    private var relationshipBinding: Binding<RelationshipDomain> {
        Binding(
            get: { contact.relationshipDomain },
            set: { newValue in
                contact.relationshipDomain = newValue
                try? modelContext.save()
            }
        )
    }

    private var intentionBinding: Binding<RelationshipIntent?> {
        Binding(
            get: { contact.relationshipIntent },
            set: { newValue in
                _ = try? RelationshipJourneyService().review(
                    contact: contact,
                    intent: newValue,
                    contextText: contact.relationshipContext,
                    theme: .ongoing,
                    journey: nil,
                    in: modelContext
                )
            }
        )
    }

    private var cadenceBinding: Binding<Int?> {
        Binding(get: { contact.desiredCadenceDays }, set: { contact.desiredCadenceDays = $0; try? modelContext.save() })
    }

    private var relationshipContextBinding: Binding<String> {
        Binding(get: { contact.relationshipContext ?? "" }, set: { contact.relationshipContext = $0; try? modelContext.save() })
    }

    private func interactionTitle(_ interaction: Interaction) -> String {
        guard interaction.type == .emailed, let isIncoming = interaction.isIncoming else {
            return interaction.type.title
        }
        return isIncoming ? "Received email" : "Sent email"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
