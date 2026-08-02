import SwiftUI
import SwiftData
struct ContactDetailView: View {
    let contact: EchoContact
    @Environment(\.modelContext) private var modelContext
    @State private var showReachSheet = false; @State private var showAddNote = false; @State private var showAIComposer = false; @State private var newNoteText = ""; @Query private var allContacts: [EchoContact]
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard; quickActions; AIPanelView(contact: contact)
                if !contact.interactions.isEmpty { interactionHistorySection }
                notesSection
            }.padding(.horizontal, 16).padding(.bottom, 100)
        }.background(EchoTheme.backgroundGradient.ignoresSafeArea()).navigationTitle(contact.fullName).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReachSheet) { ReachSheetView(contact: contact) { try? modelContext.save() }.presentationDetents([.medium]) }
        .sheet(isPresented: $showAIComposer) { SmartMessageComposerView(contact: contact) }
        .alert("添加笔记", isPresented: $showAddNote) { TextField("写点什么...", text: $newNoteText); Button("取消", role: .cancel) { newNoteText = "" }; Button("保存") { let note = Note(content: newNoteText); note.contact = contact; modelContext.insert(note); try? modelContext.save(); newNoteText = "" } }
    }
    private var headerCard: some View {
        VStack(spacing: 16) {
            if let d = contact.thumbnailData, let img = UIImage(data: d) { Image(uiImage: img).resizable().scaledToFill().frame(width: 88, height: 88).clipShape(Circle()) } else { ZStack { Circle().fill(EchoTheme.accentColor.opacity(0.2)).frame(width: 88, height: 88); Text(contact.givenName.prefix(1).uppercased()).font(.system(size: 36, weight: .bold)).foregroundStyle(EchoTheme.accentColor) } }
            VStack(spacing: 4) { Text(contact.fullName).font(.system(size: 22, weight: .bold)); if let co = contact.companyName, let ti = contact.jobTitle { Text("\(ti) · \(co)").font(.system(size: 13)).foregroundStyle(.secondary) } }
            HStack(spacing: 24) { statItem("\(contact.reachCount)", "次联系"); statItem(EchoEngine.gapDescription(for: contact).components(separatedBy: " ").first ?? "—", "上次联系"); statItem("\(contact.notes.count)", "条笔记") }.padding(.horizontal, 16).padding(.vertical, 12).background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
        }.padding(20).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: EchoTheme.cardRadius))
    }
    private func statItem(_ v: String, _ l: String) -> some View { VStack(spacing: 2) { Text(v).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.primary); Text(l).font(.system(size: 11)).foregroundStyle(.secondary) } }
    private var quickActions: some View {
        HStack(spacing: 12) {
            actionButton("phone.fill", "拨打", .green) { if let p = contact.phoneNumber, let u = URL(string: "tel:\(p)") { UIApplication.shared.open(u) } }
            actionButton("message.fill", "消息", .blue) { if let p = contact.phoneNumber, let u = URL(string: "sms:\(p)") { UIApplication.shared.open(u) } }
            actionButton("envelope.fill", "邮件", .orange) { if let e = contact.emailAddress, let u = URL(string: "mailto:\(e)") { UIApplication.shared.open(u) } }
            actionButton("sparkles", "AI写", EchoTheme.accentColor) { showAIComposer = true }
            actionButton("hand.wave.fill", "记录", .purple) { showReachSheet = true }
        }
    }
    private func actionButton(_ icon: String, _ label: String, _ color: Color, _ action: @escaping () -> Void) -> some View { Button(action: action) { VStack(spacing: 6) { Image(systemName: icon).font(.system(size: 20)).foregroundStyle(.white); Text(label).font(.system(size: 11)).foregroundStyle(.white) }.frame(maxWidth: .infinity).padding(.vertical, 14).background(color.gradient).clipShape(RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain) }
    private var interactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) { Text("互动历史").font(.system(size: 16, weight: .bold)); ForEach(contact.interactions.sorted(by: { $0.date > $1.date })) { interaction in HStack(spacing: 12) { Image(systemName: interaction.interactionType.icon).font(.system(size: 16)).foregroundStyle(EchoTheme.accentColor).frame(width: 36, height: 36).background(EchoTheme.accentColor.opacity(0.15)).clipShape(Circle()); VStack(alignment: .leading, spacing: 2) { Text(interaction.interactionType.label).font(.system(size: 15, weight: .medium)); if !interaction.note.isEmpty { Text(interaction.note).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2) } }; Spacer(); Text(interaction.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(.secondary) }.padding(12).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 10)) } }
    }
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("笔记").font(.system(size: 16, weight: .bold)); Spacer(); Button { showAddNote = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(EchoTheme.accentColor) } }
            if contact.notes.isEmpty { Text("还没有笔记。点击 + 添加你的第一条笔记。").font(.system(size: 13)).foregroundStyle(.secondary).padding(.vertical, 20) } else { ForEach(contact.notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in VStack(alignment: .leading, spacing: 4) { Text(note.content).font(.system(size: 14)).foregroundStyle(.primary); Text(note.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(.secondary) }.padding(12).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 10)) } }
        }
    }
}