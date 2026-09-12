import Contacts
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RelationshipsView: View {
    @EnvironmentObject private var kipHandoffRouter: KipHandoffRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @AppStorage("echo.contacts.autoSync") private var autoSyncContacts = false
    @State private var searchText = ""
    @State private var showingPicker = false
    @State private var showingManual = false
    @State private var showingBusinessCard = false
    @State private var showingVCFImporter = false
    @State private var vcfPreview: VCFImportPreview?
    @State private var methodFilter: RelationshipContactMethodFilter = .all
    @State private var message: String?
    @State private var selectedContactIDs = Set<String>()
    @State private var confirmingBulkDelete = false
    @State private var isImportingPhoneContacts = false
    @State private var didAutoSync = false
    @State private var path = NavigationPath()
    @State private var lastRoutedHandoffID: UUID?

    private var visible: [EchoContact] {
        let methodMatches = contacts.filter { $0.isInEchoLayer && methodFilter.includes($0) }
        guard !searchText.isEmpty else { return methodMatches }
        return methodMatches.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
                || $0.emailAddress?.localizedCaseInsensitiveContains(searchText) == true
                || $0.phoneNumber?.localizedCaseInsensitiveContains(searchText) == true
                || $0.companyName?.localizedCaseInsensitiveContains(searchText) == true
                || $0.jobTitle?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var staleContacts: [EchoContact] {
        contacts
            .filter(\.needsEchoInclusionReview)
            .sorted { ($0.daysSinceContact ?? 365) > ($1.daysSinceContact ?? 365) }
    }

    private var isEditing: Bool { editMode?.wrappedValue == .active }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your business contacts")
                            .font(.title2.bold())
                        Text("Keep partners, prospects, clients, and other commercial contacts in one place." )
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    Picker(String(localized: "Contact method"), selection: $methodFilter) {
                        ForEach(RelationshipContactMethodFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if !staleContacts.isEmpty {
                    Section {
                        Text("These contacts have had no recorded activity for 100+ days. Keep them in your workspace or remove them from Echo." )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(staleContacts.prefix(5)) { contact in
                            staleContactRow(contact)
                        }
                        if staleContacts.count > 5 {
                            Text(String(localized: "+\(staleContacts.count - 5) more people need a decision"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Label(String(localized: "Needs a decision · \(staleContacts.count)"), systemImage: "clock.badge.exclamationmark")
                    }
                }
                ForEach(RelationshipMapGroup.allCases) { group in
                    let groupContacts = visible.filter { group.includes($0) }
                    DisclosureGroup {
                        if groupContacts.isEmpty {
                            Text(String(localized: "No one here yet"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(groupContacts) { contact in
                                if isEditing {
                                    Button { toggleSelection(for: contact) } label: {
                                        HStack {
                                            ContactChoiceRow(contact: contact, isSelected: selectedContactIDs.contains(contact.systemIdentifier))
                                            Spacer()
                                            Image(systemName: selectedContactIDs.contains(contact.systemIdentifier) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedContactIDs.contains(contact.systemIdentifier) ? .indigo : .secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button {
                                        if kipHandoffRouter.handoff != nil {
                                            kipHandoffRouter.assign(contact)
                                        }
                                        path.append(contact)
                                    } label: {
                                        ContactChoiceRow(contact: contact, isSelected: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } label: {
                        Label("\(group.title) · \(groupContacts.count)", systemImage: group.symbol)
                            .font(.headline)
                    }
                    .accessibilityIdentifier("relationships.group.\(group.identifier)")
                }
                Section {
                    NavigationLink {
                        PersonRecallView(contacts: visible)
                    } label: {
                            Label("Find a contact by voice or memory", systemImage: "person.fill.questionmark")
                    }
                    NavigationLink {
                        DocumentRecognitionView(kind: .businessCard)
                    } label: {
                        Label(String(localized: "Scan a business card"), systemImage: "person.crop.rectangle")
                    }
                }
            }
            .navigationTitle("Contacts")
            .task {
                guard autoSyncContacts, !didAutoSync else { return }
                didAutoSync = true
                importPhoneContacts()
            }
            .onChange(of: kipHandoffRouter.handoff?.id, initial: true) { _, _ in
                routeKipHandoffIfNeeded()
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(String(localized: "Search all people"), text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .navigationDestination(for: EchoContact.self) { ContactDetailView(contact: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { importPhoneContacts() } label: {
                            if isImportingPhoneContacts {
                                Label(String(localized: "Refreshing iPhone Contacts…"), systemImage: "arrow.triangle.2.circlepath")
                            } else {
                                Label(String(localized: "Refresh iPhone Contacts"), systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(isImportingPhoneContacts)
                        Button { showingPicker = true } label: {
                            Label(String(localized: "Choose from iPhone Contacts"), systemImage: "person.crop.circle.badge.plus")
                        }
                        Button { showingManual = true } label: {
                            Label("Add business contact", systemImage: "square.and.pencil")
                        }
                        Button { showingVCFImporter = true } label: {
                            Label(String(localized: "Import a VCF file"), systemImage: "doc.badge.plus")
                        }
                        Button { showingBusinessCard = true } label: {
                            Label(String(localized: "Scan a business card"), systemImage: "person.crop.rectangle")
                        }
                        if !selectedContactIDs.isEmpty {
                            Divider()
                            Button(role: .destructive) { confirmingBulkDelete = true } label: {
                                Label(String(localized: "Delete selected (\(selectedContactIDs.count))"), systemImage: "trash")
                            }
                        }
                    } label: { Image(systemName: "plus") }
                }
            }
            .confirmationDialog(
                String(localized: "Delete \(selectedContactIDs.count) selected contacts?"),
                isPresented: $confirmingBulkDelete,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete contacts"), role: .destructive) { deleteSelectedContacts() }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "Their notes and interaction history will also be deleted. Linked pipeline items remain."))
            }
            .sheet(isPresented: $showingPicker) {
                SystemContactPicker { selected in
                    showingPicker = false
                    do {
                        let imported = try SelectedContactImportService().importSelected(selected, into: modelContext)
                        imported.forEach { $0.relationshipJourneyIncluded = true }
                        try modelContext.save()
                    } catch { message = String(localized: "The selected contacts could not be added.") }
                } onCancel: { showingPicker = false }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingManual) { ManualRelationshipContactView { _ in } }
            .sheet(isPresented: $showingBusinessCard) {
                NavigationStack {
                    DocumentRecognitionView(kind: .businessCard)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "Done")) { showingBusinessCard = false }
                            }
                        }
                }
            }
            .sheet(item: $vcfPreview) { preview in
                VCFImportPreviewView(preview: preview) { result in
                    message = result.added == 0 && result.updated == 0
                        ? String(localized: "All VCF contacts already exist in Echo.")
                        : String(localized: "Added \(result.added) and updated \(result.updated) VCF contacts.")
                }
            }
            .fileImporter(
                isPresented: $showingVCFImporter,
                allowedContentTypes: [.vCard],
                allowsMultipleSelection: false,
                onCompletion: handleVCFSelection
            )
            .alert(String(localized: "Echo"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(String(localized: "OK")) { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private func routeKipHandoffIfNeeded() {
        guard let handoff = kipHandoffRouter.handoff,
              handoff.id != lastRoutedHandoffID else { return }
        lastRoutedHandoffID = handoff.id
        let matches = KipContactMatcher.matches(person: handoff.person, contacts: contacts)
        guard matches.count == 1, let contact = matches.first else {
            searchText = handoff.person
            message = matches.isEmpty
                ? String(localized: "Echo could not match \(handoff.person). Choose or add the right contact to continue this Kip reminder.")
                : String(localized: "More than one contact matches \(handoff.person). Choose the right person to continue this Kip reminder.")
            return
        }
        kipHandoffRouter.assign(contact)
        path = NavigationPath()
        path.append(contact)
    }

    @ViewBuilder
    private func staleContactRow(_ contact: EchoContact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ContactChoiceRow(contact: contact, isSelected: false)
                Spacer()
                Text("\(contact.daysSinceContact ?? 100)d")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 10) {
                Button(String(localized: "Keep in Echo")) {
                    contact.lastEchoInclusionReviewedAt = .now
                    try? modelContext.save()
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
                Button(String(localized: "Remove")) {
                    contact.isInEchoLayer = false
                    contact.lastEchoInclusionReviewedAt = .now
                    try? modelContext.save()
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleSelection(for contact: EchoContact) {
        if selectedContactIDs.contains(contact.systemIdentifier) {
            selectedContactIDs.remove(contact.systemIdentifier)
        } else {
            selectedContactIDs.insert(contact.systemIdentifier)
        }
    }

    private func deleteSelectedContacts() {
        let selected = contacts.filter { selectedContactIDs.contains($0.systemIdentifier) }
        selected.forEach(modelContext.delete)
        try? modelContext.save()
        selectedContactIDs.removeAll()
        editMode?.wrappedValue = .inactive
    }

    private func importPhoneContacts() {
        guard !isImportingPhoneContacts else { return }
        isImportingPhoneContacts = true
        Task {
            defer { isImportingPhoneContacts = false }
            do {
                let result = try await ContactImportService().importContacts(into: modelContext)
                message = String(localized: "Refreshed iPhone Contacts: added \(result.added), updated \(result.updated).")
            } catch {
                message = String(localized: "iPhone Contacts could not be refreshed. Check Contacts permission in Settings.")
            }
        }
    }

    private func handleVCFSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            vcfPreview = try VCFImportService().preview(
                data: Data(contentsOf: url),
                fileName: url.lastPathComponent,
                in: modelContext
            )
        } catch {
            message = error.localizedDescription
        }
    }
}

private enum RelationshipContactMethodFilter: String, CaseIterable, Identifiable {
    case all, phone, email
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .phone: String(localized: "Phone")
        case .email: String(localized: "Email")
        }
    }
    func includes(_ contact: EchoContact) -> Bool {
        switch self {
        case .all: true
        case .phone: contact.phoneNumber != nil
        case .email: contact.emailAddress != nil
        }
    }
}

private enum RelationshipMapGroup: CaseIterable, Identifiable {
    case prospect, client, partner, supplier, investor, advisor, colleague, referral, other
    var id: String { title }
    var identifier: String {
        switch self {
        case .prospect: "prospect"
        case .client: "client"
        case .partner: "partner"
        case .supplier: "supplier"
        case .investor: "investor"
        case .advisor: "advisor"
        case .colleague: "colleague"
        case .referral: "referral"
        case .other: "other"
        }
    }
    var title: String {
        switch self {
        case .prospect: BusinessContactRole.prospect.title
        case .client: BusinessContactRole.client.title
        case .partner: BusinessContactRole.partner.title
        case .supplier: BusinessContactRole.supplier.title
        case .investor: BusinessContactRole.investor.title
        case .advisor: BusinessContactRole.advisor.title
        case .colleague: BusinessContactRole.colleague.title
        case .referral: BusinessContactRole.referral.title
        case .other: BusinessContactRole.other.title
        }
    }
    var symbol: String {
        switch self {
        case .prospect: BusinessContactRole.prospect.symbol
        case .client: BusinessContactRole.client.symbol
        case .partner: BusinessContactRole.partner.symbol
        case .supplier: BusinessContactRole.supplier.symbol
        case .investor: BusinessContactRole.investor.symbol
        case .advisor: BusinessContactRole.advisor.symbol
        case .colleague: BusinessContactRole.colleague.symbol
        case .referral: BusinessContactRole.referral.symbol
        case .other: BusinessContactRole.other.symbol
        }
    }
    func includes(_ contact: EchoContact) -> Bool {
        switch self {
        case .prospect: contact.businessRole == .prospect
        case .client: contact.businessRole == .client
        case .partner: contact.businessRole == .partner
        case .supplier: contact.businessRole == .supplier
        case .investor: contact.businessRole == .investor
        case .advisor: contact.businessRole == .advisor
        case .colleague: contact.businessRole == .colleague
        case .referral: contact.businessRole == .referral
        case .other: contact.businessRole == .other
        }
    }
}
