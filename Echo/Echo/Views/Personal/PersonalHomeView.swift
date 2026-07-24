import SwiftData
import SwiftUI

struct PersonalHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @State private var showingNewContact = false
    @State private var showingBusinessCard = false
    @State private var importMessage: String?
    @State private var searchText = ""

    private var prioritized: [EchoContact] {
        contacts.filter(\.isInEchoLayer).sorted {
            EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1)
        }
    }

    private var visibleContacts: [EchoContact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return prioritized }
        return prioritized.filter {
            [$0.fullName, $0.emailAddress, $0.phoneNumber, $0.companyName, $0.jobTitle]
                .compactMap { $0 }
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Today's echo", systemImage: "wave.3.right")
                            .font(.headline)
                            .foregroundStyle(.indigo)
                        Text(prioritized.first.map { "It may be a good day to reach out to \($0.givenName)." } ?? "Add someone you care about to begin.")
                            .font(.title3.weight(.semibold))
                        Text("Small moments keep important relationships alive.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("Your people") {
                    ForEach(visibleContacts) { contact in
                        NavigationLink(value: contact) {
                            ContactRow(contact: contact)
                        }
                    }
                }
            }
            .navigationTitle("Echo")
            .searchable(text: $searchText, prompt: "Name, company, email, or phone")
            .navigationDestination(for: EchoContact.self) { ContactDetailView(contact: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            do {
                                let result = try await ContactImportService().importContacts(into: modelContext)
                                if result.added == 0 && result.updated == 0 {
                                    importMessage = "Your contacts are already up to date."
                                } else {
                                    importMessage = "Added \(result.added) and updated \(result.updated) contacts."
                                }
                            } catch {
                                importMessage = "Contacts could not be imported."
                            }
                        }
                    } label: { Image(systemName: "person.crop.circle.badge.plus") }
                    .accessibilityLabel("Import contacts")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingNewContact = true
                        } label: {
                            Label("Add manually", systemImage: "person.badge.plus")
                        }
                        Button {
                            showingBusinessCard = true
                        } label: {
                            Label("Scan business card", systemImage: "person.crop.rectangle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add person")
                }
            }
            .sheet(isPresented: $showingNewContact) { NewContactView() }
            .sheet(isPresented: $showingBusinessCard) {
                NavigationStack {
                    DocumentRecognitionView(kind: .businessCard)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingBusinessCard = false }
                            }
                        }
                }
            }
            .alert("Contact import", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) { Button("OK") { importMessage = nil } } message: { Text(importMessage ?? "") }
        }
    }
}

private struct ContactRow: View {
    let contact: EchoContact

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.indigo.opacity(0.14))
                .frame(width: 48, height: 48)
                .overlay(Text(contact.initials).font(.headline).foregroundStyle(.indigo))
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let priority = contact.priority, priority != .cold {
                Image(systemName: priority.symbol)
                    .font(.caption)
                    .foregroundStyle(priority == .hot ? .orange : .indigo)
                    .accessibilityLabel("\(priority.title) priority")
            }
            if let days = contact.daysSinceContact {
                Text("\(days)d")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(days > 21 ? .orange : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var detail: String {
        if let company = contact.companyName { return [contact.jobTitle, company].compactMap { $0 }.joined(separator: " · ") }
        return contact.notes.last?.content ?? "Ready for your first note"
    }
}

private struct NewContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var givenName = ""
    @State private var familyName = ""
    @State private var phoneNumber = ""
    @State private var emailAddress = ""
    @State private var companyName = ""
    @State private var jobTitle = ""
    @State private var priority: PriorityLevel?
    @State private var identity: ContactIdentity?

    var body: some View {
        NavigationStack {
            Form {
                TextField("First name", text: $givenName)
                TextField("Last name", text: $familyName)
                TextField("Phone", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("Email", text: $emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                TextField("Company", text: $companyName)
                    .textContentType(.organizationName)
                TextField("Role", text: $jobTitle)
                    .textContentType(.jobTitle)
                Picker("Priority", selection: $priority) {
                    Text("Not set").tag(PriorityLevel?.none)
                    ForEach(PriorityLevel.allCases) { level in
                        Text(level.title).tag(Optional(level))
                    }
                }
                Picker("Identity", selection: $identity) {
                    Text("Not set").tag(ContactIdentity?.none)
                    ForEach(ContactIdentity.allCases) { item in
                        Text(item.rawValue).tag(Optional(item))
                    }
                }
            }
            .navigationTitle("New person")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let contact = EchoContact(
                            givenName: givenName.trimmed,
                            familyName: familyName.trimmed,
                            phoneNumber: phoneNumber.trimmed.nilIfEmpty,
                            emailAddress: emailAddress.trimmed.nilIfEmpty,
                            priority: priority,
                            companyName: companyName.trimmed.nilIfEmpty,
                            jobTitle: jobTitle.trimmed.nilIfEmpty
                        )
                        contact.tags = identity.map { [$0.rawValue] } ?? []
                        modelContext.insert(contact)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(givenName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
