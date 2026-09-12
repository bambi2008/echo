import SwiftData
import SwiftUI

struct ContactDetailView: View {
    @EnvironmentObject private var kipHandoffRouter: KipHandoffRouter
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
    @State private var showingDealEditor = false
    @State private var editingDeal: Deal?
    @State private var dealPendingDeletion: Deal?
    @State private var showingDeleteDealConfirmation = false
    @State private var dealErrorMessage: String?
    @State private var kipHandoffMessage: String?

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
                Picker("Identity tag", selection: businessRoleBinding) {
                    ForEach(BusinessContactRole.allCases) { role in
                        Label(role.title, systemImage: role.symbol).tag(role)
                    }
                }
                RelationshipCadencePicker(days: cadenceBinding)
                TextField("Business context or next objective", text: relationshipContextBinding, axis: .vertical)
                    .lineLimit(2...6)
                if let priority = contact.priority {
                    LabeledContent("Priority") {
                        Label(priority.title, systemImage: priority.symbol).foregroundStyle(priority == .hot ? .orange : .indigo)
                    }
                }
            } header: {
                Text("Business profile")
            } footer: {
                Text("Use this profile to decide who needs a follow-up and what to do next.")
            }

            if let handoff = kipHandoffRouter.handoff(for: contact) {
                Section {
                    Label {
                        Text("\(handoff.action.title) \(contact.fullName)")
                            .font(.headline)
                    } icon: {
                        Image(systemName: handoff.action.symbol)
                            .foregroundStyle(.indigo)
                    }
                    if !handoff.note.isEmpty {
                        Text(handoff.note)
                            .foregroundStyle(.secondary)
                    }
                    if let eventAt = handoff.eventAt {
                        Label {
                            Text(eventAt, format: .dateTime.month().day().hour().minute())
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if canStart(handoff.action) {
                        Button {
                            start(handoff.action)
                        } label: {
                            Label(startTitle(handoff.action), systemImage: handoff.action.symbol)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                    }
                    Button {
                        completeKipHandoff()
                    } label: {
                        Label("Completed — return to Kip", systemImage: "checkmark.circle.fill")
                    }
                } header: {
                    Text("From Kip")
                } footer: {
                    Text("Echo never sends a message or places a call without your confirmation.")
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
                LabeledContent("Identity tag", value: contact.businessRole.title)
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
                    LabeledContent(
                        "Identity",
                        value: contact.tags.map { ContactIdentity(rawValue: $0)?.title ?? $0 }.joined(separator: " · ")
                    )
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
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(deal.title).font(.headline)
                                        if let note = deal.nextActionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                                            Label(note, systemImage: "text.bubble")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    Text(deal.stage.localizedTitle)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.indigo)
                                    Menu {
                                        Button {
                                            editingDeal = deal
                                            showingDealEditor = true
                                        } label: {
                                            Label("Edit opportunity", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            dealPendingDeletion = deal
                                            showingDeleteDealConfirmation = true
                                        } label: {
                                            Label("Delete opportunity", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                    .accessibilityLabel("Manage opportunity")
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
        .sheet(isPresented: $showingDealEditor, onDismiss: { editingDeal = nil }) {
            if let editingDeal {
                PipelineItemEditor(pipeline: editingDeal.pipeline, item: editingDeal)
            }
        }
        .confirmationDialog(
            "Delete opportunity?",
            isPresented: $showingDeleteDealConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete opportunity", role: .destructive) {
                deletePendingDeal()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the business opportunity from the contact and pipeline.")
        }
        .alert("Could not delete opportunity", isPresented: Binding(
            get: { dealErrorMessage != nil },
            set: { if !$0 { dealErrorMessage = nil } }
        )) {
            Button("OK") { dealErrorMessage = nil }
        } message: {
            Text(dealErrorMessage ?? "")
        }
        .alert("Kip and Echo", isPresented: Binding(
            get: { kipHandoffMessage != nil },
            set: { if !$0 { kipHandoffMessage = nil } }
        )) {
            Button("OK") { kipHandoffMessage = nil }
        } message: {
            Text(kipHandoffMessage ?? "")
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

    private var businessRoleBinding: Binding<BusinessContactRole> {
        Binding(
            get: { contact.businessRole },
            set: { newValue in
                contact.businessRole = newValue
                contact.relationshipDomain = .business
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

    private func deletePendingDeal() {
        guard let deal = dealPendingDeletion else { return }
        modelContext.delete(deal)
        do {
            try modelContext.save()
            dealPendingDeletion = nil
        } catch {
            dealErrorMessage = error.localizedDescription
        }
    }

    private func canStart(_ action: KipHandoffAction) -> Bool {
        switch action {
        case .call:
            contact.phoneNumber.flatMap { PhoneCallService.destination(for: $0) } != nil
        case .message:
            contact.phoneNumber != nil
        case .email:
            contact.emailAddress != nil
        case .contact:
            contact.phoneNumber != nil || contact.emailAddress != nil
        case .meet:
            false
        }
    }

    private func startTitle(_ action: KipHandoffAction) -> String {
        switch action {
        case .call: "Start call"
        case .message: "Write message"
        case .email: "Write email"
        case .contact: contact.phoneNumber == nil ? "Write email" : "Choose a message"
        case .meet: ""
        }
    }

    private func start(_ action: KipHandoffAction) {
        switch action {
        case .call:
            guard let phoneNumber = contact.phoneNumber,
                  let callURL = PhoneCallService.destination(for: phoneNumber) else { return }
            EchoEngine.markReachedOut(to: contact, type: .called, note: nil, in: modelContext)
            openURL(callURL)
        case .message:
            outreachChannel = .message
        case .email:
            outreachChannel = .email
        case .contact:
            if contact.phoneNumber != nil {
                outreachChannel = .message
            } else if contact.emailAddress != nil {
                outreachChannel = .email
            }
        case .meet:
            break
        }
    }

    private func completeKipHandoff() {
        guard let url = kipHandoffRouter.completionURL() else { return }
        openURL(url) { result in
            if case .discarded = result {
                kipHandoffMessage = "Kip could not be opened. Keep Kip installed, then try again."
            } else {
                kipHandoffRouter.clear()
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
