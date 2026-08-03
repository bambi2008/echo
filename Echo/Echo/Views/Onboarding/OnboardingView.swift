import SwiftData
import SwiftUI

/// The first-run flow is intentionally local-first: the user sees a useful
/// relationship preview before an account, API key, or cloud permission is
/// required. Later stages can add authentication and StoreKit without
/// changing the core app shell.
struct OnboardingView: View {
    let finish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [EchoContact]
    @State private var step = 0
    @State private var pain: OnboardingPain = .cooling
    @State private var focus: OnboardingFocus = .both
    @State private var cadence: OnboardingCadence = .thoughtful
    @State private var isImporting = false
    @State private var importMessage: String?

    @AppStorage("echo.onboarding.profile.pain") private var savedPain = OnboardingPain.cooling.rawValue
    @AppStorage("echo.onboarding.profile.focus") private var savedFocus = OnboardingFocus.both.rawValue
    @AppStorage("echo.onboarding.profile.cadence") private var savedCadence = OnboardingCadence.thoughtful.rawValue

    private let totalSteps = 6

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.20), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        stepContent
                    }
                    .frame(maxWidth: .infinity, minHeight: 500, alignment: .top)
                    .padding(.horizontal, 24)
                    .padding(.top, 26)
                }

                if step < totalSteps - 1 {
                    Button(action: advance) {
                        Text(step == 0 ? "Find my people" : "Continue")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.indigo)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .disabled(!canAdvance)
                }
            }
        }
        .alert("Contacts", isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
        .onAppear {
            pain = OnboardingPain(rawValue: savedPain) ?? .cooling
            focus = OnboardingFocus(rawValue: savedFocus) ?? .both
            cadence = OnboardingCadence(rawValue: savedCadence) ?? .thoughtful
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Echo")
                    .font(.headline.weight(.bold))
                Spacer()
                if step > 0 && step < totalSteps - 1 {
                    Button("Skip") { complete() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(.indigo)
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: painStep
        case 2: focusStep
        case 3: cadenceStep
        case 4: previewStep
        default: readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 20)
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(.indigo)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 12) {
                Text("Know who to reach out to today.")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Echo remembers the small details that keep important relationships alive.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("We’ll ask three quick questions, then build a private relationship preview on this iPhone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    private var painStep: some View {
        OnboardingChoiceStep(
            eyebrow: "Start with the problem",
            title: "What would Echo help you with first?",
            subtitle: "There is no wrong answer. This only changes what you see first.",
            selection: pain,
            options: OnboardingPain.allCases
        ) { pain = $0 }
    }

    private var focusStep: some View {
        OnboardingChoiceStep(
            eyebrow: "Make it personal",
            title: "Who matters most right now?",
            subtitle: "Echo can keep personal and business relationships together or separate.",
            selection: focus,
            options: OnboardingFocus.allCases
        ) { focus = $0 }
    }

    private var cadenceStep: some View {
        OnboardingChoiceStep(
            eyebrow: "Set the rhythm",
            title: "How do you like to stay in touch?",
            subtitle: "Echo will use this as a gentle baseline, not a rigid task list.",
            selection: cadence,
            options: OnboardingCadence.allCases
        ) { cadence = $0 }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your first Echo")
                    .font(.largeTitle.bold())
                Text("A private preview, calculated from the people already on this device.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            previewCard

            if contacts.isEmpty {
                Button {
                    importContacts()
                } label: {
                    HStack {
                        if isImporting { ProgressView() }
                        Label("Use my contacts to personalize this", systemImage: "person.crop.circle.badge.plus")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)

                Text("You can continue without importing. Echo will not send contact data anywhere during setup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("You can change these priorities anytime in Settings. Your raw contacts stay on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 32)
            Image(systemName: "sparkles")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.indigo)
                .symbolEffect(.bounce, value: step)

            VStack(spacing: 10) {
                Text("Your Echo is ready")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Continue privately on this iPhone. When you want sync or cloud AI, you can sign in with Apple, Google, or email.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Continue on this iPhone") { complete() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.indigo)

            Text("No account or API key is required to begin.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var previewCard: some View {
        let people = contacts.filter(\.isInEchoLayer)
        let businessCount = people.filter(\.isBusinessRelationship).count
        let cooling = people.filter { ($0.daysSinceContact ?? 365) >= 30 }.count
        let ranked = people.sorted { EchoEngine.attentionScore(for: $0) > EchoEngine.attentionScore(for: $1) }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "wave.3.right")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                    .frame(width: 42, height: 42)
                    .background(Color.indigo.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(people.isEmpty ? "Your people are waiting" : "Here’s what Echo sees")
                        .font(.headline)
                    Text(people.isEmpty ? "Import contacts to get a personalized first view." : "Built locally from \(people.count) people.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if people.isEmpty {
                Text("Once you import contacts, Echo will surface the relationships that deserve attention without making you manage a spreadsheet.")
                    .font(.body)
            } else {
                HStack(spacing: 12) {
                    PreviewMetric(value: "\(cooling)", label: "cooling")
                    PreviewMetric(value: "\(businessCount)", label: "business")
                    PreviewMetric(value: "\(min(people.count, 3))", label: "first picks")
                }

                ForEach(Array(ranked.prefix(3))) { contact in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.indigo.opacity(0.12))
                            .frame(width: 32, height: 32)
                            .overlay(Text(contact.initials).font(.caption.bold()).foregroundStyle(.indigo))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.fullName).font(.subheadline.bold())
                            Text(whyNow(for: contact))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.55)))
    }

    private var canAdvance: Bool {
        step != 0 || true
    }

    private func advance() {
        if step == 4 {
            saveProfile()
        }
        withAnimation(.spring(duration: 0.45, bounce: 0.18)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func complete() {
        saveProfile()
        finish()
    }

    private func saveProfile() {
        savedPain = pain.rawValue
        savedFocus = focus.rawValue
        savedCadence = cadence.rawValue
    }

    private func importContacts() {
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                let result = try await ContactImportService().importContacts(into: modelContext)
                importMessage = result.added == 0 && result.updated == 0
                    ? "No new contacts were found."
                    : "Added \(result.added) people and updated \(result.updated)."
            } catch {
                importMessage = "Contacts could not be imported yet. You can continue and try again later."
            }
        }
    }

    private func whyNow(for contact: EchoContact) -> String {
        if let days = contact.daysSinceContact, days > 30 { return "It has been \(days) days since you connected" }
        if contact.isBusinessRelationship { return contact.companyName ?? "Business relationship" }
        return contact.notes.first?.content ?? "A relationship worth keeping in the loop"
    }
}

private struct OnboardingChoiceStep<Option: OnboardingChoice>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let selection: Option
    let options: [Option]
    let onSelect: (Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo)
                    .tracking(1.2)
                Text(title)
                    .font(.largeTitle.bold())
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(options) { option in
                    OnboardingChoiceRow(
                        option: option,
                        isSelected: selection.id == option.id,
                        onSelect: { onSelect(option) }
                    )
                }
            }
        }
    }
}

private struct OnboardingChoiceRow<Option: OnboardingChoice>: View {
    let option: Option
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: option.symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .indigo)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? Color.indigo : Color.indigo.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(option.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.indigo : Color.secondary)
            }
            .padding(14)
            .background(isSelected ? Color.indigo.opacity(0.10) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.indigo.opacity(0.35) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private protocol OnboardingChoice: CaseIterable, Identifiable, Hashable {
    var title: String { get }
    var detail: String { get }
    var symbol: String { get }
}

private enum OnboardingPain: String, CaseIterable, Identifiable, Hashable, OnboardingChoice {
    case cooling, memory, business, names

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cooling: "Keep relationships warm"
        case .memory: "Remember what we talked about"
        case .business: "Stay on top of business follow-ups"
        case .names: "Find someone whose name I forgot"
        }
    }

    var detail: String {
        switch self {
        case .cooling: "Know who may need a thoughtful check-in."
        case .memory: "Capture small details before they disappear."
        case .business: "Turn conversations into clear next steps."
        case .names: "Search by the memory, not just the name."
        }
    }

    var symbol: String {
        switch self {
        case .cooling: "heart.fill"
        case .memory: "note.text"
        case .business: "briefcase.fill"
        case .names: "person.fill.questionmark"
        }
    }
}

private enum OnboardingFocus: String, CaseIterable, Identifiable, Hashable, OnboardingChoice {
    case personal, business, both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Personal relationships"
        case .business: "Business relationships"
        case .both: "Both, in their own lanes"
        }
    }

    var detail: String {
        switch self {
        case .personal: "Family, friends, mentors, and community."
        case .business: "Clients, partners, prospects, and colleagues."
        case .both: "Keep personal and business views separate when useful."
        }
    }

    var symbol: String {
        switch self {
        case .personal: "heart.fill"
        case .business: "briefcase.fill"
        case .both: "person.2.fill"
        }
    }
}

private enum OnboardingCadence: String, CaseIterable, Identifiable, Hashable, OnboardingChoice {
    case thoughtful, structured, urgent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thoughtful: "Gentle and thoughtful"
        case .structured: "A clear rhythm"
        case .urgent: "Only when something needs attention"
        }
    }

    var detail: String {
        switch self {
        case .thoughtful: "A few useful nudges, never a noisy task list."
        case .structured: "Show me who is drifting from their usual cadence."
        case .urgent: "Keep the app quiet unless the signal is strong."
        }
    }

    var symbol: String {
        switch self {
        case .thoughtful: "leaf.fill"
        case .structured: "calendar"
        case .urgent: "bell.badge.fill"
        }
    }
}

private struct PreviewMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnboardingView(finish: {})
        .modelContainer(for: [EchoContact.self, Interaction.self, EchoNote.self, Deal.self], inMemory: true)
}
