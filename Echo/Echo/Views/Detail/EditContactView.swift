import SwiftData
import SwiftUI

struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speech = SpeechRecognitionService()

    let contact: EchoContact
    let onDelete: () -> Void

    @State private var givenName: String
    @State private var familyName: String
    @State private var phoneNumber: String
    @State private var emailAddress: String
    @State private var companyName: String
    @State private var jobTitle: String
    @State private var priority: PriorityLevel?
    @State private var relationshipDomain: RelationshipDomain
    @State private var businessRole: BusinessContactRole
    @State private var desiredCadenceDays: Int?
    @State private var relationshipContext: String
    @State private var selectedIdentities: Set<ContactIdentity>
    @State private var isInEchoLayer: Bool
    @State private var socialIdentifiers: [SocialPlatform: String]
    @State private var confirmingDelete = false
    @State private var voiceTextBeforeRecording = ""

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
        _relationshipDomain = State(initialValue: .business)
        _businessRole = State(initialValue: contact.businessRole)
        _desiredCadenceDays = State(initialValue: contact.desiredCadenceDays)
        _relationshipContext = State(initialValue: contact.relationshipContext ?? "")
        _selectedIdentities = State(initialValue: Set(contact.tags.compactMap(ContactIdentity.init(rawValue:))))
        _isInEchoLayer = State(initialValue: contact.isInEchoLayer)
        _socialIdentifiers = State(initialValue: Dictionary(uniqueKeysWithValues: SocialPlatform.allCases.map {
            ($0, contact.socialIdentifier(for: $0) ?? "")
        }))
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
                    ForEach(SocialPlatform.allCases) { platform in
                        LabeledContent {
                            TextField(platform.fieldPrompt, text: socialBinding(for: platform))
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(platform == .whatsapp ? .phonePad : .URL)
                        } label: {
                            Label(platform.title, systemImage: platform.symbol)
                        }
                    }
                } header: {
                    Text("Social accounts")
                } footer: {
                    Text("Save a username or profile URL. Echo opens the corresponding app when you choose to reach out.")
                }

                Section {
                    Picker("Identity tag", selection: $businessRole) {
                        ForEach(BusinessContactRole.allCases) { role in
                            Label(role.title, systemImage: role.symbol).tag(role)
                        }
                    }
                    RelationshipCadencePicker(days: $desiredCadenceDays)
                    TextField("Business context or next objective", text: $relationshipContext, axis: .vertical)
                        .lineLimit(2...6)
                    Button {
                        toggleVoiceContext()
                    } label: {
                        Label(
                            speech.isRecording
                                ? String(localized: "Stop listening")
                                : String(localized: "Describe this relationship by voice"),
                            systemImage: speech.isRecording ? "stop.fill" : "mic.fill"
                        )
                    }
                    .tint(speech.isRecording ? .red : .indigo)
                    if relationshipDomain.includes(.business) {
                        Picker("Business priority", selection: $priority) {
                            Text("Not set").tag(PriorityLevel?.none)
                            ForEach(PriorityLevel.allCases) { level in
                                Label(level.title, systemImage: level.symbol).tag(Optional(level))
                            }
                        }
                    }
                    Toggle("Include in Echo", isOn: $isInEchoLayer)
                } header: {
                    Text("Business profile")
                } footer: {
                    Text("Choose the commercial role, follow-up rhythm, and context that should guide your next action.")
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
            .onChange(of: speech.transcript) { _, transcript in
                relationshipContext = VoiceTranscriptComposer.combine(
                    existing: voiceTextBeforeRecording,
                    spoken: transcript
                )
            }
            .onDisappear { speech.stop() }
            .alert(String(localized: "Voice input"), isPresented: Binding(
                get: { speech.errorMessage != nil },
                set: { if !$0 { speech.errorMessage = nil } }
            )) {
                Button(String(localized: "OK")) { speech.errorMessage = nil }
            } message: {
                Text(speech.errorMessage ?? "")
            }
        }
    }

    private func save() {
        speech.stop()
        let knownTags = Set(ContactIdentity.allCases.map(\.rawValue))
        let preservedTags = contact.tags.filter { !knownTags.contains($0) }
        contact.givenName = givenName.trimmed
        contact.familyName = familyName.trimmed
        contact.phoneNumber = phoneNumber.trimmed.nilIfEmpty
        contact.emailAddress = emailAddress.trimmed.nilIfEmpty
        contact.companyName = companyName.trimmed.nilIfEmpty
        contact.jobTitle = jobTitle.trimmed.nilIfEmpty
        contact.priority = priority
        contact.relationshipDomain = .business
        contact.businessRole = businessRole
        contact.desiredCadenceDays = desiredCadenceDays
        contact.relationshipContext = relationshipContext.trimmed.nilIfEmpty
        contact.isInEchoLayer = isInEchoLayer
        contact.tags = preservedTags + selectedIdentities.map(\.rawValue).sorted()
        for platform in SocialPlatform.allCases {
            let value = socialIdentifiers[platform]?.trimmed.nilIfEmpty
            contact.setSocialIdentifier(value, for: platform)
        }
        try? modelContext.save()
        dismiss()
    }

    private func toggleVoiceContext() {
        if speech.isRecording {
            speech.stop()
            return
        }
        voiceTextBeforeRecording = relationshipContext
        Task { await speech.start() }
    }

    private func socialBinding(for platform: SocialPlatform) -> Binding<String> {
        Binding(
            get: { socialIdentifiers[platform] ?? "" },
            set: { socialIdentifiers[platform] = $0 }
        )
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
