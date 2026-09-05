import SwiftData
import SwiftUI

struct PersonalHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [EchoContact]
    @Query(sort: \ReflectionJourney.startedAt, order: .reverse) private var journeys: [ReflectionJourney]
    @Query(sort: \RelationshipAction.createdAt, order: .reverse) private var actions: [RelationshipAction]
    @Query(sort: \Deal.createdAt, order: .reverse) private var pipelineItems: [Deal]
    @State private var showingReflection = false
    @State private var showingOngoingReflection = false
    @State private var showingOutcome: RelationshipAction?

    private let service = RelationshipJourneyService()
    private var activeJourney: ReflectionJourney? { journeys.first(where: { !$0.isComplete }) }
    private var currentAction: RelationshipAction? { actions.first(where: { $0.status == .planned }) }
    private var attentionItems: [Deal] { pipelineItems.filter(\.humanAttentionRequired) }
    private var activeContacts: [EchoContact] { contacts.filter(\.isInEchoLayer) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !attentionItems.isEmpty { humanAttentionCard }
                    if let journey = activeJourney {
                        journeyCard(journey)
                    } else {
                        newJourneyCard
                    }
                    if let action = currentAction { actionCard(action) }
                    mapCard
                    guidanceCard
                }
                .padding()
            }
            .navigationTitle(String(localized: "Echo"))
            .sheet(isPresented: $showingReflection) {
                WeeklyReflectionFlow(journey: activeJourney)
            }
            .sheet(isPresented: $showingOngoingReflection) { OngoingReflectionView() }
            .confirmationDialog(String(localized: "How did it feel?"), isPresented: Binding(
                get: { showingOutcome != nil },
                set: { if !$0 { showingOutcome = nil } }
            )) {
                if let action = showingOutcome {
                    ForEach(ReflectionOutcome.allCases) { outcome in
                        Button(outcome.title) { record(outcome, for: action); showingOutcome = nil }
                    }
                    Button(String(localized: "Skip for now"), role: .cancel) { complete(action); showingOutcome = nil }
                }
            }
        }
    }

    private var humanAttentionCard: some View {
        NavigationLink { PipelineView(initialPipelineID: attentionItems.first?.pipeline?.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(String(localized: "Human Attention"), systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.headline).foregroundStyle(.indigo)
                Text(String(localized: "\(attentionItems.count) relationship items need your judgment"))
                    .font(.title2.bold()).foregroundStyle(.primary)
                if let first = attentionItems.first {
                    Text(first.organization?.name ?? first.title).foregroundStyle(.secondary).lineLimit(1)
                }
            }.echoCard()
        }.buttonStyle(.plain).accessibilityIdentifier("home.humanAttention")
    }

    private func journeyCard(_ journey: ReflectionJourney) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Week \(min(journey.currentWeekIndex, 4)) of 4"))
                .font(.caption.bold()).foregroundStyle(.indigo)
            Text(journey.currentTheme.title).font(.title.bold())
            Text(journey.currentTheme.question).font(.title3).foregroundStyle(.secondary)
            ProgressView(value: Double(journey.completedThemes.count), total: 4)
                .tint(.indigo)
            PrimaryButton(String(localized: "Continue this week's reflection"), identifier: "home.continueReflection") {
                showingReflection = true
            }
        }
        .echoCard()
    }

    private var newJourneyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(journeys.isEmpty
                 ? String(localized: "Who do you not want to slowly disappear from your life?")
                 : ReflectionTheme.ongoing.question)
                .font(.title.bold())
            Text(journeys.isEmpty
                 ? String(localized: "Choose a few people and one honest intention. Nothing becomes overdue.")
                 : String(localized: "Your four-week map is complete. Keep returning only when a relationship comes to mind."))
                .foregroundStyle(.secondary)
            PrimaryButton(journeys.isEmpty
                          ? String(localized: "Begin a four-week reflection")
                          : String(localized: "Take a weekly moment")) {
                if journeys.isEmpty {
                    _ = try? service.startJourney(in: modelContext)
                    showingReflection = true
                } else {
                    showingOngoingReflection = true
                }
            }
        }
        .echoCard()
    }

    private func actionCard(_ action: RelationshipAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "One small action"), systemImage: "checkmark.circle")
                .font(.headline).foregroundStyle(.indigo)
            Text(action.type.title).font(.title3.bold())
            if let contact = action.contact { Text(contact.fullName).foregroundStyle(.secondary) }
            if let date = action.plannedFor {
                Text(date, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(String(localized: "Done")) { showingOutcome = action }.buttonStyle(.borderedProminent)
                Button(String(localized: "Let go")) { cancel(action) }.buttonStyle(.bordered)
            }
        }
        .echoCard()
    }

    private var mapCard: some View {
        NavigationLink {
            RelationshipMapSummaryView(contacts: activeContacts)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(String(localized: "Relationship map"), systemImage: "circle.grid.2x2.fill")
                    .font(.headline).foregroundStyle(.indigo)
                Text(String(localized: "\(activeContacts.count) people in view"))
                    .font(.title2.bold()).foregroundStyle(.primary)
                Text(String(localized: "See where you want closeness, steadiness, lightness, or space."))
                    .foregroundStyle(.secondary)
            }
            .echoCard()
        }
        .buttonStyle(.plain)
    }

    private var guidanceCard: some View {
        let guidance = RelationshipGuidanceEngine.guidance(for: activeContacts).first
        return VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "A gentle nudge"), systemImage: "sparkle")
                .font(.headline).foregroundStyle(.indigo)
            Text(guidance?.explanation ?? String(localized: "Echo will offer a nudge only when it follows an intention or rhythm you chose."))
                .foregroundStyle(.secondary)
        }
        .echoCard()
    }

    private func complete(_ action: RelationshipAction) {
        try? service.completeAction(action, in: modelContext)
        Task { await RelationshipReminderCoordinator().completeAction(action) }
    }

    private func record(_ outcome: ReflectionOutcome, for action: RelationshipAction) {
        try? service.completeAction(action, in: modelContext)
        _ = try? service.recordOutcome(outcome, for: action, in: modelContext)
        Task { await RelationshipReminderCoordinator().completeAction(action) }
    }

    private func cancel(_ action: RelationshipAction) {
        try? service.cancelAction(action, in: modelContext)
        RelationshipReminderCoordinator().cancelAction(action)
    }
}

private struct OngoingReflectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @Query(sort: \RelationshipReflection.createdAt, order: .reverse) private var reflections: [RelationshipReflection]
    @State private var selectedID: String?
    @State private var actionType: RelationshipActionType = .none
    @State private var selectedIntent: RelationshipIntent?
    @State private var contextText = ""
    private let service = RelationshipJourneyService()
    private var people: [EchoContact] { contacts.filter(\.isInEchoLayer) }
    private var currentQuestion: String {
        OngoingReflectionQuestionBank.question(completedReflectionCount: reflections.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(currentQuestion).font(.title2.bold()) }
                Picker(String(localized: "Person"), selection: $selectedID) {
                    Text(String(localized: "Choose someone")).tag(String?.none)
                    ForEach(people) { Text($0.fullName).tag(Optional($0.systemIdentifier)) }
                }
                if people.contains(where: { $0.systemIdentifier == selectedID }) {
                    Picker(String(localized: "Intention"), selection: $selectedIntent) {
                        Text(String(localized: "Not sure yet")).tag(RelationshipIntent?.none)
                        ForEach(RelationshipIntent.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                    TextField(String(localized: "What has been happening between you lately?"), text: $contextText, axis: .vertical)
                    Picker(String(localized: "One small action"), selection: $actionType) {
                        ForEach(RelationshipActionType.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            .navigationTitle(String(localized: "A moment to reflect"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Save")) { save() }.disabled(selectedID == nil) }
            }
            .onChange(of: selectedID) { _, _ in loadSelectedContact() }
        }
    }
    private func loadSelectedContact() {
        let contact = people.first(where: { $0.systemIdentifier == selectedID })
        selectedIntent = contact?.relationshipIntent
        contextText = contact?.relationshipContext ?? ""
    }
    private func save() {
        guard let contact = people.first(where: { $0.systemIdentifier == selectedID }) else { return }
        _ = try? service.review(contact: contact, intent: selectedIntent, contextText: contextText, theme: .ongoing, journey: nil, in: modelContext)
        let action = try? service.planAction(for: actionType == .none ? nil : contact, type: actionType, plannedFor: actionType == .none ? nil : Calendar.current.date(byAdding: .day, value: 2, to: .now), journey: nil, in: modelContext)
        if let action, action.status == .planned {
            Task { await RelationshipReminderCoordinator().schedulePlannedActionIfEnabled(action) }
        }
        dismiss()
    }
}

private struct RelationshipMapSummaryView: View {
    let contacts: [EchoContact]
    var body: some View {
        List {
            ForEach(RelationshipIntent.allCases) { intent in
                Section(intent.title) {
                    let people = contacts.filter { $0.relationshipIntent == intent }
                    if people.isEmpty { Text(String(localized: "No one here yet")).foregroundStyle(.secondary) }
                    ForEach(people) { Text($0.fullName) }
                }
            }
            Section(String(localized: "Not sure yet")) {
                let people = contacts.filter { $0.relationshipIntent == nil }
                if people.isEmpty { Text(String(localized: "No one here yet")).foregroundStyle(.secondary) }
                ForEach(people) { Text($0.fullName) }
            }
        }
        .navigationTitle(String(localized: "Relationship map"))
    }
}

private extension View {
    func echoCard() -> some View {
        self.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
