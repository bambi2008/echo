import SwiftData
import SwiftUI

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deal.createdAt, order: .reverse) private var deals: [Deal]
    @Bindable var contact: EchoContact
    @State private var note = ""
    @State private var selectedType: InteractionType = .messaged
    @State private var outreachChannel: OutreachChannel?

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

            Section("Profile") {
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
            }

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
        .sheet(item: $outreachChannel) { channel in
            OutreachComposerView(contact: contact, channel: channel)
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
