import SwiftData
import SwiftUI

struct InteractionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let contact: EchoContact
    private let existingInteraction: Interaction?

    @State private var type: InteractionType
    @State private var direction: InteractionDirection
    @State private var date: Date
    @State private var summary: String

    init(contact: EchoContact, interaction: Interaction? = nil) {
        self.contact = contact
        existingInteraction = interaction
        _type = State(initialValue: interaction?.type ?? .messaged)
        _direction = State(initialValue: interaction?.direction ?? .outbound)
        _date = State(initialValue: interaction?.date ?? .now)
        _summary = State(initialValue: interaction?.summary ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("联系方式") {
                    Picker("方式", selection: $type) {
                        ForEach(InteractionType.allCases) { value in
                            Label(value.title, systemImage: value.symbol).tag(value)
                        }
                    }
                    Picker("方向", selection: $direction) {
                        ForEach(InteractionDirection.allCases) { value in
                            Text(directionTitle(value)).tag(value)
                        }
                    }
                    DatePicker("时间", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("联系内容") {
                    TextEditor(text: $summary)
                        .frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("记录讨论重点、客户反馈或下一步行动…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section {
                    Button(existingInteraction == nil ? "保存联系记录" : "保存修改") {
                        save()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
            }
            .navigationTitle(existingInteraction == nil ? "新增联系记录" : "编辑联系记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let cleanedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingInteraction {
            existingInteraction.type = type
            existingInteraction.direction = direction
            existingInteraction.isIncoming = direction == .inbound
            existingInteraction.date = date
            existingInteraction.summary = cleanedSummary
        } else {
            let interaction = Interaction(
                date: date,
                type: type,
                summary: cleanedSummary,
                contact: contact,
                isIncoming: direction == .inbound,
                direction: direction
            )
            contact.interactions.append(interaction)
        }

        EchoEngine.synchronizeActivity(for: contact)
        try? modelContext.save()
        dismiss()
    }

    private func directionTitle(_ value: InteractionDirection) -> String {
        switch value {
        case .inbound: "客户联系我"
        case .outbound: "我联系客户"
        case .internalDirection: "内部记录"
        }
    }
}
