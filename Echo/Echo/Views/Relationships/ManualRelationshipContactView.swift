import SwiftData
import SwiftUI

struct ManualRelationshipContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var givenName = ""
    @State private var familyName = ""
    @State private var phone = ""
    @State private var email = ""
    let onCreate: (EchoContact) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Name")) {
                    TextField(String(localized: "First name"), text: $givenName)
                        .textContentType(.givenName)
                    TextField(String(localized: "Last name"), text: $familyName)
                        .textContentType(.familyName)
                }
                Section(String(localized: "Contact")) {
                    TextField(String(localized: "Phone"), text: $phone)
                        .keyboardType(.phonePad)
                    TextField(String(localized: "Email"), text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(String(localized: "Add someone"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add")) {
                        let contact = EchoContact(
                            givenName: givenName.trimmed,
                            familyName: familyName.trimmed,
                            phoneNumber: phone.trimmed.nilIfEmpty,
                            emailAddress: email.trimmed.nilIfEmpty,
                            relationshipDomain: .business,
                            businessRole: .prospect
                        )
                        contact.relationshipJourneyIncluded = true
                        modelContext.insert(contact)
                        try? modelContext.save()
                        onCreate(contact)
                        dismiss()
                    }
                    .disabled(givenName.trimmed.isEmpty && familyName.trimmed.isEmpty)
                }
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
