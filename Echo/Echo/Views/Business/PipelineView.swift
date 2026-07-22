import SwiftData
import SwiftUI

struct PipelineView: View {
    @Query(sort: \Deal.createdAt, order: .reverse) private var deals: [Deal]
    @State private var showingNewDeal = false

    private let visibleStages: [DealStage] = [.lead, .contacted, .quoted, .negotiating, .closedWon]

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(visibleStages) { stage in
                        PipelineColumn(stage: stage, deals: deals.filter { $0.stage == stage })
                    }
                }
                .padding()
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
    @Bindable var deal: Deal

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(deal.title).font(.headline)
            if let contact = deal.contact { Text(contact.fullName).font(.subheadline).foregroundStyle(.secondary) }
            Text(deal.value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.title3.weight(.semibold))
            Menu {
                ForEach(DealStage.allCases) { stage in
                    Button(stage.title) { deal.stage = stage }
                }
            } label: {
                Label("Move", systemImage: "arrow.right.circle")
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct NewDealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var value = 0.0
    @State private var stage: DealStage = .lead

    var body: some View {
        NavigationStack {
            Form {
                TextField("Deal name", text: $title)
                TextField("Value", value: $value, format: .number).keyboardType(.decimalPad)
                Picker("Stage", selection: $stage) {
                    ForEach(DealStage.allCases) { Text($0.title).tag($0) }
                }
            }
            .navigationTitle("New deal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        modelContext.insert(Deal(title: title, value: value, stage: stage))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
