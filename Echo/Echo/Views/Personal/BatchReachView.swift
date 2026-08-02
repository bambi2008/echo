import SwiftUI
import SwiftData

struct BatchReachView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }) var contacts: [EchoContact]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContacts: Set<String> = []
    @State private var selectedChannel: InteractionType = .messaged
    @State private var openingLines: [String: [AIOpeningLine]] = [:]
    @State private var isGenerating = false
    @State private var generated = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                channelSelector.padding(.horizontal, 16).padding(.top, 12)
                if !generated { aiGroupSuggestions }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(contacts.sorted { ($0.lastReachedOut ?? .distantPast) < ($1.lastReachedOut ?? .distantPast) }) { c in contactRow(c) }
                    }.padding(.horizontal, 16).padding(.top, 12)
                }
                if generated {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            let ids = Array(selectedContacts)
                            ForEach(0..<ids.count) { i in
                                if let c = contacts.first(where: { $0.systemIdentifier == ids[i] }), let lines = openingLines[ids[i]] {
                                    OpeningLineCard(contact: c, lines: lines, channel: selectedChannel)
                                }
                            }
                        }.padding(.horizontal, 16).padding(.top, 12)
                    }
                }
                bottomBar
            }
            .background(EchoTheme.darkBackground).navigationTitle("批量联系").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
    private var channelSelector: some View {
        let types = InteractionType.allCases.filter { $0 != .reachedOut }
        return HStack(spacing: 8) {
            ForEach(0..<types.count) { i in
                Button { selectedChannel = types[i]; generated = false } label: {
                    HStack(spacing: 6) { Image(systemName: types[i].icon).font(.system(size: 13)); Text(types[i].label).font(.system(size: 13, weight: .medium)) }
                    .foregroundStyle(selectedChannel == types[i] ? .white : .primary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(selectedChannel == types[i] ? AnyShapeStyle(EchoTheme.gradient) : AnyShapeStyle(EchoTheme.cardBackground)).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
        }
    }
    private var aiGroupSuggestions: some View {
        let groups = AIEngine.batchSuggestions(contacts: contacts)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(groups) { group in
                    Button { selectedContacts = Set(group.contacts.map { $0.systemIdentifier }); withAnimation(.spring(response: 0.4)) { generated = false } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: group.icon).font(.system(size: 12)).foregroundStyle(EchoTheme.accentColor)
                            VStack(alignment: .leading, spacing: 2) { Text(group.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary); Text(String(group.contacts.count) + "人 - " + group.subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }
                        }.padding(.horizontal, 14).padding(.vertical, 10).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(EchoTheme.accentColor.opacity(0.2), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 16).padding(.top, 12)
        }
    }
    private func contactRow(_ c: EchoContact) -> some View {
        let isSelected = selectedContacts.contains(c.systemIdentifier)
        let h = AIEngine.healthScore(for: c)
        return Button { if isSelected { selectedContacts.remove(c.systemIdentifier) } else { selectedContacts.insert(c.systemIdentifier) }; generated = false } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(isSelected ? AnyShapeStyle(EchoTheme.gradient) : AnyShapeStyle(.secondary))
                Circle().fill(EchoTheme.accentColor.opacity(0.2)).frame(width: 36, height: 36).overlay(Text(c.givenName.prefix(1)).font(.system(size: 14, weight: .bold)).foregroundStyle(EchoTheme.accentColor))
                VStack(alignment: .leading, spacing: 2) { Text(c.fullName).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary); Text(EchoEngine.gapDescription(for: c)).font(.system(size: 12)).foregroundStyle(.secondary) }
                Spacer()
                Text("\(h.score)").font(.system(size: 12, weight: .bold))
            }.padding(.horizontal, 14).padding(.vertical, 10).background(isSelected ? EchoTheme.accentColor.opacity(0.08) : EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? EchoTheme.accentColor.opacity(0.3) : .clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if isGenerating { HStack(spacing: 8) { ProgressView().tint(EchoTheme.accentColor); Text("AI 正在生成个性化开场白...").font(.system(size: 13)).foregroundStyle(.secondary) } }
            else if !generated {
                Button { generateLines() } label: { Text("AI 生成 " + String(selectedContacts.count) + " 人的开场白").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(selectedContacts.isEmpty ? AnyShapeStyle(.gray.opacity(0.3)) : AnyShapeStyle(EchoTheme.gradient)).clipShape(RoundedRectangle(cornerRadius: 16)) }.disabled(selectedContacts.isEmpty).buttonStyle(.plain)
            } else {
                Button { for id in selectedContacts { if let c = contacts.first(where: { $0.systemIdentifier == id }) { EchoEngine.recordReach(on: c, type: selectedChannel, note: "", context: modelContext) } }; dismiss() } label: { Text("全部标记为已联系").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(EchoTheme.gradient).clipShape(RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 16).padding(.vertical, 12).background(.ultraThinMaterial)
    }
    private func generateLines() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [String: [AIOpeningLine]] = [:]
            for id in selectedContacts { if let c = contacts.first(where: { $0.systemIdentifier == id }) { results[id] = AIEngine.generateOpeningLines(for: c, channel: selectedChannel) } }
            DispatchQueue.main.async { openingLines = results; isGenerating = false; withAnimation(.spring(response: 0.5)) { generated = true } }
        }
    }
}

struct OpeningLineCard: View {
    let contact: EchoContact; let lines: [AIOpeningLine]; let channel: InteractionType
    @State private var copiedIndex: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(EchoTheme.accentColor.opacity(0.2)).frame(width: 32, height: 32).overlay(Text(contact.givenName.prefix(1)).font(.system(size: 13, weight: .bold)).foregroundStyle(EchoTheme.accentColor))
                VStack(alignment: .leading, spacing: 2) { Text(contact.givenName).font(.system(size: 15, weight: .semibold)); Text(EchoEngine.gapDescription(for: contact)).font(.system(size: 11)).foregroundStyle(.secondary) }
                Spacer()
                Image(systemName: channel.icon).font(.system(size: 14)).foregroundStyle(EchoTheme.accentColor)
            }
            Divider()
            ForEach(0..<lines.count) { i in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) { Text(lines[i].text).font(.system(size: 14)).foregroundStyle(.primary); Spacer(); Button { UIPasteboard.general.string = lines[i].text; withAnimation { copiedIndex = i }; DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { copiedIndex = nil } } } label: { Image(systemName: copiedIndex == i ? "checkmark" : "doc.on.doc").font(.system(size: 13)).foregroundStyle(copiedIndex == i ? .green : .secondary) }.buttonStyle(.plain) }
                    Text(lines[i].context).font(.system(size: 11)).foregroundStyle(.secondary)
                }.padding(.vertical, 6)
            }
        }.padding(14).background(EchoTheme.cardBackground).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(EchoTheme.accentColor.opacity(0.15), lineWidth: 1))
    }
}