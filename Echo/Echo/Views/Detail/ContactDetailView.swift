import SwiftUI
import SwiftData

struct ContactDetailView: View {
    let contact: EchoContact
    @Environment(\.modelContext) private var modelContext
    @State private var showReachSheet = false
    @State private var newNote = ""
    private var interactions: [Interaction] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -FreeTierLimits.maxHistoryDays, to: Date()) ?? Date()
        return contact.interactions.filter { $0.date >= cutoffDate }.sorted { $0.date > $1.date }
    }
    var body: some View {
        ZStack {
            EchoBackground()
            ScrollView {
                VStack(spacing: EchoTheme.spacing24) {
                    headerView.echoAppear()
                    Button { EchoHaptics.light(); showReachSheet = true } label: {
                        HStack(spacing: EchoTheme.spacing8) { Image(systemName: "hand.wave.fill"); Text("Reach Out") }.font(.headline).frame(maxWidth: .infinity).frame(height: 48)
                    }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).padding(.horizontal, EchoTheme.spacing16).echoAppear(delay: 0.05)
                    Button { EchoHaptics.selection(); toggleEchoLayer() } label: {
                        HStack(spacing: 6) { Image(systemName: contact.isInEchoLayer ? "person.3.sequence.fill" : "person.3.sequence"); Text(contact.isInEchoLayer ? "In Echo Layer" : "In Library") }.font(.subheadline.weight(.medium)).foregroundStyle(contact.isInEchoLayer ? EchoTheme.accent : EchoTheme.textTertiary).padding(.horizontal, EchoTheme.spacing16).padding(.vertical, EchoTheme.spacing8).background(contact.isInEchoLayer ? EchoTheme.accent.opacity(0.08) : Color.white.opacity(0.04)).clipShape(Capsule())
                    }.buttonStyle(.plain).echoAppear(delay: 0.1)
                    notesSection.echoAppear(delay: 0.15)
                    timelineSection.echoAppear(delay: 0.2)
                }.padding(.bottom, EchoTheme.spacing32)
            }
        }.navigationTitle(contact.givenName).navigationBarTitleDisplayMode(.inline).sheet(isPresented: $showReachSheet) { ReachSheetView(contact: contact) }
    }
    private var headerView: some View {
        VStack(spacing: EchoTheme.spacing8) {
            if let data = contact.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle()).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else {
                Circle().fill(LinearGradient(colors: [EchoTheme.accentSoft, EchoTheme.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 80, height: 80).overlay(Text(contact.givenName.prefix(1).uppercased()).font(.title.weight(.medium)).foregroundStyle(EchoTheme.accent))
            }
            Text(contact.fullName).font(.title2.bold()).foregroundStyle(EchoTheme.textPrimary)
            if let phone = contact.phoneNumber { Text(phone).font(.caption).foregroundStyle(EchoTheme.textSecondary) }
            if let email = contact.emailAddress { Text(email).font(.caption).foregroundStyle(EchoTheme.textSecondary) }
            Text(EchoEngine.gapDescription(for: contact)).font(.caption.weight(.medium)).foregroundStyle(EchoEngine.isOverdue(contact) ? EchoTheme.overdue : EchoTheme.textTertiary).padding(.horizontal, EchoTheme.spacing12).padding(.vertical, 4).background(EchoEngine.isOverdue(contact) ? EchoTheme.overdue.opacity(0.1) : Color.white.opacity(0.04)).clipShape(Capsule())
        }.padding(.top, EchoTheme.spacing16)
    }
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: EchoTheme.spacing8) {
            Text("Notes").font(.headline).foregroundStyle(EchoTheme.textPrimary)
            HStack {
                TextField("Add a note…", text: $newNote, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...3).tint(EchoTheme.accent)
                Button { EchoHaptics.light(); addNote() } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(newNote.isEmpty ? EchoTheme.textTertiary : EchoTheme.accent) }.disabled(newNote.isEmpty)
            }
            if !contact.notes.isEmpty {
                VStack(spacing: EchoTheme.spacing8) {
                    ForEach(contact.notes.sorted { $0.createdAt > $1.createdAt }, id: \.persistentModelID) { note in
                        HStack(alignment: .top, spacing: EchoTheme.spacing8) { Image(systemName: "note.text").font(.system(size: 12)).foregroundStyle(EchoTheme.textTertiary).frame(width: 20, alignment: .center); Text(note.content).font(.caption).foregroundStyle(EchoTheme.textSecondary); Spacer() }.padding(EchoTheme.spacing12).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius12, style: .continuous))
                    }
                }
                Text("\(contact.notes.count)/\(FreeTierLimits.maxNotesPerContact) notes (Free)").font(.caption2).foregroundStyle(EchoTheme.textTertiary)
            }
        }.padding(.horizontal, EchoTheme.spacing16)
    }
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: EchoTheme.spacing12) {
            HStack { Text("Timeline").font(.headline).foregroundStyle(EchoTheme.textPrimary); Spacer(); Text("Last \(FreeTierLimits.maxHistoryDays) days").font(.caption2).foregroundStyle(EchoTheme.textTertiary) }
            if interactions.isEmpty {
                VStack(spacing: EchoTheme.spacing8) { Image(systemName: "clock.arrow.circlepath").font(.system(size: 28, weight: .light)).foregroundStyle(EchoTheme.textTertiary); Text("No interactions yet.\nReach out to get started!").font(.subheadline).foregroundStyle(EchoTheme.textTertiary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, EchoTheme.spacing24)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(interactions.enumerated()), id: \.element.persistentModelID) { index, interaction in
                        HStack(spacing: EchoTheme.spacing12) {
                            VStack(spacing: 0) { Circle().fill(index == 0 ? EchoTheme.accent : EchoTheme.accent.opacity(0.4)).frame(width: 10, height: 10); if index < interactions.count - 1 { Rectangle().fill(EchoTheme.accent.opacity(0.15)).frame(width: 1.5).frame(maxHeight: .infinity) } }.frame(width: 10)
                            HStack(spacing: EchoTheme.spacing12) { Image(systemName: interaction.interactionType.icon).font(.system(size: 14)).foregroundStyle(EchoTheme.accent).frame(width: 28, height: 28).background(EchoTheme.accent.opacity(0.1)).clipShape(Circle()); VStack(alignment: .leading, spacing: 2) { Text(interaction.interactionType.label).font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.textPrimary); if !interaction.note.isEmpty { Text(interaction.note).font(.caption).foregroundStyle(EchoTheme.textSecondary).lineLimit(2) }; Text(interaction.date.formatted(.relative(presentation: .named))).font(.caption2).foregroundStyle(EchoTheme.textTertiary) }; Spacer() }.padding(.vertical, EchoTheme.spacing8)
                        }
                    }
                }
            }
        }.padding(.horizontal, EchoTheme.spacing16)
    }
    private func toggleEchoLayer() { contact.isInEchoLayer.toggle(); try? modelContext.save() }
    private func addNote() {
        guard !newNote.isEmpty else { return }
        if contact.notes.count >= FreeTierLimits.maxNotesPerContact { if let oldest = contact.notes.min(by: { $0.createdAt < $1.createdAt }) { modelContext.delete(oldest); contact.notes.removeAll { $0.persistentModelID == oldest.persistentModelID } } }
        let note = Note(content: newNote); note.contact = contact; contact.notes.append(note); modelContext.insert(note); try? modelContext.save(); newNote = ""
    }
}
