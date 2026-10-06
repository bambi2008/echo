import SwiftData
import SwiftUI

struct CSVImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let preview: CSVImportPreview
    let onComplete: (ContactImportResult) -> Void
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        CSVSummaryPill(value: preview.newCount, label: "新增", color: .green)
                        CSVSummaryPill(value: preview.updateCount, label: "更新", color: .indigo)
                        CSVSummaryPill(value: preview.unchangedCount, label: "无需变化", color: .secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    Label(preview.fileName, systemImage: "tablecells")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("CSV 导入预览")
                } footer: {
                    Text("Echo 会按邮箱或电话匹配已有联系人。企业信息会保存到公司资料和联系人备注中，不会上传 CSV 文件。")
                }

                Section("客户名单（\(preview.contacts.count)）") {
                    ForEach(preview.contacts) { contact in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: contact.action))
                                    .foregroundStyle(color(for: contact.action))
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(contact.fullName)
                                        .font(.headline)
                                    Text(contact.companyName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(label(for: contact.action))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(color(for: contact.action))
                            }

                            if let email = contact.emailAddress {
                                Label(email, systemImage: "envelope")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let phone = contact.phoneNumber {
                                Label(phone, systemImage: "phone")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !contact.context.isEmpty {
                                Text(contact.context)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(4)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("导入客户名单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        importContacts()
                    } label: {
                        if isImporting { ProgressView() }
                        else { Text(preview.importableCount == 0 ? "完成" : "导入 \(preview.importableCount) 条") }
                    }
                    .disabled(isImporting)
                }
            }
            .alert("CSV 导入", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func importContacts() {
        guard preview.importableCount > 0 else {
            dismiss()
            return
        }
        isImporting = true
        do {
            let result = try CSVImportService().importContacts(preview, into: modelContext)
            onComplete(result)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isImporting = false
        }
    }

    private func icon(for action: CSVContactCandidate.Action) -> String {
        switch action {
        case .add: "person.badge.plus"
        case .update: "arrow.triangle.2.circlepath"
        case .unchanged: "checkmark.circle"
        }
    }

    private func label(for action: CSVContactCandidate.Action) -> String {
        switch action {
        case .add: "新增"
        case .update: "更新"
        case .unchanged: "已存在"
        }
    }

    private func color(for action: CSVContactCandidate.Action) -> Color {
        switch action {
        case .add: .green
        case .update: .indigo
        case .unchanged: .secondary
        }
    }
}

private struct CSVSummaryPill: View {
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
