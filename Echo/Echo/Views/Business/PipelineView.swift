import SwiftData
import SwiftUI

private func localizedPipelineValue(_ value: String) -> String {
    String(localized: String.LocalizationValue(value))
}

struct PipelineView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pipeline.createdAt) private var pipelines: [Pipeline]
    @Query(sort: \Deal.createdAt, order: .reverse) private var allItems: [Deal]
    @Query(sort: \Organization.name) private var organizations: [Organization]
    @State private var selectedPipelineID: UUID?
    @State private var filter = PipelineFilter()
    @State private var sort: PipelineSort = .nextAction
    @State private var showingNewItem = false
    @State private var showingNewPipeline = false
    @State private var showingFilters = false
    @State private var showingStageEditor = false
    @State private var errorMessage: String?

    init(initialPipelineID: UUID? = nil) {
        _selectedPipelineID = State(initialValue: initialPipelineID)
    }

    private var activePipelines: [Pipeline] { pipelines.filter { !$0.isArchived } }
    private var selectedPipeline: Pipeline? { activePipelines.first { $0.id == selectedPipelineID } ?? activePipelines.first }
    private var scopedFilter: PipelineFilter { var value = filter; value.pipelineID = selectedPipeline?.id; return value }
    private var items: [Deal] { PipelineQuery.items(allItems.filter { $0.status != .archived }, matching: scopedFilter, sortedBy: sort) }
    private var allPipelineItems: [Deal] {
        guard let id = selectedPipeline?.id else { return [] }
        return allItems.filter { $0.pipeline?.id == id && $0.status != .archived }
    }
    private var stages: [PipelineStageDefinition] {
        var result = selectedPipeline?.stageDefinitions ?? DealStage.defaultAgenticStages.map { PipelineStageDefinition(identifier: $0.rawValue) }
        for stage in allPipelineItems.map(\.stageDefinition) where !result.contains(stage) {
            result.append(stage)
        }
        return result
    }

    var body: some View {
        Group { horizontalSizeClass == .regular ? AnyView(regularLayout) : AnyView(compactLayout) }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(selectedPipeline?.name ?? "Pipeline")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { pipelineMenu }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingFilters = true } label: { Image(systemName: hasActiveFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") }
                        .accessibilityLabel("Filter pipeline")
                    Menu { Picker("Sort", selection: $sort) { ForEach(PipelineSort.allCases) { Text(localizedPipelineValue($0.title)).tag($0) } } } label: { Image(systemName: "arrow.up.arrow.down") }
                    Button { showingNewItem = true } label: { Image(systemName: "plus") }.accessibilityIdentifier("pipeline.addItem")
                }
            }
            .sheet(isPresented: $showingNewItem) { PipelineItemEditor(pipeline: selectedPipeline) }
            .sheet(isPresented: $showingNewPipeline) { NewPipelineView() }
            .sheet(isPresented: $showingFilters) { PipelineFiltersView(filter: $filter, pipeline: selectedPipeline, organizations: organizations) }
            .sheet(isPresented: $showingStageEditor) { if let selectedPipeline { PipelineStageEditor(pipeline: selectedPipeline) } }
            .task {
                do {
                    let service = PipelineService()
                    let fallback = try service.migrateExistingData(in: modelContext)
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--echo-agentic-demo") {
                        try service.seedAcceptanceScenario(in: modelContext)
                        let seededDeals = try modelContext.fetch(FetchDescriptor<Deal>())
                        selectedPipelineID = seededDeals.first(where: { $0.humanNotes == "echo.agentic.acceptance" })?.pipeline?.id ?? fallback.id
                    } else if selectedPipelineID == nil {
                        selectedPipelineID = fallback.id
                    }
                    #else
                    if selectedPipelineID == nil { selectedPipelineID = fallback.id }
                    #endif
                }
                catch { errorMessage = "Pipeline data could not be prepared: \(error.localizedDescription)" }
            }
            .alert("Pipeline", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }
    }

    private var compactLayout: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                PipelineSummary(items: allPipelineItems, usesMonetaryValue: selectedPipeline?.usesMonetaryValue == true)
                attentionSection
                if items.isEmpty {
                ContentUnavailableView("No matching items", systemImage: "rectangle.3.group", description: Text("Adjust filters or add a business opportunity."))
                        .frame(minHeight: 240)
                } else {
                    ForEach(stages) { stage in
                        let stageItems = items.filter { $0.stageIdentifier == stage.id }
                        if !stageItems.isEmpty { PipelineStageSection(stage: stage, items: stageItems) }
                    }
                }
            }.padding()
        }
    }

    private var regularLayout: some View {
        VStack(spacing: 0) {
            PipelineSummary(items: allPipelineItems, usesMonetaryValue: selectedPipeline?.usesMonetaryValue == true).padding([.horizontal, .top])
            attentionSection
                .padding(.horizontal)
                .padding(.top, 12)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(stages) { stage in
                        PipelineColumn(stage: stage, items: items.filter { $0.stageIdentifier == stage.id })
                    }
                }.padding()
            }
        }
    }

    @ViewBuilder private var attentionSection: some View {
        let attention = allPipelineItems.filter(\.humanAttentionRequired)
        if !attention.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Human Attention", systemImage: "person.crop.circle.badge.exclamationmark").font(.title3.bold()).foregroundStyle(.indigo)
                Text("Items that need a human decision or a direct commercial follow-up.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(attention.prefix(3)) { PipelineItemCard(item: $0) }
                if attention.count > 3 { Button("Show all \(attention.count)") { filter.humanAttentionOnly = true } }
            }.padding(16).background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 20)).accessibilityIdentifier("pipeline.humanAttention")
        }
    }

    private var pipelineMenu: some View {
        Menu {
            ForEach(activePipelines) { pipeline in
                Button { selectedPipelineID = pipeline.id; filter = PipelineFilter() } label: {
                    if pipeline.id == selectedPipeline?.id { Label(pipeline.name, systemImage: "checkmark") } else { Text(pipeline.name) }
                }
            }
            Divider()
            Button { showingStageEditor = true } label: { Label("Edit stages", systemImage: "slider.horizontal.3") }
                .disabled(selectedPipeline == nil)
                .accessibilityIdentifier("pipeline.editStages")
            Button { showingNewPipeline = true } label: { Label("New pipeline", systemImage: "plus") }
        } label: { Image(systemName: "rectangle.3.group.fill") }.accessibilityLabel("Choose pipeline")
    }
    private var hasActiveFilter: Bool { filter.stageIdentifier != nil || filter.humanAttentionOnly || filter.priority != nil || filter.organizationID != nil || filter.nextAction != .any }
}

private struct PipelineSummary: View {
    let items: [Deal]; let usesMonetaryValue: Bool
    private var active: [Deal] { items.filter { $0.status == .active || $0.status == .paused } }
    private var overdue: Int { active.filter { ($0.nextActionDate ?? .distantFuture) < Calendar.current.startOfDay(for: .now) }.count }
    private var shouldShowValue: Bool { usesMonetaryValue || active.contains(where: \.hasMonetaryValue) }
    var body: some View {
        HStack(spacing: 8) {
            metric("Active", "\(active.count)", "circle.dashed")
            metric("Attention", "\(active.filter(\.humanAttentionRequired).count)", "person.crop.circle.badge.exclamationmark")
            metric("Overdue", "\(overdue)", "calendar.badge.exclamationmark")
            if shouldShowValue { metric("Value", active.filter(\.hasMonetaryValue).reduce(0) { $0 + $1.value }.formatted(.currency(code: active.first?.resolvedCurrency ?? "USD").precision(.fractionLength(0))), "chart.line.uptrend.xyaxis") }
        }.padding(14).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Image(systemName: symbol).font(.caption).foregroundStyle(.indigo); Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.65); Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PipelineStageSection: View {
    let stage: PipelineStageDefinition; let items: [Deal]
    var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { Label(stage.displayTitle, systemImage: stage.symbol).font(.headline); Spacer(); Text("\(items.count)").pipelineCount() }; ForEach(items) { PipelineItemCard(item: $0) } } }
}

private struct PipelineColumn: View {
    let stage: PipelineStageDefinition; let items: [Deal]
    var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { Label(stage.displayTitle, systemImage: stage.symbol).font(.headline); Spacer(); Text("\(items.count)").pipelineCount() }; ForEach(items) { PipelineItemCard(item: $0) }; if items.isEmpty { Text("No items").foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.vertical, 24).pipelineSurface() } }.frame(width: 290) }
}

private struct PipelineItemCard: View {
    let item: Deal
    var body: some View {
        NavigationLink { PipelineItemDetailView(item: item) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) { Text(item.title).font(.headline).foregroundStyle(.primary); Spacer(); if item.humanAttentionRequired { Image(systemName: "person.crop.circle.badge.exclamationmark").foregroundStyle(.indigo) } }
                if let organization = item.organization { Text(organization.name).font(.subheadline).foregroundStyle(.secondary) }
                if let contact = item.contact { Label(contact.fullName, systemImage: "person.fill").font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 8) { Text(item.stageDefinition.displayTitle).font(.caption.bold()).foregroundStyle(.secondary); Text(localizedPipelineValue(item.priority.title)).font(.caption.bold()).foregroundStyle(item.priority == .urgent ? .red : .indigo); if let score = item.intelligence?.score { Label("\(score)", systemImage: "sparkles").font(.caption.bold()) }; if item.hasMonetaryValue { Text(item.value, format: .currency(code: item.resolvedCurrency).precision(.fractionLength(0))).font(.caption.bold()) } }
                if let summary = item.intelligence?.summary, !summary.isEmpty { Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                if let date = item.nextActionDate { Label { Text(date, format: .dateTime.month().day()) } icon: { Image(systemName: "calendar") }.font(.caption).foregroundStyle(date < .now ? .red : .secondary) }
                if let note = item.nextActionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    Label(note, systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }.pipelineSurface()
        }.buttonStyle(.plain)
    }
}

struct PipelineItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Interaction.date, order: .reverse) private var interactions: [Interaction]
    @Bindable var item: Deal
    @State private var showingEditor = false; @State private var showingIntelligence = false; @State private var showingOutreach = false
    @State private var isAnalyzing = false; @State private var isResearching = false; @State private var errorMessage: String?
    private var relevantInteractions: [Interaction] { interactions.filter { interaction in interaction.pipelineItem === item || interaction.organization === item.organization || item.allContacts.contains { $0 === interaction.contact } } }
    private var timeline: [PipelineTimelineEntry] {
        let communication = relevantInteractions.map { PipelineTimelineEntry(id: "i-\($0.persistentModelID)", date: $0.date, symbol: $0.type.symbol, title: localizedPipelineValue($0.type.title), detail: $0.summary, origin: localizedPipelineValue($0.actor.title)) }
        let actions = item.agentActions.map { PipelineTimelineEntry(id: "a-\($0.id)", date: $0.timestamp, symbol: $0.actionType == .escalation ? "person.crop.circle.badge.exclamationmark" : "sparkles", title: $0.summary, detail: $0.details ?? "", origin: "\($0.source ?? String(localized: "Agent")) · \(localizedPipelineValue($0.status.title))") }
        let humanNote = item.humanNotes.flatMap { note in
            note.isEmpty ? nil : PipelineTimelineEntry(id: "n-\(item.persistentModelID)", date: item.updatedAt ?? item.createdAt, symbol: "note.text", title: String(localized: "Human note"), detail: note, origin: String(localized: "Human"))
        }
        return (communication + actions + [humanNote].compactMap { $0 }).sorted { $0.date > $1.date }
    }
    var body: some View {
        List {
            Section("Overview") {
                Picker("Stage", selection: Binding(get: { item.stageIdentifier }, set: { transition(to: $0) })) { ForEach(item.pipeline?.stageDefinitions ?? DealStage.defaultAgenticStages.map { PipelineStageDefinition(identifier: $0.rawValue) }) { Text($0.displayTitle).tag($0.id) } }
                LabeledContent("Priority", value: localizedPipelineValue(item.priority.title))
                if let organization = item.organization { NavigationLink("Organization · \(organization.name)") { OrganizationDetailView(organization: organization) } }
                if let contact = item.contact { NavigationLink("Primary contact · \(contact.fullName)") { ContactDetailView(contact: contact) } }
                if item.hasMonetaryValue { LabeledContent("Value", value: item.value.formatted(.currency(code: item.resolvedCurrency))) }
                if let date = item.nextActionDate {
                    LabeledContent("Next action") { Text(date, style: .date) }
                }
                if let note = item.nextActionNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    LabeledContent("Action details") {
                        Text(note)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Toggle("Human Attention", isOn: Binding(get: { item.humanAttentionRequired }, set: { setAttention($0) })).tint(.indigo).accessibilityIdentifier("pipeline.detail.attention")
            }
            Section { if let intelligence = item.intelligence { intelligenceContent(intelligence); Button("Edit AI intelligence") { showingIntelligence = true } } else { Text("No AI intelligence yet").foregroundStyle(.secondary); Button("Add intelligence record") { showingIntelligence = true } } } header: { Label("AI Intelligence", systemImage: "sparkles").accessibilityIdentifier("pipeline.detail.ai") }
            Section {
                Button { analyze() } label: {
                    if isAnalyzing { HStack { ProgressView(); Text("Analyzing with DeepSeek…") } }
                    else { Label("Analyze with DeepSeek", systemImage: "sparkles") }
                }.disabled(isAnalyzing || isResearching)
                Button { researchWebsite() } label: {
                    if isResearching { HStack { ProgressView(); Text("Reading organization website…") } }
                    else { Label("Research organization website", systemImage: "globe") }
                }.disabled(isAnalyzing || isResearching || item.organization == nil)
                Button { showingOutreach = true } label: { Label("Prepare email", systemImage: "envelope") }
                    .disabled(item.contact?.emailAddress?.isEmpty != false)
            } header: {
                Label("Agent workspace", systemImage: "cpu")
            } footer: {
                Text("Research stores its source. DeepSeek updates only AI intelligence. Email is sent only after a separate review and confirmation.")
            }
            Section("People") { if item.allContacts.isEmpty { Text("No people linked").foregroundStyle(.secondary) }; ForEach(item.allContacts) { contact in NavigationLink(contact.fullName) { ContactDetailView(contact: contact) } } }
            Section { if timeline.isEmpty { Text("No activity yet").foregroundStyle(.secondary) }; ForEach(timeline) { entry in HStack(alignment: .top, spacing: 12) { Image(systemName: entry.symbol).foregroundStyle(.indigo).frame(width: 22); VStack(alignment: .leading, spacing: 3) { Text(entry.title).font(.subheadline.bold()); if !entry.detail.isEmpty { Text(entry.detail).font(.subheadline).foregroundStyle(.secondary) }; Text("\(entry.origin) · \(entry.date.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.tertiary) } } } } header: { Text("Timeline").accessibilityIdentifier("pipeline.detail.timeline") }
        }.navigationTitle(item.title).navigationBarTitleDisplayMode(.inline).toolbar { Button("Edit") { showingEditor = true } }
            .sheet(isPresented: $showingEditor) { PipelineItemEditor(pipeline: item.pipeline, item: item) }.sheet(isPresented: $showingIntelligence) { IntelligenceEditor(item: item) }
            .sheet(isPresented: $showingOutreach) { PipelineOutreachView(item: item) }
            .alert("Pipeline", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }
    }
    @ViewBuilder private func intelligenceContent(_ value: AgentIntelligence) -> some View {
        HStack { if let score = value.score { Label("Score \(score)", systemImage: "gauge.with.dots.needle.67percent").accessibilityIdentifier("pipeline.detail.score") }; Spacer(); Text("AI generated").font(.caption).foregroundStyle(.secondary) }
        if let text = value.summary, !text.isEmpty { LabeledContent("Summary") { Text(text).multilineTextAlignment(.trailing) } }
        if let text = value.whyItMatters, !text.isEmpty { LabeledContent("Why it matters") { Text(text).multilineTextAlignment(.trailing) } }
        if let text = value.recommendedNextAction, !text.isEmpty { LabeledContent("Recommended next") { Text(text).multilineTextAlignment(.trailing) } }
        if let text = value.riskNotes, !text.isEmpty { LabeledContent("Risks / uncertainty") { Text(text).multilineTextAlignment(.trailing) } }
        ForEach(value.evidence) { evidence in if let raw = evidence.url, let url = URL(string: raw) { Link(destination: url) { Label(evidence.title, systemImage: "link") } } else { Label(evidence.title, systemImage: "doc.text") } }
    }
    private func transition(to stageIdentifier: String) { do { try PipelineService().transition(item, toStageIdentifier: stageIdentifier, in: modelContext) } catch { errorMessage = error.localizedDescription } }
    private func setAttention(_ required: Bool) { do { try PipelineService().setHumanAttention(required, for: item, in: modelContext) } catch { errorMessage = error.localizedDescription } }
    private func analyze() {
        isAnalyzing = true
        Task {
            defer { isAnalyzing = false }
            do {
                let service = DeepSeekPipelineAgentService(features: try EchoAIEnvironment.features())
                try await service.evaluate(item: item, in: modelContext)
            } catch { errorMessage = EchoAIEnvironment.message(for: error) }
        }
    }
    private func researchWebsite() {
        isResearching = true
        Task {
            defer { isResearching = false }
            do { try await PipelineResearchCoordinator().research(item: item, provider: WebsiteResearchProvider(), in: modelContext) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

private struct PipelineTimelineEntry: Identifiable { let id: String; let date: Date; let symbol: String; let title: String; let detail: String; let origin: String }

struct OrganizationDetailView: View {
    @Query(sort: \Interaction.date, order: .reverse) private var interactions: [Interaction]
    let organization: Organization
    private var recent: [Interaction] { interactions.filter { interaction in interaction.organization === organization || organization.contacts.contains { $0 === interaction.contact } }.prefix(5).map { $0 } }
    var body: some View {
        List {
            Section("Organization") { LabeledContent("Name", value: organization.name); if let industry = organization.industry, !industry.isEmpty { LabeledContent("Industry", value: industry) }; if let location = organization.location, !location.isEmpty { LabeledContent("Location", value: location) }; if let raw = organization.website, let url = URL(string: raw) { Link("Open website", destination: url) }; if let notes = organization.notes, !notes.isEmpty { Text(notes) } }
            Section("People") { if organization.contacts.isEmpty { Text("No people linked").foregroundStyle(.secondary) }; ForEach(organization.contacts) { contact in NavigationLink(contact.fullName) { ContactDetailView(contact: contact) } } }
            Section("Active items") { let active = organization.pipelineItems.filter { $0.status == .active || $0.status == .paused }; if active.isEmpty { Text("No active items").foregroundStyle(.secondary) }; ForEach(active) { item in NavigationLink { PipelineItemDetailView(item: item) } label: { VStack(alignment: .leading, spacing: 3) { Text(item.title); if let summary = item.intelligence?.summary, !summary.isEmpty { Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2) } } } } }
            Section("Recent business activity") { if recent.isEmpty { Text("No recent activity").foregroundStyle(.secondary) }; ForEach(recent) { interaction in LabeledContent(localizedPipelineValue(interaction.type.title), value: interaction.date.formatted(date: .abbreviated, time: .omitted)) } }
        }.navigationTitle(organization.name)
    }
}

private struct NewPipelineView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    @State private var name = ""; @State private var objective = ""; @State private var autonomy: AgentAutonomyLevel = .assist
    @State private var agentEnabled = false; @State private var usesValue = false; @State private var errorMessage: String?
    var body: some View {
        NavigationStack { Form { Section("Purpose") { TextField("Pipeline name", text: $name); TextField("Objective", text: $objective, axis: .vertical) }; Section("Agent") { Toggle("Enable agent foundation", isOn: $agentEnabled); Picker("Authority", selection: $autonomy) { ForEach(AgentAutonomyLevel.allCases) { Text(localizedPipelineValue($0.title)).tag($0) } }; Text(localizedPipelineValue(autonomy.explanation)).font(.caption).foregroundStyle(.secondary) }; Section("Metrics") { Toggle("Track monetary value", isOn: $usesValue) } }.navigationTitle("New pipeline").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Create", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.alert("Could not create pipeline", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") } }
    }
    private func save() { let value = Pipeline(name: name.trimmingCharacters(in: .whitespacesAndNewlines), objective: objective, agentEnabled: agentEnabled, autonomyLevel: autonomy, usesMonetaryValue: usesValue); modelContext.insert(value); do { try modelContext.save(); dismiss() } catch { errorMessage = error.localizedDescription } }
}

private struct PipelineFiltersView: View {
    @Environment(\.dismiss) private var dismiss; @Binding var filter: PipelineFilter
    let pipeline: Pipeline?; let organizations: [Organization]
    var body: some View {
        NavigationStack { Form { Toggle("Human Attention only", isOn: $filter.humanAttentionOnly); Picker("Stage", selection: $filter.stageIdentifier) { Text("All stages").tag(String?.none); ForEach(pipeline?.stageDefinitions ?? DealStage.defaultAgenticStages.map { PipelineStageDefinition(identifier: $0.rawValue) }) { Text($0.displayTitle).tag(Optional($0.id)) } }; Picker("Priority", selection: $filter.priority) { Text("All priorities").tag(WorkPriority?.none); ForEach(WorkPriority.allCases) { Text(localizedPipelineValue($0.title)).tag(Optional($0)) } }; Picker("Organization", selection: $filter.organizationID) { Text("All organizations").tag(UUID?.none); ForEach(organizations) { Text($0.name).tag(Optional($0.id)) } }; Picker("Next action", selection: $filter.nextAction) { ForEach(NextActionFilter.allCases) { Text(localizedPipelineValue($0.title)).tag($0) } }; Button("Reset filters") { filter = PipelineFilter() } }.navigationTitle("Filters").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } } }
    }
}

struct PipelineItemEditor: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]; @Query(sort: \Organization.name) private var organizations: [Organization]
    @Query(sort: \Pipeline.createdAt) private var pipelines: [Pipeline]
    let pipeline: Pipeline?; let item: Deal?
    @State private var title: String; @State private var stageIdentifier: String; @State private var priority: WorkPriority
    @State private var organizationID: UUID?; @State private var contactID: String?; @State private var relatedIDs: Set<String>
    @State private var hasValue: Bool; @State private var value: Double; @State private var currency: String
    @State private var hasNextAction: Bool; @State private var nextActionDate: Date; @State private var nextActionNote: String; @State private var notes: String
    @State private var attention: Bool; @State private var errorMessage: String?; @State private var showingNewOrganization = false
    init(pipeline: Pipeline?, item: Deal? = nil, presetContact: EchoContact? = nil) {
        self.pipeline = pipeline; self.item = item
        _title = State(initialValue: item?.title ?? ""); _stageIdentifier = State(initialValue: item?.stageIdentifier ?? pipeline?.stageDefinitions.first?.id ?? DealStage.discovered.rawValue); _priority = State(initialValue: item?.priority ?? .medium)
        _organizationID = State(initialValue: item?.organization?.id ?? presetContact?.organization?.id); _contactID = State(initialValue: item?.contact?.systemIdentifier ?? presetContact?.systemIdentifier); _relatedIDs = State(initialValue: Set(item?.relatedContacts.map(\.systemIdentifier) ?? (presetContact.map { [$0.systemIdentifier] } ?? [])))
        _hasValue = State(initialValue: item?.hasMonetaryValue ?? pipeline?.usesMonetaryValue == true); _value = State(initialValue: item?.value ?? 0); _currency = State(initialValue: item?.resolvedCurrency ?? "USD")
        _hasNextAction = State(initialValue: item?.nextActionDate != nil); _nextActionDate = State(initialValue: item?.nextActionDate ?? Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now); _nextActionNote = State(initialValue: item?.nextActionNote ?? "")
        _notes = State(initialValue: item?.humanNotes ?? ""); _attention = State(initialValue: item?.humanAttentionRequired ?? false)
    }
    var body: some View {
        NavigationStack { Form {
            Section("Work item") { TextField("Title", text: $title); Picker("Stage", selection: $stageIdentifier) { ForEach(pipeline?.stageDefinitions ?? DealStage.defaultAgenticStages.map { PipelineStageDefinition(identifier: $0.rawValue) }) { Text($0.displayTitle).tag($0.id) } }; Picker("Priority", selection: $priority) { ForEach(WorkPriority.allCases) { Text(localizedPipelineValue($0.title)).tag($0) } }; Toggle("Human Attention", isOn: $attention) }
            Section("Organization and people") { Picker("Organization", selection: $organizationID) { Text("No organization").tag(UUID?.none); ForEach(organizations) { Text($0.name).tag(Optional($0.id)) } }; Button { showingNewOrganization = true } label: { Label("New organization", systemImage: "building.2.crop.circle") }; Picker("Primary contact", selection: $contactID) { Text("No primary contact").tag(String?.none); ForEach(contacts) { Text($0.fullName).tag(Optional($0.systemIdentifier)) } }; NavigationLink("Related people · \(relatedIDs.count)") { ContactMultiSelectView(selection: $relatedIDs, contacts: contacts) } }
            Section("Next step") {
                Toggle("Set next action", isOn: $hasNextAction)
                if hasNextAction {
                    DatePicker("Date", selection: $nextActionDate, displayedComponents: [.date])
                    TextField("Action details", text: $nextActionNote, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("pipeline.nextAction.note")
                }
            }
            Section("Value") { Toggle("Track value", isOn: $hasValue); if hasValue { TextField("Amount", value: $value, format: .number).keyboardType(.decimalPad); TextField("Currency", text: $currency).textInputAutocapitalization(.characters) } }
            Section("Human notes") { TextField("Notes written by you", text: $notes, prompt: Text("AI intelligence stays separate."), axis: .vertical) }
            if item != nil { Section { Button("Delete item", role: .destructive, action: delete) } }
        }.navigationTitle(item == nil ? "New item" : "Edit item").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.sheet(isPresented: $showingNewOrganization) { NewOrganizationView() }.alert("Pipeline", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") } }
    }
    private func save() {
        let organization = organizations.first { $0.id == organizationID }; let contact = contacts.first { $0.systemIdentifier == contactID }; let related = contacts.filter { relatedIDs.contains($0.systemIdentifier) }
        let target = item ?? Deal(title: title, pipeline: pipeline ?? pipelines.first); if item == nil { modelContext.insert(target) }
        let previousStageIdentifier = target.stageIdentifier
        let previousAttention = target.humanAttentionRequired
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines); target.priority = priority; target.organization = organization; target.contact = contact; target.relatedContacts = related
        if let organization { ([contact].compactMap { $0 } + related).forEach { if $0.organization == nil { $0.organization = organization } } }
        target.value = hasValue ? value : 0; target.valueIsSet = hasValue; target.currency = currency.uppercased(); target.nextActionDate = hasNextAction ? nextActionDate : nil; target.nextActionNote = hasNextAction ? nextActionNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil; target.humanNotes = notes.isEmpty ? nil : notes; target.updatedAt = .now
        do {
            if item == nil {
                target.stageIdentifier = stageIdentifier
                let stage = PipelineStageDefinition(identifier: stageIdentifier)
                target.status = stage.legacyStage == .won || stage.legacyStage == .closedWon ? .won : (stage.isClosed ? .lost : .active)
                target.humanAttentionRequired = attention
            } else {
                if previousStageIdentifier != stageIdentifier { try PipelineService().transition(target, toStageIdentifier: stageIdentifier, in: modelContext) }
                if previousAttention != attention { try PipelineService().setHumanAttention(attention, for: target, in: modelContext) }
            }
            try modelContext.save()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
    private func delete() { guard let item else { return }; modelContext.delete(item); do { try modelContext.save(); dismiss() } catch { errorMessage = error.localizedDescription } }
}

private struct NewOrganizationView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    @State private var name = ""; @State private var website = ""; @State private var industry = ""
    @State private var location = ""; @State private var notes = ""; @State private var errorMessage: String?
    var body: some View {
        NavigationStack { Form { Section("Identity") { TextField("Name", text: $name); TextField("Website", text: $website).textInputAutocapitalization(.never).keyboardType(.URL); TextField("Industry", text: $industry); TextField("Location", text: $location) }; Section("Notes") { TextField("What should you remember?", text: $notes, axis: .vertical) } }.navigationTitle("New organization").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Add", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.alert("Could not save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") } }
    }
    private func save() { let value = Organization(name: name.trimmingCharacters(in: .whitespacesAndNewlines), website: website.isEmpty ? nil : website, industry: industry.isEmpty ? nil : industry, location: location.isEmpty ? nil : location, notes: notes.isEmpty ? nil : notes); modelContext.insert(value); do { try modelContext.save(); dismiss() } catch { errorMessage = error.localizedDescription } }
}

private struct ContactMultiSelectView: View {
    @Binding var selection: Set<String>; let contacts: [EchoContact]
    var body: some View { List(contacts) { contact in Button { if selection.contains(contact.systemIdentifier) { selection.remove(contact.systemIdentifier) } else { selection.insert(contact.systemIdentifier) } } label: { HStack { Text(contact.fullName).foregroundStyle(.primary); Spacer(); if selection.contains(contact.systemIdentifier) { Image(systemName: "checkmark").foregroundStyle(.indigo) } } } }.navigationTitle("Related people") }
}

private struct IntelligenceEditor: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext; let item: Deal
    @State private var score: Int; @State private var summary: String; @State private var why: String; @State private var next: String; @State private var risks: String; @State private var errorMessage: String?
    init(item: Deal) { self.item = item; _score = State(initialValue: item.intelligence?.score ?? 50); _summary = State(initialValue: item.intelligence?.summary ?? ""); _why = State(initialValue: item.intelligence?.whyItMatters ?? ""); _next = State(initialValue: item.intelligence?.recommendedNextAction ?? ""); _risks = State(initialValue: item.intelligence?.riskNotes ?? "") }
    var body: some View { NavigationStack { Form { Section("AI assessment") { Stepper("Score · \(score)", value: $score, in: 0...100); TextField("Summary", text: $summary, axis: .vertical); TextField("Why it matters", text: $why, axis: .vertical); TextField("Recommended next action", text: $next, axis: .vertical); TextField("Risks or uncertainty", text: $risks, axis: .vertical) }; Section { Text("This record is separated from human notes. Enter only output from a real analysis; Echo does not claim research happened automatically.").font(.caption).foregroundStyle(.secondary) } }.navigationTitle("AI Intelligence").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) } }.alert("Could not save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") } } }
    private func save() { let value = item.intelligence ?? AgentIntelligence(pipelineItem: item); if item.intelligence == nil { modelContext.insert(value); item.intelligence = value }; value.score = score; value.summary = summary; value.whyItMatters = why; value.recommendedNextAction = next; value.riskNotes = risks; value.lastEvaluatedAt = .now; do { try modelContext.save(); dismiss() } catch { errorMessage = error.localizedDescription } }
}

private extension View { func pipelineSurface() -> some View { padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16)) } }
private extension Text { func pipelineCount() -> some View { font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4).background(.quaternary, in: Capsule()) } }
private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
