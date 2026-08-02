import SwiftUI
import SwiftData

struct EchoLayerView: View {
    @Query(filter: #Predicate<EchoContact> { $0.isInEchoLayer }, sort: [SortDescriptor(\EchoContact.lastReachedOut, order: .reverse)])
    private var contacts: [EchoContact]
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showAIChat = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Echo Layer").tag(0)
                    Text("AI 洞察").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                if selectedTab == 0 { echoLayerTab } else { aiInsightsTab }
            }
            .background(EchoTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Echo")
            .searchable(text: $searchText, prompt: "搜索联系人、笔记...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { EchoHaptics.light(); showAIChat = true } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(EchoTheme.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showAIChat) { AIChatView() }
        }
    }

    private var echoLayerTab: some View {
        ScrollView {
            if filteredContacts.isEmpty {
                emptyState
            } else {
                let urgentCount = filteredContacts.filter { AIEngine.smartReminder(for: $0)?.priority == .urgent }.count
                if urgentCount > 0 {
                    UrgentBanner(count: urgentCount).padding(.horizontal, 16).padding(.top, 8)
                }
                LazyVStack(spacing: 12) {
                    ForEach(EchoEngine.sortedEchoLayer(from: filteredContacts)) { contact in
                        NavigationLink { ContactDetailView(contact: contact) } label: { AIContactCard(contact: contact) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
            }
        }
    }

    private var aiInsightsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                NavigationLink { AIWeeklyReportView() } label: { WeeklySummaryCard() }.buttonStyle(.plain)
                SmartRemindersSection(contacts: contacts)
                HealthDistributionCard(contacts: contacts)
                BatchSuggestionsSection(contacts: contacts)
                GoalsSection(contacts: contacts)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash").font(.system(size: 48)).foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "还没有联系人在 Echo Layer" : "没有找到匹配的联系人").font(EchoTheme.sectionFont).foregroundStyle(.secondary)
        }.padding(.top, 80)
    }

    private var filteredContacts: [EchoContact] {
        if searchText.isEmpty { return contacts }
        return AIEngine.smartSearch(query: searchText, in: contacts).map { $0.0 }
    }
}