import SwiftUI
import SwiftData

struct EchoLayerView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }, sort: [SortDescriptor(\.lastReachedOut, order: .reverse)]) private var contacts: [EchoContact]
    @State private var ahaContact: EchoContact?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if contacts.isEmpty {
                    emptyState
                } else {
                    // Urgent reminders
                    let urgent = contacts.filter {
                        if let r = AIEngine.smartReminder(for: $0) { return r.priority == .urgent }
                        return false
                    }
                    if !urgent.isEmpty {
                        Text("需要关注")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(urgent) { contact in
                                    urgentCard(contact)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 32)
                    }

                    // All contacts
                    Text("联系人")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    LazyVStack(spacing: 2) {
                        ForEach(contacts) { contact in
                            contactRow(contact)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .padding(.top, 12)
        }
        .background(Color.black)
    }

    // MARK: - Urgent Card
    private func urgentCard(_ contact: EchoContact) -> some View {
        let gap = daysSince(contact.lastReachedOut)
        return VStack(alignment: .leading, spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(contact.givenName.prefix(1).uppercased())
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.givenName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(gap) 天")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120)
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Contact Row
    private func contactRow(_ contact: EchoContact) -> some View {
        let gap = daysSince(contact.lastReachedOut)
        return NavigationLink {
            ContactDetailView(contact: contact)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(contact.givenName.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    if let last = contact.lastReachedOut {
                        Text("\(gap) 天前")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 120)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.2")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                )
            Text("还没有联系人")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
            Text("从通讯录导入联系人开始使用")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func daysSince(_ date: Date?) -> Int {
        guard let date = date else { return 999 }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}
