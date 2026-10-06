import SwiftData
import SwiftUI
import UIKit

/// A reviewed, BCC-based email composer for a selected set of business
/// contacts. Echo never sends the message itself; it hands the draft to Gmail
/// (or Gmail web) after the user taps the final button.
struct BulkEmailComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext

    let contacts: [EchoContact]

    @State private var subject = "商务跟进"
    @State private var messageBody = "您好，想和您跟进一下我们之前讨论的事项。方便时请告诉我接下来的安排。"
    @State private var errorMessage: String?

    private var recipients: [String] {
        contacts.compactMap(\.emailAddress)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var bodyView: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundStyle(.indigo)
                    Text("群发邮件")
                        .font(.headline)
                    Spacer()
                    Text("密送 \(recipients.count) 人")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Echo 会使用密送（BCC），客户看不到彼此的邮箱地址。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("收件人") {
                ForEach(contacts.filter { contact in
                    guard let email = contact.emailAddress?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                        return false
                    }
                    return recipients.contains(email)
                }) { contact in
                    HStack(spacing: 10) {
                        Text(contact.initials)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.indigo)
                            .frame(width: 28, height: 28)
                            .background(Color.indigo.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.fullName)
                                .font(.subheadline.weight(.semibold))
                            Text(contact.emailAddress ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("邮件内容") {
                TextField("主题", text: $subject)
                TextEditor(text: $messageBody)
                    .frame(minHeight: 180)
            }

            Section {
                Button {
                    launch()
                } label: {
                    Label("在 Gmail 中撰写", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(recipients.isEmpty || subject.trimmed.isEmpty || messageBody.trimmed.isEmpty)
            } footer: {
                Text("打开 Gmail 后请检查收件人和内容，再由你手动发送。")
                    .font(.caption)
            }
        }
        .navigationTitle("群发邮件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .alert("无法打开 Gmail", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            bodyView
        }
    }

    private func launch() {
        guard let appURL = GmailComposeService.bulkAppURL(
            recipients: recipients,
            subject: subject,
            body: messageBody
        ) else {
            errorMessage = "没有可用的客户邮箱。"
            return
        }

        let recipientsToLog = contacts.filter { contact in
            guard let email = contact.emailAddress?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            return recipients.contains(email)
        }

        let summary = "发起群发邮件：\(subject.trimmed)"
        recipientsToLog.forEach { contact in
            let interaction = Interaction(
                type: .emailed,
                summary: summary,
                contact: contact,
                source: "gmail",
                isIncoming: false,
                direction: .outbound
            )
            contact.interactions.append(interaction)
            EchoEngine.synchronizeActivity(for: contact)
        }
        try? modelContext.save()

        if UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else if let webURL = GmailComposeService.bulkWebURL(
            recipients: recipients,
            subject: subject,
            body: messageBody
        ) {
            openURL(webURL)
        } else {
            errorMessage = "Echo 无法打开 Gmail，请确认已安装 Gmail 或检查网络。"
            return
        }
        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
