import SwiftData
import SwiftUI

struct PersonalHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @State private var showingNewContact = false
    @State private var showingBusinessCard = false
    @State private var importMessage: String?

    private var prioritized: [EchoContact] {
        contacts.filter(\.isInEchoLayer).sorted {
            EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1)
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
                    ForEach(prioritized) { contact in
                        NavigationLink(value: contact) {
                            ContactRow(contact: contact)
                        }
                    }
                }
            }
            .navigationTitle("Echo")
            .navigationDestination(for: EchoContact.self) { ContactDetailView(contact: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            do {
                                let count = try await ContactImportService().importContacts(into: modelContext)
                                importMessage = count == 0 ? "No new contacts were added." : "Imported \(count) contacts."
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

    var body: some View {
        NavigationStack {
            Form {
                TextField("First name", text: $givenName)
                TextField("Last name", text: $familyName)
            }
            .navigationTitle("New person")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        modelContext.insert(EchoContact(givenName: givenName, familyName: familyName))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(givenName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
