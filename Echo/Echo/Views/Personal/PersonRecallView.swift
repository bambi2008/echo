import EchoAI
import SwiftUI

struct PersonRecallView: View {
    let contacts: [EchoContact]

    @State private var memoryDescription = ""
    @State private var localCandidates: [RecallCandidate] = []
    @State private var aiOrder: [String] = []
    @State private var aiMatches: [String: PersonRecallMatch] = [:]
    @State private var statusMessage: String?
    @State private var hasSearched = false
    @State private var isRefining = false
    @State private var activeRequestID = UUID()

    private let examples = [
        "去年在上海的保险活动认识，王总介绍，做企业客户",
        "以前的同事，后来去了金融行业",
        "最近给我发过关于续保的邮件",
    ]

    private var displayedCandidates: [RecallCandidate] {
        guard !aiOrder.isEmpty else { return localCandidates }
        let candidatesByID = Dictionary(uniqueKeysWithValues: localCandidates.map { ($0.id, $0) })
        let ranked = aiOrder.compactMap { candidatesByID[$0] }
        let rankedIDs = Set(aiOrder)
        return ranked + localCandidates.filter { !rankedIDs.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 34))
                        .foregroundStyle(.indigo)
                    Text("Find someone from a memory")
                        .font(.title2.bold())
                    Text("Describe where you met, their work, who introduced you, or what you discussed. A name is optional.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                TextField(
                    "For example: I met her at an insurance event in Shanghai last year…",
                    text: $memoryDescription,
                    axis: .vertical
                )
                .lineLimit(4...8)

                Button(action: findPeople) {
                    HStack {
                        if isRefining {
                            ProgressView()
                        } else {
                            Image(systemName: "sparkle.magnifyingglass")
                        }
                        Text(isRefining ? "Refining matches…" : "Find people")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(trimmedDescription.count < 3 || isRefining)
            } header: {
                Text("What do you remember?")
            } footer: {
                Text("You can also use the microphone on the iPhone keyboard to describe the person.")
            }

            Section("Try an example") {
                ForEach(examples, id: \.self) { example in
                    Button(example) {
                        memoryDescription = example
                    }
                    .foregroundStyle(.primary)
                }
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: aiOrder.isEmpty ? "iphone" : "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !displayedCandidates.isEmpty {
                Section("Possible matches") {
                    ForEach(displayedCandidates) { candidate in
                        NavigationLink(value: candidate.contact) {
                            RecallResultRow(
                                candidate: candidate,
                                aiMatch: aiMatches[candidate.id]
                            )
                        }
                    }
                }
            } else if hasSearched && !isRefining {
                Section {
                    ContentUnavailableView(
                        "No close match yet",
                        systemImage: "person.slash",
                        description: Text("Try adding a company, city, event, introduction, topic, or approximate date.")
                    )
                }
            }
        }
        .navigationTitle("Memory search")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trimmedDescription: String {
        memoryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func findPeople() {
        let description = trimmedDescription
        guard description.count >= 3 else { return }

        let requestID = UUID()
        activeRequestID = requestID
        hasSearched = true
        aiOrder = []
        aiMatches = [:]
        statusMessage = nil
        localCandidates = RecallSearchEngine.search(
            description: description,
            contacts: contacts
        )
        guard !localCandidates.isEmpty else { return }

        statusMessage = "Private on-device matches are ready. Echo AI is checking the best candidates."
        isRefining = true
        Task {
            await refineWithAI(
                description: description,
                candidates: localCandidates,
                requestID: requestID
            )
        }
    }

    @MainActor
    private func refineWithAI(
        description: String,
        candidates: [RecallCandidate],
        requestID: UUID
    ) async {
        defer {
            if activeRequestID == requestID { isRefining = false }
        }
        do {
            let features = try EchoAIEnvironment.features()
            let privacy = AIPrivacyContext(
                people: candidates.map(\.contact.fullName),
                companies: candidates.compactMap(\.contact.companyName)
            )
            let aliasToIdentifier = Dictionary(uniqueKeysWithValues: candidates.compactMap { candidate in
                privacy.alias(for: candidate.contact.fullName).map {
                    ($0, candidate.contact.systemIdentifier)
                }
            })
            let summaries = candidates.map { candidate in
                let contact = candidate.contact
                let alias = privacy.alias(for: contact.fullName) ?? "Person"
                let notes = contact.notes
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(3)
                    .map { "\($0.createdAt.formatted(date: .abbreviated, time: .omitted)): \($0.content)" }
                    .joined(separator: "; ")
                let interactions = contact.interactions
                    .sorted { $0.date > $1.date }
                    .prefix(4)
                    .map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.summary)" }
                    .joined(separator: "; ")
                return privacy.anonymize("""
                \(alias) | relationship: \(contact.relationshipDomain.title) | company: \(contact.companyName ?? "unknown") | role: \(contact.jobTitle ?? "unknown") | identities: \(contact.tags.joined(separator: ", ")) | local clues: \(candidate.matchedKeywords.joined(separator: ", ")) | notes: \(notes.isEmpty ? "none" : notes) | interactions: \(interactions.isEmpty ? "none" : interactions)
                """)
            }.joined(separator: "\n")

            let result = try await features.personRecall(
                memoryDescription: privacy.anonymize(description),
                candidateSummaries: summaries
            )
            guard activeRequestID == requestID else { return }

            var matchesByID: [String: PersonRecallMatch] = [:]
            var order: [String] = []
            for match in result.value.matches {
                guard let identifier = aliasToIdentifier[match.alias],
                      !order.contains(identifier)
                else { continue }
                order.append(identifier)
                matchesByID[identifier] = PersonRecallMatch(
                    alias: match.alias,
                    confidence: min(max(match.confidence, 0), 100),
                    reason: privacy.restoreAliases(in: match.reason)
                )
            }
            aiOrder = order
            aiMatches = matchesByID
            statusMessage = order.isEmpty
                ? "Showing private on-device matches."
                : "Echo AI refined these matches with \(result.model.rawValue)."
        } catch {
            guard activeRequestID == requestID else { return }
            statusMessage = error is AIServiceError
                ? "\(EchoAIEnvironment.message(for: error)) Showing private on-device matches."
                : "Echo AI is unavailable. Showing private on-device matches."
        }
    }
}

private struct RecallResultRow: View {
    let candidate: RecallCandidate
    let aiMatch: PersonRecallMatch?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.indigo.opacity(0.14))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(candidate.contact.initials)
                            .font(.subheadline.bold())
                            .foregroundStyle(.indigo)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.contact.fullName)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let aiMatch {
                    Text("\(aiMatch.confidence)%")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.1), in: Capsule())
                }
            }
            Text(aiMatch?.reason ?? candidate.localReason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !candidate.matchedKeywords.isEmpty {
                Text("Clues: \(candidate.matchedKeywords.prefix(5).joined(separator: " · "))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        [candidate.contact.jobTitle, candidate.contact.companyName]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty ?? candidate.contact.relationshipDomain.title
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
