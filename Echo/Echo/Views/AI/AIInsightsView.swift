import EchoAI
import SwiftData
import SwiftUI

struct AIInsightsView: View {
    @Query private var contacts: [EchoContact]
    @Query(sort: \Deal.createdAt, order: .reverse) private var deals: [Deal]
    @State private var insights: [InsightCardData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                        Text("Turn your people, conversations, and pipeline into useful next actions.")
                            .foregroundStyle(.secondary)
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
                            DocumentRecognitionView(kind: .businessCard)
                        } label: {
                            AIFeatureCard(
                                title: "Business card",
                                subtitle: "Scan into People",
                                symbol: "person.crop.rectangle",
                                color: .blue
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

                    HStack {
                        Text("Suggested outreach")
                            .font(.title3.bold())
                        Spacer()
                        if !insights.isEmpty {
                            Text("Top \(insights.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if insights.isEmpty && !isLoading {
                        outreachIntro
                    }

                    ForEach(insights) { insight in
                        InsightCard(insight: insight)
                    }
                }
                .padding()
            }
            .navigationTitle("Echo AI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: generateInsights) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Generate outreach suggestions")
                }
            }
            .alert("Echo AI", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var outreachIntro: some View {
        VStack(spacing: 15) {
            Image(systemName: "message.badge.waveform.fill")
                .font(.system(size: 38))
                .foregroundStyle(.indigo)
            Text("Find the right words")
                .font(.headline)
            Text("Echo will choose three people who need attention and draft a warm, specific opening message.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Generate suggestions", action: generateInsights)
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func generateInsights() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let features = try EchoAIEnvironment.features()
                var generated: [InsightCardData] = []

                for contact in contacts.sorted(by: {
                    EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1)
                }).prefix(3) {
                    let privacy = AIPrivacyContext(
                        people: [contact.fullName],
                        companies: [contact.companyName ?? ""]
                    )
                    let alias = privacy.alias(for: contact.fullName) ?? "Person A"
                    let safeNote = contact.notes.last.map { privacy.anonymize($0.content) }
                    let result = try await features.conversationOpener(
                        personAlias: alias,
                        recentNote: safeNote,
                        daysSinceContact: contact.daysSinceContact,
                        relationship: contact.jobTitle ?? contact.tags.first ?? "personal relationship"
                    )
                    generated.append(InsightCardData(
                        person: contact.fullName,
                        kind: "What to say",
                        message: privacy.restoreAliases(in: result.text),
                        model: result.model.rawValue
                    ))
                }
                insights = generated
            } catch {
                errorMessage = EchoAIEnvironment.message(for: error)
            }
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

private struct InsightCard: View {
    let insight: InsightCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(insight.kind, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                Spacer()
                Text(insight.model)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(insight.person).font(.headline)
            Text(insight.message).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct InsightCardData: Identifiable {
    let id = UUID()
    let person: String
    let kind: String
    let message: String
    let model: String
}
