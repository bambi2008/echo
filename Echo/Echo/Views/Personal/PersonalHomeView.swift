import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PersonalHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @State private var showingNewContact = false
    @State private var showingBusinessCard = false
    @State private var showingVCFImporter = false
    @State private var vcfPreview: VCFImportPreview?
    @State private var importMessage: String?
    @State private var isImporting = false
    @State private var searchText = ""
    @State private var peopleFilter: PeopleFilter = .all
    @State private var contactMethodFilter: ContactMethodFilter = .all

    private var prioritized: [EchoContact] {
        contacts.filter {
            $0.isInEchoLayer && peopleFilter.includes($0) && contactMethodFilter.includes($0)
        }.sorted {
            EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1)
        }
    }

    private var visibleContacts: [EchoContact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return prioritized }
        return prioritized.filter { contact in
            let social = SocialPlatform.allCases.compactMap { platform in
                contact.socialIdentifier(for: platform)
            }
            let profile = [contact.fullName, contact.emailAddress, contact.phoneNumber, contact.companyName, contact.jobTitle]
                .compactMap { $0 }
            return (profile + social)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var todaysEchoContact: EchoContact? {
        prioritized.first(where: \.isEligibleForTodaysEcho)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Contact method", selection: $contactMethodFilter) {
                        ForEach(ContactMethodFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.symbol).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Contact method filter")

                    Picker("People", selection: $peopleFilter) {
                        ForEach(PeopleFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Relationship filter")
                }

                Section {
                    NavigationLink {
                        PersonRecallView(contacts: contacts)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.fill.questionmark")
                                .font(.title2)
                                .foregroundStyle(.indigo)
                                .frame(width: 40, height: 40)
                                .background(Color.indigo.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Can't remember their name?")
                                    .font(.headline)
                                Text("Describe what you remember and let Echo find them.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Today's echo", systemImage: "wave.3.right")
                            .font(.headline)
                            .foregroundStyle(.indigo)
                        Text(todaysEchoContact.map { "It may be a good day to reach out to \($0.fullName)." } ?? "Add a name and relationship details to get a meaningful suggestion.")
                            .font(.title3.weight(.semibold))
                        Text("Small moments keep important relationships alive.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section(contactSectionTitle) {
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
                    Menu {
                        Button(action: importGoogleContacts) {
                            Label("Google contacts", systemImage: "person.2.badge.plus")
                        }
                        Button(action: importIPhoneContacts) {
                            Label("iPhone contacts", systemImage: "iphone")
                        }
                        Button {
                            showingVCFImporter = true
                        } label: {
                            Label("VCF file", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        if isImporting { ProgressView() }
                        else { Image(systemName: "person.crop.circle.badge.plus") }
                    }
                    .disabled(isImporting)
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
            .sheet(item: $vcfPreview) { preview in
                VCFImportPreviewView(preview: preview) { result in
                    importMessage = result.added == 0 && result.updated == 0
                        ? "All VCF contacts already exist in Echo."
                        : "Added \(result.added) and updated \(result.updated) VCF contacts."
                }
            }
            .fileImporter(
                isPresented: $showingVCFImporter,
                allowedContentTypes: [.vCard],
                allowsMultipleSelection: false
            ) { result in
                handleVCFSelection(result)
            }
            .alert("Contact import", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) { Button("OK") { importMessage = nil } } message: { Text(importMessage ?? "") }
        }
    }

    private var contactSectionTitle: String {
        if contactMethodFilter == .all { return peopleFilter.sectionTitle }
        return "\(contactMethodFilter.title) contacts"
    }

    private func handleVCFSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            vcfPreview = try VCFImportService().preview(
                data: data,
                fileName: url.lastPathComponent,
                in: modelContext
            )
        } catch {
            importMessage = error.localizedDescription
        }
    }

    private func importIPhoneContacts() {
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                let result = try await ContactImportService().importContacts(into: modelContext)
                importMessage = result.added == 0 && result.updated == 0
                    ? "Your iPhone contacts are already up to date."
                    : "Added \(result.added) and updated \(result.updated) iPhone contacts."
            } catch {
                importMessage = "iPhone contacts could not be imported."
            }
        }
    }

    private func importGoogleContacts() {
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                if GmailSyncService.shared.status()?.canImportContacts != true {
                    _ = try await GmailSyncService.shared.connect()
                }
                let result = try await GmailSyncService.shared.importGoogleContacts(in: modelContext)
                if result.savedContactsFound == 0 && result.otherContactsFound == 0 {
                    importMessage = "Google returned no saved or Other contacts for this account. You can switch accounts in Settings."
                } else if result.added == 0 && result.updated == 0 {
                    importMessage = "Found \(result.savedContactsFound) saved and \(result.otherContactsFound) Other contacts; Echo is already up to date."
                } else {
                    importMessage = "Added \(result.added) and updated \(result.updated) Google contacts."
                }
            } catch {
                importMessage = error.localizedDescription
            }
        }
    }
}

private enum ContactMethodFilter: String, CaseIterable, Identifiable {
    case all
    case phone
    case email

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .phone: "Phone"
        case .email: "Email"
        }
    }

    var symbol: String {
        switch self {
        case .all: "person.2"
        case .phone: "phone"
        case .email: "envelope"
        }
    }

    func includes(_ contact: EchoContact) -> Bool {
        switch self {
        case .all: true
        case .phone: contact.phoneNumber?.trimmed.nilIfEmpty != nil
        case .email: contact.emailAddress?.trimmed.nilIfEmpty != nil
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
            Image(systemName: contact.relationshipDomain.symbol)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityLabel(contact.relationshipDomain.title)
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
    @State private var relationshipDomain: RelationshipDomain = .personal
    @State private var identity: ContactIdentity?
    @State private var socialIdentifiers: [SocialPlatform: String] = [:]

    private var availableIdentities: [ContactIdentity] {
        ContactIdentity.allCases.filter { relationshipDomain.includes($0.domain) }
    }

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
                Section {
                    ForEach(SocialPlatform.allCases) { platform in
                        LabeledContent {
                            TextField(platform.fieldPrompt, text: socialBinding(for: platform))
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } label: {
                            Label(platform.title, systemImage: platform.symbol)
                        }
                    }
                } header: {
                    Text("Social accounts")
                }
                Picker("Relationship", selection: $relationshipDomain) {
                    ForEach(RelationshipDomain.allCases) { domain in
                        Label(domain.title, systemImage: domain.symbol).tag(domain)
                    }
                }
                Picker("Priority", selection: $priority) {
                    Text("Not set").tag(PriorityLevel?.none)
                    ForEach(PriorityLevel.allCases) { level in
                        Text(level.title).tag(Optional(level))
                    }
                }
                Picker("Identity", selection: $identity) {
                    Text("Not set").tag(ContactIdentity?.none)
                    ForEach(availableIdentities) { item in
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
                            relationshipDomain: relationshipDomain,
                            companyName: companyName.trimmed.nilIfEmpty,
                            jobTitle: jobTitle.trimmed.nilIfEmpty
                        )
                        contact.tags = identity.map { [$0.rawValue] } ?? []
                        for platform in SocialPlatform.allCases {
                            contact.setSocialIdentifier(
                                socialIdentifiers[platform]?.trimmed.nilIfEmpty,
                                for: platform
                            )
                        }
                        modelContext.insert(contact)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(givenName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: relationshipDomain) { _, newValue in
                if let identity, !newValue.includes(identity.domain) {
                    self.identity = nil
                }
            }
        }
    }

    private func socialBinding(for platform: SocialPlatform) -> Binding<String> {
        Binding(
            get: { socialIdentifiers[platform] ?? "" },
            set: { socialIdentifiers[platform] = $0 }
        )
    }
}

private enum PeopleFilter: String, CaseIterable, Identifiable {
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

    var sectionTitle: String {
        switch self {
        case .all: "Your people"
        case .personal: "Personal relationships"
        case .business: "Business relationships"
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

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
