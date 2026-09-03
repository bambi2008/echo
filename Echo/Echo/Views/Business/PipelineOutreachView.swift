import SwiftData
import SwiftUI

struct PipelineOutreachView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: Deal
    @State private var subject: String
    @State private var emailBody: String
    @State private var model: String?
    @State private var gmailStatus: GmailConnectionStatus?
    @State private var isGenerating = false
    @State private var isSending = false
    @State private var confirmingSend = false
    @State private var sent = false
    @State private var statusMessage: String?

    init(item: Deal) {
        self.item = item
        let givenName = item.contact?.givenName ?? ""
        let name = givenName.isEmpty ? "there" : givenName
        _subject = State(initialValue: "Following up on \(item.title)")
        _emailBody = State(initialValue: "Hi \(name),\n\nI wanted to follow up about \(item.title). Would you be open to a short conversation?\n\nBest,")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient") {
                    LabeledContent(item.contact?.fullName ?? "No primary contact", value: recipient)
                    if let gmailStatus {
                        LabeledContent("Send from", value: gmailStatus.email)
                        Label(gmailStatus.canSendEmail ? "Gmail sending ready" : "Reconnect Google to approve sending", systemImage: gmailStatus.canSendEmail ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(gmailStatus.canSendEmail ? .green : .orange)
                    } else {
                        Label("Google is not connected", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    if gmailStatus?.canSendEmail != true {
                        Button(isSending ? "Connecting…" : "Connect or reconnect Google") { connectGoogle() }
                            .disabled(isSending)
                    }
                }

                Section("Draft") {
                    TextField("Subject", text: $subject)
                    TextEditor(text: $emailBody).frame(minHeight: 180)
                    if let model { Label("Drafted with \(model)", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary) }
                    Button { generate() } label: {
                        if isGenerating { HStack { ProgressView(); Text("Drafting…") } }
                        else { Label("Generate with DeepSeek", systemImage: "sparkles") }
                    }.disabled(isGenerating || isSending)
                }

                Section {
                    Button { confirmingSend = true } label: {
                        if isSending { HStack { ProgressView(); Text("Sending…") }.frame(maxWidth: .infinity) }
                        else if sent { Label("Sent", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity) }
                        else { Label("Review and send with Gmail", systemImage: "paperplane.fill").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(sent ? .green : .indigo)
                    .disabled(!canSend)
                    .accessibilityIdentifier("pipeline.outreach.send")
                } footer: {
                    Text("This sends a real email from the connected Gmail account. Echo records it only after Gmail confirms delivery acceptance.")
                }
            }
            .navigationTitle("Prepare email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(sent ? "Done" : "Cancel") { dismiss() } } }
            .task { gmailStatus = GmailSyncService.shared.status() }
            .confirmationDialog("Send this email now?", isPresented: $confirmingSend) {
                Button("Send with Gmail") { send() }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("To: \(recipient)\nSubject: \(subject)")
            }
            .alert("Pipeline email", isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) {
                Button("OK") { statusMessage = nil }
            } message: { Text(statusMessage ?? "") }
        }
    }

    private var recipient: String { item.contact?.emailAddress ?? "Missing email" }
    private var canSend: Bool {
        !sent && !isSending && !isGenerating && gmailStatus?.canSendEmail == true
            && !recipient.isEmpty && !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !emailBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func connectGoogle() {
        isSending = true
        Task {
            defer { isSending = false }
            do { gmailStatus = try await GmailSyncService.shared.connect() }
            catch { statusMessage = error.localizedDescription }
        }
    }

    private func generate() {
        isGenerating = true
        Task {
            defer { isGenerating = false }
            do {
                let provider = DeepSeekCommunicationProvider(features: try EchoAIEnvironment.features())
                let draft = try await provider.prepareOutreach(for: item)
                subject = draft.subject; emailBody = draft.body; model = draft.model
                try PipelineEmailService().recordPrepared(draft, for: item, in: modelContext)
            } catch { statusMessage = EchoAIEnvironment.message(for: error) }
        }
    }

    private func send() {
        guard canSend else { return }
        isSending = true
        let outreach = PreparedOutreach(subject: subject, body: emailBody, model: model)
        Task {
            defer { isSending = false }
            do {
                _ = try await PipelineEmailService().send(outreach, for: item, using: GmailEmailDeliveryProvider(), in: modelContext)
                sent = true
                statusMessage = "Gmail accepted the message. It is now recorded in the timeline."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}
