import SwiftData
import SwiftUI

struct AIInsightsView: View {
    @Query private var contacts: [EchoContact]
    @Query(sort: \Deal.createdAt, order: .reverse) private var deals: [Deal]
    @StateObject private var subscription = EchoSubscriptionManager.shared
    @State private var showingPro = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your relationship copilot")
                            .font(.title2.bold())
                        Text("Analyze the right group of people, then focus on the relationships that matter.")
                            .foregroundStyle(.secondary)
                    }

                    if !subscription.hasPremiumAccess {
                        Button { showingPro = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(.indigo)
                                    .frame(width: 40, height: 40)
                                    .background(Color.indigo.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Make this your daily ritual")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text("Try Echo Pro free for 7 days: ranked insights, briefings, and better next words.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(Color.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink {
                            RelationshipAnalysisView(mode: .insight, contacts: contacts)
                        } label: {
                            AIFeatureCard(
                                title: "Relationship insight",
                                subtitle: "See patterns",
                                symbol: "person.text.rectangle",
                                color: .indigo
                            )
                        }
                        NavigationLink {
                            RelationshipAnalysisView(mode: .health, contacts: contacts)
                        } label: {
                            AIFeatureCard(
                                title: "Relationship health",
                                subtitle: "Check momentum",
                                symbol: "heart.text.clipboard",
                                color: .pink
                            )
                        }
                        NavigationLink {
                            DailyBriefingView(contacts: contacts)
                        } label: {
                            AIFeatureCard(
                                title: "Daily briefing",
                                subtitle: "Prioritize today",
                                symbol: "sun.max.fill",
                                color: .orange
                            )
                        }
                        NavigationLink {
                            SalesCoachingView(deals: deals)
                        } label: {
                            AIFeatureCard(
                                title: "Sales follow-up",
                                subtitle: "Move deals forward",
                                symbol: "chart.line.uptrend.xyaxis",
                                color: .green
                            )
                        }
                        NavigationLink {
                            DocumentRecognitionView(kind: .policy)
                        } label: {
                            AIFeatureCard(
                                title: "Policy scan",
                                subtitle: "Extract key fields",
                                symbol: "doc.text.viewfinder",
                                color: .teal
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Outreach suggestions now appear when you contact someone.", systemImage: "message.badge")
                            .font(.subheadline.weight(.semibold))
                        Text("Open a person in People, then choose Message or Email. Echo will draft a specific opener at that moment.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding()
            }
            .navigationTitle("Echo AI")
            .sheet(isPresented: $showingPro) { EchoProView(subscription: subscription) }
        }
    }
}

private struct AIFeatureCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(15)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
