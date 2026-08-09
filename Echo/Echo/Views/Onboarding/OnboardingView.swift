import AuthenticationServices
import StoreKit
import SwiftData
import SwiftUI

/// Echo's first-run funnel moves through four deliberate phases:
/// self-assessment, account, product stories, and a transparent free trial.
/// Answers are stored locally and are used only to personalize Echo.
@MainActor
struct OnboardingView: View {
    let finish: () -> Void

    @Query private var contacts: [EchoContact]
    @StateObject private var subscription = EchoSubscriptionManager.shared

    @State private var step = 0
    @State private var answers: [FunnelQuestion: String] = [:]
    @State private var selectedPlan: EchoPlan = .annual
    @State private var isConnectingGoogle = false
    @State private var showingEmailSheet = false
    @State private var statusMessage: String?

    @AppStorage("echo.account.email") private var accountEmail = ""
    @AppStorage("echo.account.provider") private var accountProvider = ""
    @AppStorage("echo.account.displayName") private var accountDisplayName = ""
    @AppStorage("echo.account.identifier") private var accountIdentifier = ""
    @AppStorage("echo.onboarding.profile.answers") private var savedAnswers = ""

    private let totalSteps = 17

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.20), Color(.systemBackground), Color.purple.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    stepContent
                        .frame(maxWidth: .infinity, minHeight: 520, alignment: .top)
                        .padding(.horizontal, 22)
                        .padding(.top, 24)
                        .padding(.bottom, 18)
                }

                if showsBottomButton {
                    Button(action: advance) {
                        Text(bottomButtonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.indigo)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                    .disabled(!canAdvance)
                }
            }
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showingEmailSheet) {
            OnboardingEmailSheet { email, name in
                accountEmail = email
                accountDisplayName = name.isEmpty ? email : name
                accountProvider = "Email"
                accountIdentifier = email.lowercased()
                showingEmailSheet = false
            }
        }
        .alert("Echo", isPresented: Binding(
            get: { statusMessage != nil || subscription.message != nil },
            set: {
                if !$0 {
                    statusMessage = nil
                    subscription.message = nil
                }
            }
        )) {
            Button("OK") {
                statusMessage = nil
                subscription.message = nil
            }
        } message: {
            Text(statusMessage ?? subscription.message ?? "")
        }
        .task { await subscription.refresh() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                if step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.primary)
                } else {
                    Text("Echo")
                        .font(.headline.bold())
                }

                Spacer()

                Text(phaseTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)

            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(.indigo)
                .padding(.horizontal, 22)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            welcomeStep
        case 1...9:
            questionStep(FunnelQuestion.allCases[step - 1], number: step)
        case 10:
            impactStep
        case 11:
            accountStep
        case 12...15:
            featureStep(FeatureStory.all[step - 12], index: step - 12)
        default:
            subscriptionStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 22)

            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 82, weight: .semibold))
                .foregroundStyle(.indigo)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 12) {
                Text("The relationships you forget are often the ones you paid most to build.")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Nine honest questions will show where your time, trust, and opportunities are quietly leaking.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Label("About 90 seconds · Answers stay on this iPhone", systemImage: "lock.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.indigo)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.indigo.opacity(0.10), in: Capsule())
        }
    }

    private func questionStep(_ question: FunnelQuestion, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                Text("QUESTION \(number) OF 9")
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(.indigo)
                Text(question.title)
                    .font(.largeTitle.bold())
                Text(question.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 11) {
                ForEach(question.options) { option in
                    FunnelAnswerRow(
                        option: option,
                        isSelected: answers[question] == option.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            answers[question] = option.id
                        }
                    }
                }
            }
        }
    }

    private var impactStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                Text("YOUR RELATIONSHIP AUDIT")
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(.indigo)
                Text("Remembering late is more expensive than remembering early.")
                    .font(.largeTitle.bold())
                Text("These are your answers—not a generic prediction.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                AuditResultCard(
                    symbol: "person.2.fill",
                    value: selectedLabel(for: .followUpVolume),
                    caption: "important follow-ups competing for your attention each week",
                    color: .indigo
                )
                AuditResultCard(
                    symbol: "clock.fill",
                    value: selectedLabel(for: .searchTime),
                    caption: "spent searching for context before you can act",
                    color: .orange
                )
                if answers[.opportunityValue] != "no-business" {
                    AuditResultCard(
                        symbol: "dollarsign.circle.fill",
                        value: selectedLabel(for: .opportunityValue),
                        caption: "is the value you said one missed business follow-up can put at risk",
                        color: .green
                    )
                }
            }

            Text("Echo cannot guarantee an outcome. It can make the right person and the right context visible before the moment is gone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                Text("SAVE YOUR ECHO")
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(.indigo)
                Text("Keep your relationship plan attached to you.")
                    .font(.largeTitle.bold())
                Text("Sign in now so your Echo profile is ready for restore and future device sync. Contacts remain local unless you explicitly enable sync.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if accountProvider.isEmpty {
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signUp, onRequest: configureAppleRequest, onCompletion: handleAppleResult)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button(action: connectGoogle) {
                        HStack {
                            if isConnectingGoogle { ProgressView() }
                            Image(systemName: "g.circle.fill")
                            Text("Continue with Google")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .disabled(isConnectingGoogle)

                    Button("Use email instead") { showingEmailSheet = true }
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)
                }

                Text("Echo asks Google only for your basic identity here—not Gmail access. Email sync is a separate, optional permission in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(accountDisplayName.isEmpty ? accountEmail : accountDisplayName)
                            .font(.headline)
                        Text("Registered with \(accountProvider)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))

                Button("Use a different account") {
                    accountEmail = ""
                    accountProvider = ""
                    accountDisplayName = ""
                    accountIdentifier = ""
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func featureStep(_ story: FeatureStory, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("WHY ECHO · \(index + 1) OF \(FeatureStory.all.count)")
                    .font(.caption.bold())
                    .tracking(1.1)
                    .foregroundStyle(story.color)
                Spacer()
            }

            Image(systemName: story.symbol)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(story.color)
                .frame(width: 82, height: 82)
                .background(story.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))

            VStack(alignment: .leading, spacing: 10) {
                Text(story.title)
                    .font(.largeTitle.bold())
                Text(story.scene)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(story.color)
                Text(story.body)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(story.bullets, id: \.self) { bullet in
                    Label(bullet, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.primary)
                        .tint(story.color)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

            if index == 0, !contacts.isEmpty {
                Text("Echo already has \(contacts.count) people ready to organize on this device.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subscriptionStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR ECHO IS READY")
                    .font(.caption.bold())
                    .tracking(1.2)
                    .foregroundStyle(.indigo)
                Text("Try the system before you pay for it.")
                    .font(.largeTitle.bold())
                Text("For seven days, use the complete relationship copilot with your real people and real follow-ups.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 11) {
                paywallBenefit("A daily list of who matters—and why now")
                paywallBenefit("Evidence-led relationship health and insights")
                paywallBenefit("Personalized words when you choose to reach out")
                paywallBenefit("Business follow-up, card scan, and policy scan")
            }
            .padding(17)
            .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 10) {
                ForEach(EchoPlan.allCases) { plan in
                    Button { selectedPlan = plan } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedPlan == plan ? .indigo : .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(plan.title).font(.headline)
                                Text(plan.valueNote).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(subscription.product(for: plan)?.displayPrice ?? plan.fallbackPrice)
                                .font(.subheadline.bold())
                        }
                        .padding(14)
                        .background(selectedPlan == plan ? Color.indigo.opacity(0.11) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedPlan == plan ? Color.indigo.opacity(0.45) : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                startTrial()
            } label: {
                HStack {
                    if subscription.isLoading { ProgressView().tint(.white) }
                    Text(subscription.hasPremiumAccess ? "Continue to Echo" : primaryPaywallLabel)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.indigo)
            .disabled(subscription.isLoading)

            VStack(spacing: 5) {
                Text(subscription.storeKitIsConnected
                     ? "No charge today. On day 8, your selected plan renews at the price shown above unless you cancel before the trial ends."
                     : "This test build will enable preview access because App Store products are not available on this device yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Restore purchases") {
                    Task {
                        await subscription.restorePurchases()
                        if subscription.hasPremiumAccess { complete() }
                    }
                }
                .font(.caption.weight(.semibold))

                Text("Manage or cancel anytime in Apple ID Settings.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func paywallBenefit(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .symbolRenderingMode(.hierarchical)
            .tint(.green)
    }

    private var showsBottomButton: Bool { step < 16 }

    private var bottomButtonTitle: String {
        switch step {
        case 0: "Start my relationship audit"
        case 10: "Build my Echo"
        case 11: "Show me what Echo does"
        case 15: "See my free trial"
        default: step >= 12 ? "Next" : "Continue"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 1...9:
            answers[FunnelQuestion.allCases[step - 1]] != nil
        case 11:
            !accountProvider.isEmpty
        default:
            true
        }
    }

    private var phaseTitle: String {
        switch step {
        case 0...10: "Know what is slipping"
        case 11: "Create your account"
        case 12...15: "Meet your copilot"
        default: "Start your trial"
        }
    }

    private var primaryPaywallLabel: String {
        subscription.storeKitIsConnected
            ? "Start my 7-day free trial"
            : "Preview Echo Pro on this test build"
    }

    private func advance() {
        guard canAdvance else { return }
        if step == 10 { saveProfile() }
        withAnimation(.spring(duration: 0.42, bounce: 0.12)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func startTrial() {
        if subscription.hasPremiumAccess {
            complete()
            return
        }
        Task {
            await subscription.purchase(plan: selectedPlan)
            if subscription.hasPremiumAccess { complete() }
        }
    }

    private func complete() {
        saveProfile()
        finish()
    }

    private func saveProfile() {
        let values = Dictionary(uniqueKeysWithValues: answers.map { ($0.key.storageKey, $0.value) })
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else { return }
        savedAnswers = json
    }

    private func selectedLabel(for question: FunnelQuestion) -> String {
        guard let id = answers[question] else { return "Not answered" }
        return question.options.first(where: { $0.id == id })?.title ?? "Not answered"
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                statusMessage = "Apple returned an unexpected credential."
                return
            }
            accountIdentifier = credential.user
            if let email = credential.email { accountEmail = email }
            if accountEmail.isEmpty { accountEmail = "Apple private account" }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty { accountDisplayName = name }
            if accountDisplayName.isEmpty { accountDisplayName = accountEmail }
            accountProvider = "Apple"
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                statusMessage = "Apple sign-up could not be completed on this device. Try Google or email."
            }
        }
    }

    private func connectGoogle() {
        isConnectingGoogle = true
        Task {
            defer { isConnectingGoogle = false }
            do {
                let identity = try await GoogleIdentityService.shared.signIn()
                accountIdentifier = identity.identifier
                accountEmail = identity.email
                accountDisplayName = identity.name
                accountProvider = "Google"
            } catch {
                statusMessage = "Google sign-up was not completed. Try again or use Apple/email."
            }
        }
    }
}

private struct FunnelAnswerRow: View {
    let option: FunnelOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: option.symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .indigo)
                    .frame(width: 40, height: 40)
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
                    .foregroundStyle(isSelected ? .indigo : .secondary)
            }
            .padding(14)
            .background(isSelected ? Color.indigo.opacity(0.10) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(isSelected ? Color.indigo.opacity(0.38) : .clear))
        }
        .buttonStyle(.plain)
    }
}

private struct AuditResultCard: View {
    let symbol: String
    let value: String
    let caption: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(value).font(.headline)
                Text(caption).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct OnboardingEmailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var name = ""
    let onContinue: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Create your Echo account") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("Continue") {
                        onContinue(
                            email.trimmingCharacters(in: .whitespacesAndNewlines),
                            name.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    .disabled(!email.contains("@"))
                } footer: {
                    Text("This test build stores the email profile on this iPhone. Production email verification requires Echo's account backend.")
                }
            }
            .navigationTitle("Continue with email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct FunnelOption: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

private enum FunnelQuestion: Int, CaseIterable, Hashable {
    case followUpVolume
    case relationshipCost
    case mentalLoad
    case searchTime
    case opportunityValue
    case painfulMoment
    case desiredOutcome
    case preferredRhythm
    case readiness

    var storageKey: String { String(describing: self) }

    var title: String {
        switch self {
        case .followUpVolume: "How many important people do you mean to follow up with every week?"
        case .relationshipCost: "What has falling out of touch already cost you?"
        case .mentalLoad: "Where do your follow-ups live right now?"
        case .searchTime: "How much time disappears while you search chats, email, and notes for context?"
        case .opportunityValue: "If one business follow-up slips, what can realistically be at risk?"
        case .painfulMoment: "Which moment makes you feel you should have had a better system?"
        case .desiredOutcome: "What would one perfectly timed message create more often?"
        case .preferredRhythm: "How should Echo earn a place in your day?"
        case .readiness: "If Echo gives you ten focused minutes, what will you do with them?"
        }
    }

    var subtitle: String {
        switch self {
        case .followUpVolume: "Not everyone in your contacts—only the people you genuinely do not want to lose."
        case .relationshipCost: "The cost is not always money. Trust and timing compound too."
        case .mentalLoad: "If the system is your memory, every quiet week adds invisible pressure."
        case .searchTime: "Use your honest weekly estimate. Echo will never invent a savings claim."
        case .opportunityValue: "Choose your own range. This is used only for your private audit."
        case .painfulMoment: "The most painful miss usually reveals the feature you need first."
        case .desiredOutcome: "This tells Echo what kind of value to prioritize."
        case .preferredRhythm: "Useful enough to act on, quiet enough to trust."
        case .readiness: "A relationship system only works when the next step feels small."
        }
    }

    var options: [FunnelOption] {
        switch self {
        case .followUpVolume:
            [
                .init(id: "1-2", title: "1–2 people", detail: "A small circle, but every person matters.", symbol: "person.fill"),
                .init(id: "3-5", title: "3–5 people", detail: "Enough that memory alone starts to fail.", symbol: "person.2.fill"),
                .init(id: "6-10", title: "6–10 people", detail: "Important follow-ups compete every week.", symbol: "person.3.fill"),
                .init(id: "10+", title: "More than 10", detail: "Relationships are already an operating system for you.", symbol: "person.3.fill"),
            ]
        case .relationshipCost:
            [
                .init(id: "trust", title: "A relationship became colder", detail: "There was no conflict—just too much silence.", symbol: "heart.slash.fill"),
                .init(id: "opportunity", title: "I missed an opportunity", detail: "A referral, introduction, sale, or collaboration passed.", symbol: "arrow.down.right.circle.fill"),
                .init(id: "memory", title: "I forgot something that mattered", detail: "A promise, milestone, or personal detail arrived too late.", symbol: "brain.fill"),
            ]
        case .mentalLoad:
            [
                .init(id: "head", title: "Mostly in my head", detail: "I remember until life gets busy.", symbol: "brain.head.profile"),
                .init(id: "scattered", title: "Scattered across apps", detail: "Messages, email, notes, and calendar all hold pieces.", symbol: "square.grid.2x2.fill"),
                .init(id: "crm", title: "In a system I avoid opening", detail: "The tool creates more admin than clarity.", symbol: "tray.full.fill"),
            ]
        case .searchTime:
            [
                .init(id: "under-15", title: "Under 15 minutes a week", detail: "Context is usually close at hand.", symbol: "clock"),
                .init(id: "15-30", title: "15–30 minutes a week", detail: "Small searches keep interrupting action.", symbol: "clock.fill"),
                .init(id: "30-60", title: "30–60 minutes a week", detail: "Finding context is now a recurring task.", symbol: "hourglass"),
                .init(id: "60+", title: "More than an hour", detail: "The search itself is costing meaningful time.", symbol: "hourglass.bottomhalf.filled"),
            ]
        case .opportunityValue:
            [
                .init(id: "no-business", title: "My focus is personal", detail: "The value is trust, not a dollar amount.", symbol: "heart.fill"),
                .init(id: "under-1k", title: "Up to $1,000", detail: "Small opportunities still add up.", symbol: "dollarsign.circle"),
                .init(id: "1k-10k", title: "$1,000–$10,000", detail: "Timing can materially change the outcome.", symbol: "dollarsign.circle.fill"),
                .init(id: "10k+", title: "More than $10,000", detail: "A missed follow-up can be genuinely expensive.", symbol: "banknote.fill"),
            ]
        case .painfulMoment:
            [
                .init(id: "name", title: "I remembered the person, not the name", detail: "I could picture the conversation but could not find them.", symbol: "person.fill.questionmark"),
                .init(id: "promise", title: "I forgot a promise", detail: "I said I would follow up and realized too late.", symbol: "checkmark.bubble.fill"),
                .init(id: "timing", title: "I reached out after the moment passed", detail: "The right message arrived at the wrong time.", symbol: "clock.badge.exclamationmark"),
            ]
        case .desiredOutcome:
            [
                .init(id: "trust", title: "Stronger trust", detail: "People feel remembered without the effort feeling mechanical.", symbol: "hand.raised.heart.fill"),
                .init(id: "referrals", title: "More referrals and introductions", detail: "Warm relationships create natural opportunity.", symbol: "person.2.fill"),
                .init(id: "revenue", title: "More deals moving forward", detail: "Every conversation ends with a visible next step.", symbol: "chart.line.uptrend.xyaxis"),
                .init(id: "calm", title: "A calmer mind", detail: "I stop carrying every relationship in working memory.", symbol: "leaf.fill"),
            ]
        case .preferredRhythm:
            [
                .init(id: "daily", title: "A short daily plan", detail: "Show me the few people who matter today.", symbol: "sun.max.fill"),
                .init(id: "signal", title: "Only strong signals", detail: "Stay quiet until a relationship truly needs attention.", symbol: "wave.3.right"),
                .init(id: "business", title: "A business follow-up rhythm", detail: "Prioritize next actions, pipeline, and momentum.", symbol: "briefcase.fill"),
            ]
        case .readiness:
            [
                .init(id: "act", title: "I will send the message", detail: "Give me the person, context, and a strong opening.", symbol: "paperplane.fill"),
                .init(id: "review", title: "I will review and choose", detail: "Help me focus without deciding for me.", symbol: "checklist"),
                .init(id: "proof", title: "I need Echo to prove itself first", detail: "Show useful results before asking for commitment.", symbol: "sparkle.magnifyingglass"),
            ]
        }
    }
}

private struct FeatureStory {
    let symbol: String
    let color: Color
    let title: String
    let scene: String
    let body: String
    let bullets: [String]

    static let all: [FeatureStory] = [
        .init(
            symbol: "sun.max.fill",
            color: .orange,
            title: "Open Echo. Know who matters today.",
            scene: "Monday, 8:10 AM",
            body: "Instead of scanning hundreds of names, you see a short, ranked relationship brief built from timing, history, and your own priorities.",
            bullets: ["Daily personal and business priorities", "Why now, backed by visible evidence", "No noisy task list"]
        ),
        .init(
            symbol: "person.fill.questionmark",
            color: .blue,
            title: "Find the person whose name disappeared.",
            scene: "You remember the event, job, and conversation—just not the name.",
            body: "Describe the memory in your own words or by voice. Echo searches locally across notes, roles, companies, and interaction history.",
            bullets: ["Search by memory instead of exact name", "Voice input when the clue is easier to say", "Local results still work without AI"]
        ),
        .init(
            symbol: "message.fill",
            color: .indigo,
            title: "Reach out with context, not a generic template.",
            scene: "You decide to message someone after months of silence.",
            body: "Echo shows the relationship trend and drafts an opener only when you choose Message or Email. You stay in control of what is sent.",
            bullets: ["Relationship health with evidence", "Relevant personal or business context", "Editable words at the moment of action"]
        ),
        .init(
            symbol: "briefcase.fill",
            color: .green,
            title: "Turn relationships into visible next steps.",
            scene: "A prospect replies, a renewal approaches, or a card lands on your desk.",
            body: "Echo connects the person, conversation, opportunity, and next action—without becoming a heavy CRM.",
            bullets: ["Mobile-first pipeline and follow-up coaching", "Business-card and policy recognition", "Gmail metadata sync without downloading bodies"]
        ),
    ]
}

#Preview {
    OnboardingView(finish: {})
        .modelContainer(for: [EchoContact.self, Interaction.self, EchoNote.self, Deal.self], inMemory: true)
}
