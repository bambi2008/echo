import SwiftData
import SwiftUI

struct VCFImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let preview: VCFImportPreview
    let onComplete: (ContactImportResult) -> Void
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var relationships: [UUID: RelationshipDomain]

    init(preview: VCFImportPreview, onComplete: @escaping (ContactImportResult) -> Void) {
        self.preview = preview
        self.onComplete = onComplete
        _relationships = State(initialValue: Dictionary(uniqueKeysWithValues: preview.contacts.map {
            ($0.id, RelationshipDomain.business)
        }))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        SummaryPill(value: preview.newCount, label: "New", color: .green)
                        SummaryPill(value: preview.updateCount, label: "Update", color: .indigo)
                        SummaryPill(value: preview.unchangedCount, label: "Existing", color: .secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    Label(preview.fileName, systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Import preview")
                } footer: {
                    Text("Echo matches contacts by email or phone. Existing information is kept; the VCF only fills missing details.")
                }

                Section("Contacts (\(preview.contacts.count))") {
                    ForEach(preview.contacts) { contact in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: contact.action))
                                .foregroundStyle(color(for: contact.action))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.fullName)
                                    .font(.headline)
                                if let detail = detail(for: contact) {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(label(for: contact.action))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(color(for: contact.action))
                                Label("Business", systemImage: "briefcase.fill")
                                    .font(.caption)
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .navigationTitle("VCF contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        importContacts()
                    } label: {
                        if isImporting { ProgressView() }
                        else { Text(importableCount == 0 ? "Done" : "Import \(importableCount)") }
                    }
                    .disabled(isImporting)
                }
            }
            .alert("VCF import", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func importContacts() {
        guard importableCount > 0 else {
            dismiss()
            return
        }
        isImporting = true
        do {
            let result = try VCFImportService().importContacts(
                preview,
                relationshipOverrides: relationships,
                into: modelContext
            )
            onComplete(result)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isImporting = false
        }
    }

    private var importableCount: Int {
        preview.contacts.filter { contact in
            contact.action != .unchanged || relationships[contact.id] != contact.relationshipDomain
        }.count
    }

    private func relationshipBinding(for contact: VCFContactCandidate) -> Binding<RelationshipDomain> {
        Binding(
            get: { relationships[contact.id] ?? contact.relationshipDomain },
            set: { relationships[contact.id] = $0 }
        )
    }

    private func detail(for contact: VCFContactCandidate) -> String? {
        [contact.phoneNumber, contact.emailAddress, contact.companyName]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty
    }

    private func icon(for action: VCFContactCandidate.Action) -> String {
        switch action {
        case .add: "person.badge.plus"
        case .update: "arrow.triangle.2.circlepath"
        case .unchanged: "checkmark.circle"
        }
    }

    private func label(for action: VCFContactCandidate.Action) -> String {
        switch action {
        case .add: String(localized: "New")
        case .update: String(localized: "Update")
        case .unchanged: String(localized: "Exists")
        }
    }

    private func color(for action: VCFContactCandidate.Action) -> Color {
        switch action {
        case .add: .green
        case .update: .indigo
        case .unchanged: .secondary
        }
    }
}

private struct SummaryPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
