import SwiftData
import SwiftUI

struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let contact: EchoContact
    let onDelete: () -> Void

    @State private var givenName: String
    @State private var familyName: String
    @State private var phoneNumber: String
    @State private var emailAddress: String
    @State private var companyName: String
    @State private var jobTitle: String
    @State private var priority: PriorityLevel?
    @State private var selectedIdentities: Set<ContactIdentity>
    @State private var isInEchoLayer: Bool
    @State private var confirmingDelete = false

    init(contact: EchoContact, onDelete: @escaping () -> Void) {
        self.contact = contact
        self.onDelete = onDelete
        _givenName = State(initialValue: contact.givenName)
        _familyName = State(initialValue: contact.familyName)
        _phoneNumber = State(initialValue: contact.phoneNumber ?? "")
        _emailAddress = State(initialValue: contact.emailAddress ?? "")
        _companyName = State(initialValue: contact.companyName ?? "")
        _jobTitle = State(initialValue: contact.jobTitle ?? "")
        _priority = State(initialValue: contact.priority)
        _selectedIdentities = State(initialValue: Set(contact.tags.compactMap(ContactIdentity.init(rawValue:))))
        _isInEchoLayer = State(initialValue: contact.isInEchoLayer)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $givenName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $familyName)
                        .textContentType(.familyName)
                }

                Section("Contact") {
                    TextField("Phone", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Email", text: $emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                }

                Section("Work") {
                    TextField("Company", text: $companyName)
                        .textContentType(.organizationName)
                    TextField("Role", text: $jobTitle)
                        .textContentType(.jobTitle)
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        Text("Not set").tag(PriorityLevel?.none)
                        ForEach(PriorityLevel.allCases) { level in
                            Label(level.title, systemImage: level.symbol)
                                .tag(Optional(level))
                        }
                    }
                    Toggle("Include in Echo", isOn: $isInEchoLayer)
                } header: {
                    Text("Relationship")
                } footer: {
                    Text("Priority and identity determine which people appear in Echo AI smart selections.")
                }

                Section("Identity") {
                    ForEach(ContactIdentity.allCases) { identity in
                        Button {
                            toggle(identity)
                        } label: {
                            HStack {
                                Label(identity.rawValue, systemImage: identity.symbol)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedIdentities.contains(identity) {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.indigo)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Delete contact", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
            .navigationTitle("Edit person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(givenName.trimmed.isEmpty && familyName.trimmed.isEmpty)
                }
            }
            .confirmationDialog(
                "Delete \(contact.fullName)?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete contact", role: .destructive, action: deleteContact)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its notes and interaction history will also be deleted. Linked deals will remain.")
            }
        }
    }

    private func toggle(_ identity: ContactIdentity) {
        if selectedIdentities.contains(identity) {
            selectedIdentities.remove(identity)
        } else {
            selectedIdentities.insert(identity)
        }
    }

    private func save() {
        let knownTags = Set(ContactIdentity.allCases.map(\.rawValue))
        let preservedTags = contact.tags.filter { !knownTags.contains($0) }
        contact.givenName = givenName.trimmed
        contact.familyName = familyName.trimmed
        contact.phoneNumber = phoneNumber.trimmed.nilIfEmpty
        contact.emailAddress = emailAddress.trimmed.nilIfEmpty
        contact.companyName = companyName.trimmed.nilIfEmpty
        contact.jobTitle = jobTitle.trimmed.nilIfEmpty
        contact.priority = priority
        contact.isInEchoLayer = isInEchoLayer
        contact.tags = preservedTags + selectedIdentities.map(\.rawValue).sorted()
        try? modelContext.save()
        dismiss()
    }

    private func deleteContact() {
        modelContext.delete(contact)
        try? modelContext.save()
        dismiss()
        onDelete()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
