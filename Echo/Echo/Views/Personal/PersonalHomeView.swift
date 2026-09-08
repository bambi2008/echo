import SwiftData
import SwiftUI

/// Commercial dashboard shown as the first tab. The file name is retained to
/// avoid changing the existing Xcode project group.
struct BusinessHomeView: View {
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @Query(sort: \Deal.createdAt, order: .reverse) private var deals: [Deal]
    @State private var showingBusinessCard = false
    @State private var showingManualContact = false

    private var businessContacts: [EchoContact] {
        contacts.filter { $0.isInEchoLayer && $0.hasRealName }
    }

    private var dueDeals: [Deal] {
        let horizon = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return deals
            .filter { $0.status == .active && ($0.nextActionDate ?? .distantFuture) <= horizon }
            .sorted { ($0.nextActionDate ?? .distantFuture) < ($1.nextActionDate ?? .distantFuture) }
    }

    private var openDeals: [Deal] { deals.filter { $0.status == .active } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    welcomeHeader
                    if businessContacts.isEmpty && openDeals.isEmpty {
                        emptyWorkspaceCard
                    } else {
                        followUpCard
                        metricsGrid
                    }
                    quickActions
                    if !businessContacts.isEmpty { roleSummary }
                }
                .padding()
            }
            .navigationTitle("Echo")
            .sheet(isPresented: $showingBusinessCard) {
                NavigationStack {
                    DocumentRecognitionView(kind: .businessCard)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingBusinessCard = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingManualContact) {
                ManualRelationshipContactView { _ in }
            }
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Business workspace", systemImage: "briefcase.fill")
                .font(.headline)
                .foregroundStyle(.indigo)
            Text("Keep every important commercial conversation moving.")
                .font(.title.bold())
            Text("Echo surfaces the next useful action across your contacts and pipeline.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
    }

    private var emptyWorkspaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your workspace is empty", systemImage: "tray")
                .font(.headline)
            Text("Add a business card, partner, prospect, or client to start your follow-up system.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Scan business card") { showingBusinessCard = true }
                    .buttonStyle(.borderedProminent)
                Button("Add contact") { showingManualContact = true }
                    .buttonStyle(.bordered)
            }
        }
        .dashboardCard()
    }

    private var followUpCard: some View {
        NavigationLink {
            PipelineView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label("Next actions", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Text(dueDeals.isEmpty ? "No follow-ups due this week" : "\(dueDeals.count) follow-up\(dueDeals.count == 1 ? "" : "s") due soon")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                if let first = dueDeals.first {
                    Text(first.title)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let date = first.nextActionDate {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Open Pipeline to add an opportunity and set its next action.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .dashboardCard()
        }
        .buttonStyle(.plain)
    }

    private var metricsGrid: some View {
        HStack(spacing: 12) {
            metric("Contacts", value: businessContacts.count, symbol: "person.2.fill")
            metric("Open opportunities", value: openDeals.count, symbol: "chart.line.uptrend.xyaxis")
        }
    }

    private func metric(_ title: String, value: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.indigo)
            Text("\(value)").font(.title.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick actions").font(.headline)
            HStack(spacing: 10) {
                quickAction("Business card", symbol: "person.crop.rectangle") { showingBusinessCard = true }
                quickAction("Add contact", symbol: "person.badge.plus") { showingManualContact = true }
                NavigationLink { PipelineView() } label: {
                    quickActionLabel("Pipeline", symbol: "rectangle.3.group.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { quickActionLabel(title, symbol: symbol) }
            .buttonStyle(.plain)
    }

    private func quickActionLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.indigo)
            Text(title).font(.caption).foregroundStyle(.primary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var roleSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Business network").font(.headline)
            ForEach(BusinessContactRole.allCases) { role in
                let count = businessContacts.filter { $0.businessRole == role }.count
                if count > 0 {
                    HStack {
                        Label(role.title, systemImage: role.symbol)
                        Spacer()
                        Text("\(count)").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .dashboardCard()
    }
}

private extension View {
    func dashboardCard() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}
