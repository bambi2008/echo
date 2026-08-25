import Contacts
import SwiftData
import SwiftUI

struct WeeklyReflectionFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]

    let existingJourney: ReflectionJourney?
    @State private var selectedIDs = Set<String>()
    @State private var draftIntents: [String: String] = [:]
    @State private var draftContexts: [String: String] = [:]
    @State private var searchText = ""
    @State private var step = 0
    @State private var chosenAction: RelationshipActionType = .remember
    @State private var actionContactID: String?
    @State private var showingPicker = false
    @State private var showingManual = false
    @State private var statusMessage: String?

    private let service = RelationshipJourneyService()

    init(journey: ReflectionJourney?) { existingJourney = journey }

    private var journey: ReflectionJourney? { existingJourney }
    private var candidates: [EchoContact] {
        contacts.sorted {
            if ($0.lastRelationshipReviewAt == nil) != ($1.lastRelationshipReviewAt == nil) {
                return $0.lastRelationshipReviewAt == nil
            }
            return $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }
    private var displayedCandidates: [EchoContact] {
        guard !searchText.isEmpty else { return candidates }
        return candidates.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }
    private var selectedContacts: [EchoContact] {
        candidates.filter { selectedIDs.contains($0.systemIdentifier) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: peopleStep
                case 1: intentStep
                case 2: actionStep
                default: completeStep
                }
            }
            .navigationTitle(journey?.currentTheme.title ?? ReflectionTheme.protect.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
            .onAppear(perform: restoreProgress)
            .sheet(isPresented: $showingPicker) {
                SystemContactPicker { selected in
                    showingPicker = false
                    importSelected(selected)
                } onCancel: { showingPicker = false }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingManual) {
                ManualRelationshipContactView { contact in
                    select(contact)
                }
            }
            .alert(String(localized: "Echo"), isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button(String(localized: "OK")) { statusMessage = nil }
            } message: { Text(statusMessage ?? "") }
        }
    }

    private var peopleStep: some View {
        List {
            Section {
                Text(journey?.currentTheme.question ?? ReflectionTheme.protect.question)
                    .font(.title2.bold())
                Text(String(localized: "Choose 1–10 people. People you have not reflected on appear first, and you can revisit anyone."))
                    .foregroundStyle(.secondary)
            }
            Section {
                Button { showingPicker = true } label: {
                    Label(String(localized: "Choose from iPhone Contacts"), systemImage: "person.crop.circle.badge.plus")
                }
                Button { showingManual = true } label: {
                    Label(String(localized: "Add someone manually"), systemImage: "square.and.pencil")
                }
            }
            Section(String(localized: "People")) {
                if displayedCandidates.isEmpty {
                    Text(String(localized: "No matching people. Add someone manually or choose from Contacts."))
                        .foregroundStyle(.secondary)
                }
                ForEach(displayedCandidates) { contact in
                    Button { toggle(contact) } label: {
                        ContactChoiceRow(contact: contact, isSelected: selectedIDs.contains(contact.systemIdentifier))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIDs.count >= 10 && !selectedIDs.contains(contact.systemIdentifier))
                }
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "Search people"))
        .safeAreaInset(edge: .bottom) { nextButton(disabled: selectedIDs.isEmpty) }
    }

    private var intentStep: some View {
        List {
            Section {
                Text(String(localized: "Choose the intention that feels true now."))
                    .font(.title2.bold())
            }
            ForEach(selectedContacts) { contact in
                Section(contact.fullName) {
                    Picker(String(localized: "Intention"), selection: intentBinding(contact)) {
                        Text(String(localized: "Not sure yet")).tag(RelationshipIntent?.none)
                        ForEach(RelationshipIntent.allCases) { intent in
                            Text(intent.title).tag(Optional(intent))
                        }
                    }
                    TextField(String(localized: "Optional context"), text: contextBinding(contact), axis: .vertical)
                        .lineLimit(2...5)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { nextButton(disabled: false) }
    }

    private var actionStep: some View {
        List {
            Section {
                Text(String(localized: "Would one small action feel right this week?"))
                    .font(.title2.bold())
            }
            Section(String(localized: "Person")) {
                Picker(String(localized: "Person"), selection: $actionContactID) {
                    Text(String(localized: "No one")).tag(String?.none)
                    ForEach(selectedContacts) { contact in
                        Text(contact.fullName).tag(Optional(contact.systemIdentifier))
                    }
                }
            }
            Section(String(localized: "Action")) {
                Picker(String(localized: "Action"), selection: $chosenAction) {
                    ForEach(RelationshipActionType.allCases) { type in
                        Label(type.title, systemImage: type.symbol).tag(type)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            nextButton(disabled: chosenAction != .none && actionContactID == nil)
        }
    }

    private var completeStep: some View {
        ReflectionPage {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.indigo)
                .accessibilityLabel(String(localized: "Week reflected"))
            Text(String(localized: "That is enough for this week."))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(mapChangeSummary)
                .font(.title3)
                .multilineTextAlignment(.center)
            Text(String(localized: "Echo will keep your choices visible without turning them into obligations."))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(String(localized: "Done")) { dismiss() }
        }
    }

    private var mapChangeSummary: String {
        let decided = selectedContacts.filter { $0.relationshipIntent != nil }.count
        return String(
            format: String(localized: "This week, %lld relationships came into view and %lld found a direction."),
            selectedContacts.count,
            decided
        )
    }

    private func nextButton(disabled: Bool) -> some View {
        PrimaryButton(step == 2 ? String(localized: "Finish this week") : String(localized: "Continue")) {
            advance()
        }
        .disabled(disabled)
        .padding()
        .background(.bar)
    }

    private func restoreProgress() {
        guard let journey else { return }
        selectedIDs = Set(journey.selectedContactIdentifiers)
        step = Int(journey.activeStepRawValue ?? "0") ?? 0
        draftIntents = decodedPairs(journey.draftIntentValues ?? [])
        draftContexts = decodedPairs(journey.draftContextValues ?? [])
        for contact in selectedContacts where draftIntents[contact.systemIdentifier] == nil {
            draftIntents[contact.systemIdentifier] = contact.relationshipIntent?.rawValue ?? "unsure"
            draftContexts[contact.systemIdentifier] = contact.relationshipContext ?? ""
        }
    }

    private func toggle(_ contact: EchoContact) {
        if selectedIDs.contains(contact.systemIdentifier) {
            selectedIDs.remove(contact.systemIdentifier)
        } else {
            select(contact)
        }
        persistProgress()
    }

    private func select(_ contact: EchoContact) {
        guard selectedIDs.count < 10 || selectedIDs.contains(contact.systemIdentifier) else { return }
        selectedIDs.insert(contact.systemIdentifier)
        contact.relationshipJourneyIncluded = true
        draftIntents[contact.systemIdentifier] = contact.relationshipIntent?.rawValue ?? "unsure"
        draftContexts[contact.systemIdentifier] = contact.relationshipContext ?? ""
        persistProgress()
    }

    private func importSelected(_ selected: [CNContact]) {
        do {
            let imported = try SelectedContactImportService().importSelected(selected, into: modelContext)
            imported.forEach(select)
        } catch {
            statusMessage = String(localized: "The selected contacts could not be added.")
        }
    }

    private func advance() {
        guard let journey else { return }
        do {
            if step == 1 {
                for contact in selectedContacts {
                    _ = try service.review(
                        contact: contact,
                        intent: draftIntents[contact.systemIdentifier].flatMap(RelationshipIntent.init(rawValue:)),
                        contextText: draftContexts[contact.systemIdentifier],
                        theme: journey.currentTheme,
                        journey: journey,
                        in: modelContext
                    )
                }
            }
            if step == 2 {
                let contact = selectedContacts.first { $0.systemIdentifier == actionContactID }
                let action = try service.planAction(
                    for: contact,
                    type: chosenAction,
                    plannedFor: chosenAction == .none ? nil : Calendar.current.date(byAdding: .day, value: 2, to: .now),
                    journey: journey,
                    in: modelContext
                )
                if action.status == .planned {
                    Task { await RelationshipReminderCoordinator().schedulePlannedActionIfEnabled(action) }
                }
                try service.completeWeek(journey, in: modelContext)
                step = 3
                return
            }
            step += 1
            persistProgress()
        } catch {
            statusMessage = String(localized: "This week's reflection could not be saved.")
        }
    }

    private func persistProgress() {
        guard let journey else { return }
        journey.selectedContactIdentifiers = Array(selectedIDs)
        journey.activeStepRawValue = String(step)
        journey.draftIntentValues = encodedPairs(draftIntents)
        journey.draftContextValues = encodedPairs(draftContexts)
        try? modelContext.save()
    }

    private func intentBinding(_ contact: EchoContact) -> Binding<RelationshipIntent?> {
        Binding(
            get: {
                guard let rawValue = draftIntents[contact.systemIdentifier] else {
                    return contact.relationshipIntent
                }
                return RelationshipIntent(rawValue: rawValue)
            },
            set: { draftIntents[contact.systemIdentifier] = $0?.rawValue ?? "unsure"; persistProgress() }
        )
    }

    private func contextBinding(_ contact: EchoContact) -> Binding<String> {
        Binding(
            get: { draftContexts[contact.systemIdentifier] ?? contact.relationshipContext ?? "" },
            set: { draftContexts[contact.systemIdentifier] = $0; persistProgress() }
        )
    }

    private func encodedPairs(_ values: [String: String]) -> [String] {
        values.keys.sorted().flatMap { [$0, values[$0] ?? ""] }
    }

    private func decodedPairs(_ values: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for index in stride(from: 0, to: values.count - 1, by: 2) {
            result[values[index]] = values[index + 1]
        }
        return result
    }
}
