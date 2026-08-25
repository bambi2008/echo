import Contacts
import SwiftData
import SwiftUI

@MainActor
struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @Query(sort: \ReflectionJourney.startedAt, order: .reverse) private var journeys: [ReflectionJourney]
    @Query(sort: \RelationshipAction.createdAt, order: .reverse) private var actions: [RelationshipAction]
    @AppStorage("echo.relationship.onboarding.stage") private var stageRawValue = OnboardingStage.philosophy.rawValue
    @StateObject private var speech = SpeechRecognitionService()
    @State private var showingContactPicker = false
    @State private var showingManualContact = false
    @State private var selectedActionContactID: String?
    @State private var selectedActionType: RelationshipActionType?
    @State private var activeVoiceContactID: String?
    @State private var voiceTextBeforeRecording = ""
    @State private var statusMessage: String?

    let finish: () -> Void
    private let journeyService = RelationshipJourneyService()

    private var stage: OnboardingStage {
        OnboardingStage(rawValue: stageRawValue) ?? .philosophy
    }

    private var journey: ReflectionJourney? {
        journeys.first(where: { !$0.isComplete }) ?? journeys.first
    }

    private var selectedContacts: [EchoContact] {
        guard let journey else { return [] }
        let ids = Set(journey.selectedContactIdentifiers)
        return contacts.filter { ids.contains($0.systemIdentifier) }
    }

    private var plannedAction: RelationshipAction? {
        guard let journey else { return nil }
        return actions.first(where: { $0.journeyID == journey.id })
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Group {
                switch stage {
                case .philosophy: philosophyView
                case .coreQuestion: coreQuestionView
                case .contactSelection: contactSelectionView
                case .intentions: intentionsView
                case .context: contextView
                case .action: actionView
                case .completed: completionView
                }
            }
            .transition(reduceMotion ? .identity : .opacity)
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showingContactPicker) {
            SystemContactPicker { selected in
                showingContactPicker = false
                importSelectedContacts(selected)
            } onCancel: {
                showingContactPicker = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingManualContact) {
            ManualRelationshipContactView { contact in
                addToJourney(contact)
            }
        }
        .onChange(of: speech.transcript) { _, transcript in
            guard let activeVoiceContactID,
                  let contact = contacts.first(where: { $0.systemIdentifier == activeVoiceContactID })
            else { return }
            contact.relationshipContext = VoiceTranscriptComposer.combine(
                existing: voiceTextBeforeRecording,
                spoken: transcript
            )
            try? modelContext.save()
        }
        .onDisappear { speech.stop() }
        .alert("Echo", isPresented: Binding(
            get: { statusMessage != nil || speech.errorMessage != nil },
            set: { if !$0 { statusMessage = nil; speech.errorMessage = nil } }
        )) {
            Button(String(localized: "OK")) { statusMessage = nil; speech.errorMessage = nil }
        } message: {
            Text(statusMessage ?? speech.errorMessage ?? "")
        }
        .task { seedUITestContactsIfNeeded() }
    }

    private var philosophyView: some View {
        ReflectionPage {
            Spacer()
            Text(String(localized: "Some people do not disappear all at once.\nWe simply think of them, again and again, without reaching out."))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("onboarding.philosophy.title")
            Spacer()
            PrimaryButton(String(localized: "Continue"), identifier: "onboarding.continue") {
                move(to: .coreQuestion)
            }
        }
    }

    private var coreQuestionView: some View {
        ReflectionPage {
            Spacer()
            VStack(spacing: 18) {
                Text(String(localized: "Start with the people you do not want to slowly disappear from your life."))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboarding.coreQuestion.title")
                Text(String(localized: "You do not need to sort everyone. Start with up to five people this week."))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            PrimaryButton(String(localized: "Take a moment"), identifier: "onboarding.takeMoment") {
                ensureJourney()
                move(to: .contactSelection)
            }
        }
    }

    private var contactSelectionView: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Choose a few people"))
                            .font(.title2.bold())
                        Text(String(localized: "Echo only needs the people you choose to bring in. You can add or remove them later."))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                if !contacts.isEmpty {
                    Section(String(localized: "In Echo")) {
                        ForEach(contacts) { contact in
                            Button { toggleJourneyContact(contact) } label: {
                                ContactChoiceRow(
                                    contact: contact,
                                    isSelected: selectedContacts.contains(where: { $0.systemIdentifier == contact.systemIdentifier })
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding.contact.\(contact.systemIdentifier)")
                            .disabled(selectedContacts.count >= 10 && !selectedContacts.contains(where: { $0.systemIdentifier == contact.systemIdentifier }))
                        }
                    }
                }

                Section {
                    Button {
                        showingContactPicker = true
                    } label: {
                        Label(String(localized: "Choose from iPhone Contacts"), systemImage: "person.crop.circle.badge.plus")
                    }
                    .accessibilityIdentifier("onboarding.chooseContacts")
                    Button {
                        showingManualContact = true
                    } label: {
                        Label(String(localized: "Add someone manually"), systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("onboarding.addManually")
                } footer: {
                    Text(String(localized: "Choosing people does not import your entire address book. If you prefer not to use Contacts, add someone manually."))
                }
            }
            .navigationTitle(String(localized: "People in view"))
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    PrimaryButton(
                        selectedContacts.isEmpty
                            ? String(localized: "Continue without choosing")
                            : String(localized: "Continue with \(selectedContacts.count) people"),
                        identifier: "onboarding.contactsContinue"
                    ) {
                        if selectedContacts.isEmpty {
                            move(to: .completed)
                        } else {
                            move(to: .intentions)
                        }
                    }
                    Text(String(localized: "Choose 1–10 people. Five is only a suggestion."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var intentionsView: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "How would you like each relationship to move from here?"))
                        .font(.title2.bold())
                        .padding(.vertical, 6)
                }
                ForEach(selectedContacts) { contact in
                    Section(contact.fullName) {
                        ForEach(RelationshipIntent.allCases) { intent in
                            Button {
                                saveReflection(for: contact, intent: intent)
                            } label: {
                                IntentChoiceRow(intent: intent, isSelected: contact.relationshipIntent == intent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding.intent.\(intent.rawValue)")
                        }
                        Button {
                            saveReflection(for: contact, intent: nil)
                        } label: {
                            HStack {
                                Label(String(localized: "Not sure yet"), systemImage: "questionmark.circle")
                                Spacer()
                                if contact.relationshipIntent == nil,
                                   contact.lastRelationshipReviewAt != nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(String(localized: "Relationship intention"))
            .toolbar { backToolbar(to: .contactSelection) }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(String(localized: "Continue"), identifier: "onboarding.intentionsContinue") {
                    move(to: .context)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var contextView: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "What has been happening between you lately?"))
                        .font(.title2.bold())
                    Text(String(localized: "This is optional and stays in Echo on this device."))
                        .foregroundStyle(.secondary)
                }
                ForEach(selectedContacts) { contact in
                    Section(contact.fullName) {
                        TextField(
                            String(localized: "A sentence you want to remember"),
                            text: contextBinding(for: contact),
                            axis: .vertical
                        )
                        .lineLimit(2...5)
                        Button {
                            toggleVoice(for: contact)
                        } label: {
                            Label(
                                speech.isRecording && activeVoiceContactID == contact.systemIdentifier
                                    ? String(localized: "Stop listening")
                                    : String(localized: "Describe by voice"),
                                systemImage: speech.isRecording && activeVoiceContactID == contact.systemIdentifier ? "stop.fill" : "mic.fill"
                            )
                        }
                        .tint(speech.isRecording && activeVoiceContactID == contact.systemIdentifier ? .red : .indigo)
                    }
                }
            }
            .navigationTitle(String(localized: "A little context"))
            .toolbar { backToolbar(to: .intentions) }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(String(localized: "Continue"), identifier: "onboarding.contextContinue") {
                    speech.stop()
                    saveContexts()
                    move(to: .action)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private var actionView: some View {
        NavigationStack {
            List {
                if plannedAction == nil {
                    Section {
                        Text(String(localized: "You have brought \(selectedContacts.count) relationships back into view."))
                            .font(.title2.bold())
                        Text(String(localized: "If you did one small thing for one person this week, who would you choose?"))
                            .foregroundStyle(.secondary)
                    }
                    Section(String(localized: "Choose one person")) {
                        ForEach(selectedContacts) { contact in
                            Button { selectedActionContactID = contact.systemIdentifier } label: {
                                ContactChoiceRow(contact: contact, isSelected: selectedActionContactID == contact.systemIdentifier)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding.actionContact.\(contact.systemIdentifier)")
                        }
                    }
                    Section(String(localized: "Choose one action")) {
                        ForEach(RelationshipActionType.allCases) { type in
                            Button { selectedActionType = type } label: {
                                HStack {
                                    Label(type.title, systemImage: type.symbol)
                                    Spacer()
                                    if selectedActionType == type { Image(systemName: "checkmark") }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding.action.\(type.rawValue)")
                        }
                    }
                } else {
                    completionCard
                }
            }
            .navigationTitle(String(localized: "One small action"))
            .toolbar { backToolbar(to: .context) }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    plannedAction == nil ? String(localized: "Keep this plan") : String(localized: "Enter Echo"),
                    identifier: plannedAction == nil ? "onboarding.planAction" : "onboarding.enterEcho"
                ) {
                    if plannedAction == nil { saveFirstAction() }
                    else { completeOnboarding() }
                }
                .disabled(plannedAction == nil && (selectedActionType == nil || (selectedActionType != RelationshipActionType.none && selectedActionContactID == nil)))
                .padding()
                .background(.bar)
            }
        }
    }

    private var completionView: some View {
        ReflectionPage {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.indigo)
                Text(String(localized: "Your relationship map can begin whenever you are ready."))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(String(localized: "Nothing is overdue. You can return to this question at any time."))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            PrimaryButton(String(localized: "Enter Echo"), identifier: "onboarding.enterEcho") {
                completeOnboarding()
            }
        }
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "A choice you made"), systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.indigo)
            if let action = plannedAction {
                Text(action.type.title).font(.title3.bold())
                if let contact = action.contact { Text(contact.fullName).foregroundStyle(.secondary) }
            }
            Text(String(localized: "Echo will keep this visible without turning it into pressure."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ToolbarContentBuilder
    private func backToolbar(to target: OnboardingStage) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { move(to: target) } label: {
                Label(String(localized: "Back"), systemImage: "chevron.left")
            }
        }
    }

    private func move(to newStage: OnboardingStage) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            stageRawValue = newStage.rawValue
        }
    }

    private func ensureJourney() {
        _ = try? journeyService.startJourney(in: modelContext)
    }

    private func addToJourney(_ contact: EchoContact) {
        ensureJourney()
        guard let journey, !journey.selectedContactIdentifiers.contains(contact.systemIdentifier), journey.selectedContactIdentifiers.count < 10 else { return }
        journey.selectedContactIdentifiers.append(contact.systemIdentifier)
        contact.relationshipJourneyIncluded = true
        try? modelContext.save()
    }

    private func toggleJourneyContact(_ contact: EchoContact) {
        ensureJourney()
        guard let journey else { return }
        if let index = journey.selectedContactIdentifiers.firstIndex(of: contact.systemIdentifier) {
            journey.selectedContactIdentifiers.remove(at: index)
        } else if journey.selectedContactIdentifiers.count < 10 {
            journey.selectedContactIdentifiers.append(contact.systemIdentifier)
            contact.relationshipJourneyIncluded = true
        }
        try? modelContext.save()
    }

    private func importSelectedContacts(_ selected: [CNContact]) {
        do {
            let imported = try SelectedContactImportService().importSelected(selected, into: modelContext)
            imported.forEach(addToJourney)
        } catch {
            statusMessage = String(localized: "The selected contacts could not be added.")
        }
    }

    private func saveReflection(for contact: EchoContact, intent: RelationshipIntent?) {
        do {
            _ = try journeyService.review(
                contact: contact,
                intent: intent,
                contextText: contact.relationshipContext,
                theme: .protect,
                journey: journey,
                in: modelContext
            )
        } catch {
            statusMessage = String(localized: "This reflection could not be saved.")
        }
    }

    private func contextBinding(for contact: EchoContact) -> Binding<String> {
        Binding(
            get: { contact.relationshipContext ?? "" },
            set: { value in contact.relationshipContext = value; try? modelContext.save() }
        )
    }

    private func toggleVoice(for contact: EchoContact) {
        if speech.isRecording {
            speech.stop()
            activeVoiceContactID = nil
            return
        }
        activeVoiceContactID = contact.systemIdentifier
        voiceTextBeforeRecording = contact.relationshipContext ?? ""
        Task { await speech.start() }
    }

    private func saveFirstAction() {
        guard let type = selectedActionType else { return }
        let contact = selectedActionContactID.flatMap { id in contacts.first(where: { $0.systemIdentifier == id }) }
        do {
            let action = try journeyService.planAction(
                for: contact,
                type: type,
                plannedFor: type == .none ? nil : Calendar.current.date(byAdding: .day, value: 2, to: .now),
                journey: journey,
                in: modelContext
            )
            if action.status == .planned {
                Task { await RelationshipReminderCoordinator().schedulePlannedActionIfEnabled(action) }
            }
            if let journey { try journeyService.completeWeek(journey, in: modelContext) }
        } catch {
            statusMessage = String(localized: "This action could not be saved.")
        }
    }

    private func saveContexts() {
        for contact in selectedContacts {
            try? journeyService.updateContext(
                for: contact,
                text: contact.relationshipContext,
                journey: journey,
                in: modelContext
            )
        }
    }

    private func completeOnboarding() {
        stageRawValue = OnboardingStage.completed.rawValue
        finish()
    }

    private func seedUITestContactsIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--echo-ui-testing"), contacts.isEmpty else { return }
        for name in ["Alex Chen", "Maya Lin"] {
            let parts = name.split(separator: " ").map(String.init)
            let contact = EchoContact(givenName: parts[0], familyName: parts[1])
            modelContext.insert(contact)
        }
        try? modelContext.save()
        #endif
    }
}

struct ReflectionPage<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(spacing: 24) { content }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
    }
}

struct PrimaryButton: View {
    let title: String
    let identifier: String?
    let action: () -> Void

    init(_ title: String, identifier: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .accessibilityIdentifier(identifier ?? "")
    }
}

struct ContactChoiceRow: View {
    let contact: EchoContact
    let isSelected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.indigo.opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay(Text(contact.initials).font(.subheadline.bold()).foregroundStyle(.indigo))
            Text(contact.fullName).foregroundStyle(.primary)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .indigo : .secondary)
        }
        .contentShape(Rectangle())
    }
}

struct IntentChoiceRow: View {
    let intent: RelationshipIntent
    let isSelected: Bool
    var body: some View {
        HStack {
            Label(intent.title, systemImage: intent.symbol)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected { Image(systemName: "checkmark").foregroundStyle(.indigo) }
        }
        .contentShape(Rectangle())
        .accessibilityLabel(intent.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
