import SwiftData
import SwiftUI

struct PipelineView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Deal.createdAt, order: .reverse) private var deals: [Deal]
    @State private var showingNewDeal = false

    private let visibleStages: [DealStage] = [.lead, .contacted, .quoted, .negotiating, .closedWon]

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(visibleStages) { stage in
                                PipelineColumn(stage: stage, deals: deals(for: stage))
                            }
                        }
                        .padding()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            PipelineSummary(deals: deals)

                            ForEach(visibleStages) { stage in
                                PipelineStageSection(stage: stage, deals: deals(for: stage))
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pipeline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewDeal = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNewDeal) { NewDealView() }
        }
    }

    private func deals(for stage: DealStage) -> [Deal] {
        deals.filter { $0.stage == stage }
    }
}

private struct PipelineSummary: View {
    let deals: [Deal]

    private var openDeals: [Deal] {
        deals.filter { $0.stage != .closedWon && $0.stage != .closedLost }
    }

    var body: some View {
        HStack(spacing: 12) {
            summaryItem(title: "Open deals", value: "\(openDeals.count)", symbol: "chart.line.uptrend.xyaxis")
            Divider().frame(height: 42)
            summaryItem(
                title: "Pipeline value",
                value: openDeals.reduce(0) { $0 + $1.value }.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                symbol: "dollarsign.circle.fill"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func summaryItem(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PipelineStageSection: View {
    let stage: DealStage
    let deals: [Deal]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(stage.title, systemImage: stage.symbol)
                    .font(.headline)
                Spacer()
                Text("\(deals.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 4)

            if deals.isEmpty {
                Text("No deals")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .foregroundStyle(.tertiary)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(deals) { deal in
                    DealCard(deal: deal)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PipelineColumn: View {
    let stage: DealStage
    let deals: [Deal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(stage.title, systemImage: stage.symbol).font(.headline)
                Spacer()
                Text("\(deals.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            ForEach(deals) { deal in DealCard(deal: deal) }
            if deals.isEmpty {
                Text("No deals")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .foregroundStyle(.tertiary)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(width: 270)
    }
}

private struct DealCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deal: Deal
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(deal.title).font(.headline)
            if let contact = deal.contact { Text(contact.fullName).font(.subheadline).foregroundStyle(.secondary) }
            Text(deal.value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.title3.weight(.semibold))
            if let nextActionDate = deal.nextActionDate {
                Label {
                    Text(nextActionDate, format: .dateTime.month().day())
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(nextActionDate < .now ? .red : .secondary)
            }
            Menu {
                Button {
                    showingEditor = true
                } label: {
                    Label("Edit details", systemImage: "pencil")
                }
                Divider()
                ForEach(DealStage.allCases) { stage in
                    Button(stage.title) {
                        deal.stage = stage
                        try? modelContext.save()
                    }
                }
            } label: {
                Label("Manage", systemImage: "ellipsis.circle")
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingEditor) {
            EditDealView(deal: deal)
        }
    }
}

struct NewDealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]
    @State private var title = ""
    @State private var value = 0.0
    @State private var stage: DealStage = .lead
    @State private var selectedContactIdentifier: String?
    @State private var hasNextAction = true
    @State private var nextActionDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now

    init(contact: EchoContact? = nil) {
        _selectedContactIdentifier = State(initialValue: contact?.systemIdentifier)
    }

    private var businessContacts: [EchoContact] {
        contacts.filter(\.isBusinessRelationship)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Opportunity") {
                    TextField("Deal name", text: $title)
                    TextField("Value", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Stage", selection: $stage) {
                        ForEach(DealStage.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Relationship") {
                    Picker("Contact", selection: $selectedContactIdentifier) {
                        Text("No contact").tag(String?.none)
                        ForEach(businessContacts) { contact in
                            Text(contact.fullName).tag(Optional(contact.systemIdentifier))
                        }
                    }
                    if businessContacts.isEmpty {
                        Text("Mark a person as Business or Both before linking an opportunity.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Next step") {
                    Toggle("Set next action", isOn: $hasNextAction)
                    if hasNextAction {
                        DatePicker(
                            "Date",
                            selection: $nextActionDate,
                            displayedComponents: [.date]
                        )
                    }
                }
            }
            .navigationTitle("New deal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let contact = businessContacts.first {
                            $0.systemIdentifier == selectedContactIdentifier
                        }
                        modelContext.insert(Deal(
                            title: title.trimmed,
                            value: value,
                            stage: stage,
                            nextActionDate: hasNextAction ? nextActionDate : nil,
                            contact: contact
                        ))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct EditDealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EchoContact.givenName) private var contacts: [EchoContact]

    let deal: Deal
    @State private var title: String
    @State private var value: Double
    @State private var stage: DealStage
    @State private var selectedContactIdentifier: String?
    @State private var hasNextAction: Bool
    @State private var nextActionDate: Date
    @State private var confirmingDelete = false

    init(deal: Deal) {
        self.deal = deal
        _title = State(initialValue: deal.title)
        _value = State(initialValue: deal.value)
        _stage = State(initialValue: deal.stage)
        _selectedContactIdentifier = State(initialValue: deal.contact?.systemIdentifier)
        _hasNextAction = State(initialValue: deal.nextActionDate != nil)
        _nextActionDate = State(initialValue: deal.nextActionDate ?? .now)
    }

    private var eligibleContacts: [EchoContact] {
        contacts.filter {
            $0.isBusinessRelationship
                || $0.systemIdentifier == deal.contact?.systemIdentifier
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Opportunity") {
                    TextField("Deal name", text: $title)
                    TextField("Value", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Stage", selection: $stage) {
                        ForEach(DealStage.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Relationship") {
                    Picker("Contact", selection: $selectedContactIdentifier) {
                        Text("No contact").tag(String?.none)
                        ForEach(eligibleContacts) { contact in
                            Text(contact.fullName).tag(Optional(contact.systemIdentifier))
                        }
                    }
                }
                Section("Next step") {
                    Toggle("Set next action", isOn: $hasNextAction)
                    if hasNextAction {
                        DatePicker("Date", selection: $nextActionDate, displayedComponents: [.date])
                    }
                }
                Section {
                    Button("Delete deal", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
            .navigationTitle("Edit deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmed.isEmpty)
                }
            }
            .confirmationDialog("Delete this deal?", isPresented: $confirmingDelete) {
                Button("Delete deal", role: .destructive, action: deleteDeal)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        deal.title = title.trimmed
        deal.value = value
        deal.stage = stage
        deal.contact = eligibleContacts.first { $0.systemIdentifier == selectedContactIdentifier }
        deal.nextActionDate = hasNextAction ? nextActionDate : nil
        try? modelContext.save()
        dismiss()
    }

    private func deleteDeal() {
        modelContext.delete(deal)
        try? modelContext.save()
        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
