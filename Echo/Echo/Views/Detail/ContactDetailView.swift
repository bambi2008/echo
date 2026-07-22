import SwiftData
import SwiftUI

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var contact: EchoContact
    @State private var note = ""
    @State private var selectedType: InteractionType = .messaged

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
    }

    private var subtitle: String? {
        [contact.jobTitle, contact.companyName].compactMap { $0 }.joined(separator: " at ").nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
