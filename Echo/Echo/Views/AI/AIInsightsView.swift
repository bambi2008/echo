import SwiftData
import SwiftUI

struct AIInsightsView: View {
    @Query private var contacts: [EchoContact]
    @Query(sort: \ReflectionJourney.startedAt, order: .reverse) private var journeys: [ReflectionJourney]

    private var insights: [LocalRelationshipInsight] {
        RelationshipGuidanceEngine.insights(contacts: activeContacts, journeys: journeys)
    }

    private var activeContacts: [EchoContact] {
        contacts.filter { $0.isInEchoLayer && $0.hasRealName && $0.isBusinessRelationship }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Business signals, not guesses"))
                            .font(.title2.bold())
                        Text(String(localized: "These observations use only the commercial context and activity you recorded in Echo. No API key is needed for local ranking."))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    NavigationLink {
                        RelationshipAnalysisView(mode: .insight, contacts: activeContacts)
                    } label: {
                        Label(String(localized: "Account insight"), systemImage: "person.text.rectangle")
                    }
                    NavigationLink {
                        RelationshipAnalysisView(mode: .health, contacts: activeContacts)
                    } label: {
                        Label(String(localized: "Account health"), systemImage: "chart.bar.xaxis")
                    }
                    NavigationLink {
                        DailyBriefingView(contacts: activeContacts)
                    } label: {
                        Label(String(localized: "Today's business brief"), systemImage: "sun.max.fill")
                    }
                } header: {
                    Text(String(localized: "AI tools"))
                } footer: {
                    Text(String(localized: "Choose a rule and let Echo rank a small group before sending any AI request. Outreach is never sent automatically."))
                }
                ForEach(insights) { insight in
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(insight.title).font(.headline)
                            Text(insight.detail).foregroundStyle(.secondary)
                            Text(String(localized: "Why this appeared"))
                                .font(.caption.bold())
                                .foregroundStyle(.indigo)
                            Text(reason(for: insight))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle(String(localized: "Insights"))
        }
    }

    private func reason(for insight: LocalRelationshipInsight) -> String {
        switch insight.kind {
        case .intentionAheadOfAction: String(localized: "Some high-priority business contacts have no completed follow-up in Echo yet.")
        case .spaceMismatch: String(localized: "Some low-priority contacts still have repeated activity; review where effort is going.")
        case .intentChanged: String(localized: "A business role or follow-up preference changed over time.")
        case .journeyProgress: String(localized: "This summarizes the commercial context recorded in Echo.")
        case .insufficientData: String(localized: "Echo does not infer a pattern until you have recorded enough context.")
        }
    }
}
