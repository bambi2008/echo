import SwiftData
import SwiftUI

struct PipelineStageEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var pipeline: Pipeline
    @State private var drafts: [StageDraft]
    @State private var newStageName = ""
    @State private var errorMessage: String?

    @MainActor init(pipeline: Pipeline) {
        self.pipeline = pipeline
        _drafts = State(initialValue: pipeline.stageDefinitions.map(StageDraft.init(stage:)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($drafts) { $draft in
                        HStack(spacing: 10) {
                            Image(systemName: draft.symbol)
                                .foregroundStyle(.indigo)
                                .frame(width: 24)
                            TextField("Stage name", text: $draft.name)
                                .disabled(draft.isProtected)
                            Button { move(draft.id, offset: -1) } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(drafts.first?.id == draft.id)
                            Button { move(draft.id, offset: 1) } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(drafts.last?.id == draft.id)
                            Button(role: .destructive) { remove(draft.id) } label: {
                                Image(systemName: draft.isProtected ? "lock.fill" : "trash")
                            }
                            .buttonStyle(.borderless)
                            .disabled(draft.isProtected)
                        }
                    }
                } header: {
                    Text("Ordered stages")
                } footer: {
                    Text("Rename or reorder stages freely. Won and Lost remain protected so completed items keep a reliable outcome.")
                }

                Section("Add a stage") {
                    TextField("Example: Review", text: $newStageName)
                        .accessibilityIdentifier("pipeline.stage.newName")
                    Button("Add stage", action: add)
                        .disabled(newStageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("pipeline.stage.add")
                }
            }
            .navigationTitle("Pipeline stages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("pipeline.stage.save")
                }
            }
            .alert("Could not update stages", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func add() {
        let name = newStageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let insertionIndex = drafts.firstIndex(where: { $0.originalIdentifier == DealStage.won.rawValue }) ?? drafts.endIndex
        drafts.insert(StageDraft(name: name), at: insertionIndex)
        newStageName = ""
    }

    private func move(_ id: UUID, offset: Int) {
        guard let source = drafts.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard drafts.indices.contains(destination) else { return }
        drafts.swapAt(source, destination)
    }

    private func remove(_ id: UUID) {
        drafts.removeAll { $0.id == id && !$0.isProtected }
    }

    private func save() {
        let names = drafts.map(\.resolvedIdentifier)
        let renames: [String: String] = Dictionary(uniqueKeysWithValues: drafts.compactMap { draft -> (String, String)? in
            guard let original = draft.originalIdentifier, original != draft.resolvedIdentifier else { return nil }
            return (original, draft.resolvedIdentifier)
        })
        do {
            try PipelineService().updateStages(for: pipeline, orderedNames: names, renames: renames, in: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct StageDraft: Identifiable {
    let id = UUID()
    let originalIdentifier: String?
    let originalTitle: String?
    var name: String

    init(stage: PipelineStageDefinition) {
        originalIdentifier = stage.id
        originalTitle = stage.displayTitle
        name = stage.displayTitle
    }

    init(name: String) {
        originalIdentifier = nil
        originalTitle = nil
        self.name = name
    }

    var isProtected: Bool {
        originalIdentifier == DealStage.won.rawValue || originalIdentifier == DealStage.lost.rawValue
    }

    var resolvedIdentifier: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let originalIdentifier, trimmed == originalTitle { return originalIdentifier }
        return trimmed
    }

    var symbol: String {
        originalIdentifier.map { PipelineStageDefinition(identifier: $0).symbol } ?? "circle.fill"
    }
}
