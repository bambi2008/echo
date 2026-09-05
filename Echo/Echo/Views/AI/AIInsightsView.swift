import SwiftData
import SwiftUI

struct AIInsightsView: View {
    @Query private var contacts: [EchoContact]
    @Query(sort: \ReflectionJourney.startedAt, order: .reverse) private var journeys: [ReflectionJourney]

    private var insights: [LocalRelationshipInsight] {
        RelationshipGuidanceEngine.insights(contacts: activeContacts, journeys: journeys)
    }

    private var activeContacts: [EchoContact] {
        contacts.filter { $0.isInEchoLayer && $0.hasRealName }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Patterns, not judgments"))
                            .font(.title2.bold())
                        Text(String(localized: "These observations come only from intentions and actions you recorded in Echo. No API key is needed."))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    NavigationLink {
                        RelationshipAnalysisView(mode: .insight, contacts: activeContacts)
                    } label: {
                        Label("Relationship insight", systemImage: "person.text.rectangle")
                    }
                    NavigationLink {
                        RelationshipAnalysisView(mode: .health, contacts: activeContacts)
                    } label: {
                        Label("Relationship health", systemImage: "heart.text.clipboard")
                    }
                    NavigationLink {
                        DailyBriefingView(contacts: activeContacts)
                    } label: {
                        Label("Today's relationship briefing", systemImage: "sun.max.fill")
                    }
                } header: {
                    Text("AI tools")
                } footer: {
                    Text("Choose a rule and let Echo rank a small group before sending any AI request. Nothing is sent automatically.")
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
        case .intentionAheadOfAction: String(localized: "Some Grow closer relationships have no completed action in Echo yet.")
        case .spaceMismatch: String(localized: "Some Give it space relationships also have repeated completed actions.")
        case .intentChanged: String(localized: "Your recorded intention changed over time.")
        case .journeyProgress: String(localized: "This summarizes the reflections you completed.")
        case .insufficientData: String(localized: "Echo does not infer a pattern until you have recorded enough context.")
        }
    }
}
