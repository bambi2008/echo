import SwiftUI
import SwiftData

struct PeopleLibraryView: View {
    @Query private var contacts: [EchoContact]
    @State private var searchText = ""
    
    private var sortedContacts: [EchoContact] {
        contacts.sorted { $0.givenName.localizedCompare($1.givenName) == .orderedAscending }
    }
    @Environment(\.modelContext) private var modelContext
    private var filteredContacts: [EchoContact] {
        if searchText.isEmpty { return sortedContacts }
        return sortedContacts.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) || ($0.companyName ?? "").localizedCaseInsensitiveContains(searchText) }
    }
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                if contacts.isEmpty { emptyState } else {
                    List(filteredContacts, id: \.systemIdentifier) { contact in
                        NavigationLink { ContactDetailView(contact: contact) } label: {
                            HStack(spacing: EchoTheme.spacing12) {
                                if let data = contact.thumbnailData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill().frame(width: 36, height: 36).clipShape(Circle()) }
                                else { Circle().fill(EchoTheme.accent.opacity(0.1)).frame(width: 36, height: 36).overlay(Text(contact.givenName.prefix(1).uppercased()).font(.caption.weight(.medium)).foregroundStyle(EchoTheme.accent)) }
                                Text(contact.fullName).font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.textPrimary)
                                Spacer()
                                if contact.isInEchoLayer { Image(systemName: "person.3.sequence.fill").font(.system(size: 11)).foregroundStyle(EchoTheme.accent) }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if contact.isInEchoLayer { Button { EchoHaptics.selection(); demote(contact) } label: { Label("Demote", systemImage: "tray.and.arrow.down") }.tint(.gray) }
                            else { Button { EchoHaptics.selection(); promote(contact) } label: { Label("Promote", systemImage: "tray.and.arrow.up") }.tint(EchoTheme.accent) }
                        }.listRowBackground(Color.clear).listRowSeparator(.visible)
                    }.listStyle(.plain).scrollContentBackground(.hidden).searchable(text: $searchText, prompt: "Search contacts")
                }
            }.navigationTitle("All People").navigationBarTitleDisplayMode(.large)
        }
    }
    private func promote(_ contact: EchoContact) { contact.isInEchoLayer = true; try? modelContext.save() }
    private func demote(_ contact: EchoContact) { contact.isInEchoLayer = false; try? modelContext.save() }
    private var emptyState: some View { VStack(spacing: EchoTheme.spacing16) { Image(systemName: "person.2.circle").font(.system(size: 36, weight: .light)).foregroundStyle(EchoTheme.textTertiary); Text("No contacts yet").font(.subheadline).foregroundStyle(EchoTheme.textTertiary) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
}
