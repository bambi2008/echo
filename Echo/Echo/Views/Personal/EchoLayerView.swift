import SwiftUI
import SwiftData

struct EchoLayerView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }, sort: [SortDescriptor(\.lastReachedOut, order: .reverse)]) private var contacts: [EchoContact]
    @State private var selectedTab = 0
    @State private var ahaContact: EchoContact?
    @State private var pullDistance: CGFloat = 0
    @State private var aiSuggestion: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Echo Layer").tag(0)
                Text("AI 洞察").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if selectedTab == 0 {
                echoLayerTab
            } else {
                aiInsightsTab
            }
        }
        .background(EchoTheme.bgPrimary)
    }

    private var echoLayerTab: some View {
        ScrollView {
            PullReachHint(pullDistance: pullDistance, suggestion: aiSuggestion).padding(.top, 8)
            if !filteredContacts.isEmpty { 
                SmartContextCards(contacts: filteredContacts, onReach: { c in ahaContact = c }, onCompose: { c in ahaContact = c })
                    .padding(.horizontal, 16).padding(.top, 8)
            }
            if filteredContacts.isEmpty { emptyState } else {
                let urgentCount = filteredContacts.filter { AIEngine.smartReminder(for: $0)?.priority == .urgent }.count
                if urgentCount > 0 {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text("\(urgentCount) 位联系人超过30天未联系").font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(12).background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16).padding(.top, 8)
                }
                LazyVStack(spacing: 12) {
                    ForEach(EchoEngine.sortedEchoLayer(from: filteredContacts)) { contact in
                        NavigationLink {
                            ContactDetailView(contact: contact)
                        } label: {
                            AIContactCard(contact: contact)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 100)
            }
        }
    }

    private var aiInsightsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                RelationshipWeatherView(contacts: contacts)
                StreakCalendarView(interactions: contacts.flatMap { $0.interactions })
                WeeklySummaryCard()
                SmartRemindersSection(contacts: contacts)
                HealthDistributionCard(contacts: contacts)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 100)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("还没有联系人在 Echo Layer").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
        }
        .padding(.top, 80)
    }

    private var filteredContacts: [EchoContact] {
        contacts
    }
}
