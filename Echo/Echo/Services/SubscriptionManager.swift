import AuthenticationServices
import Combine
import StoreKit
import SwiftUI

enum EchoPlan: String, CaseIterable, Identifiable {
    case monthly = "com.bambi2008.echo.ai.pro.monthly"
    case annual = "com.bambi2008.echo.ai.pro.annual"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Monthly"
        case .annual: "Annual"
        }
    }

    var fallbackPrice: String {
        switch self {
        case .monthly: "$3.99 / month"
        case .annual: "$29.99 / year"
        }
    }

    var valueNote: String {
        switch self {
        case .monthly: "Flexible month to month"
        case .annual: "Best value · save about 37%"
        }
    }
}

@MainActor
final class EchoSubscriptionManager: ObservableObject {
    static let shared = EchoSubscriptionManager()

    private static let previewAccessKey = "echo.subscription.debugPreview"
    private static let productIDs = Set(EchoPlan.allCases.map(\.rawValue))

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var isLoading = false
    @Published var message: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            guard let self else { return }
            await observeTransactionUpdates()
        }
        Task { [weak self] in
            await self?.refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var storeKitIsConnected: Bool { !products.isEmpty }

    func product(for plan: EchoPlan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { left, right in
                    let leftRank = EchoPlan(rawValue: left.id) == .annual ? 1 : 0
                    let rightRank = EchoPlan(rawValue: right.id) == .annual ? 1 : 0
                    return leftRank < rightRank
                }
        } catch {
            products = []
            message = "Echo Pro is ready, but App Store products are not connected in this build yet."
        }

        await refreshEntitlements()
    }

    func purchase(plan: EchoPlan) async {
        guard let product = product(for: plan) else {
            #if DEBUG
            enableSimulatorPreview()
            #else
            message = "This plan is not available yet. Please try again after App Store products are connected."
            #endif
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
                message = "AI Pro is active on this Apple ID."
            case .success(.unverified):
                message = "Apple could not verify this purchase. Nothing was unlocked."
            case .userCancelled:
                message = "No changes were made."
            case .pending:
                message = "Purchase is waiting for approval."
            @unknown default:
                message = "The purchase could not be completed."
            }
        } catch {
            message = "The purchase could not be completed. Check your Apple ID and try again."
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = hasPremiumAccess
                ? "Your AI Pro access has been restored."
                : "No active Echo Pro purchase was found for this Apple ID."
        } catch {
            message = "Purchases could not be restored right now. Try again later."
        }
    }

    #if DEBUG
    func enableSimulatorPreview() {
        UserDefaults.standard.set(true, forKey: Self.previewAccessKey)
        hasPremiumAccess = true
        message = "Simulator preview enabled. Real purchases will use Apple StoreKit in production."
    }

    func resetSimulatorPreview() {
        UserDefaults.standard.removeObject(forKey: Self.previewAccessKey)
        hasPremiumAccess = !purchasedProductIDs.isEmpty
        message = "Simulator preview disabled."
    }
    #endif

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func refreshEntitlements() async {
        var active = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  Self.productIDs.contains(transaction.productID)
            else { continue }
            active.insert(transaction.productID)
        }
        purchasedProductIDs = active
        #if DEBUG
        hasPremiumAccess = !active.isEmpty || UserDefaults.standard.bool(forKey: Self.previewAccessKey)
        #else
        hasPremiumAccess = !active.isEmpty
        #endif
    }
}

@MainActor
struct EchoProView: View {
    @ObservedObject private var subscription: EchoSubscriptionManager
    @State private var selectedPlan: EchoPlan = .annual
    @State private var showingAccount = false

    init(subscription: EchoSubscriptionManager) {
        _subscription = ObservedObject(wrappedValue: subscription)
    }

    init() {
        self.init(subscription: .shared)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                benefits
                planPicker
                trialDisclosure

                Button {
                    Task { await subscription.purchase(plan: selectedPlan) }
                } label: {
                    HStack {
                        if subscription.isLoading { ProgressView().tint(.white) }
                        Text(subscription.hasPremiumAccess ? "AI Pro is active" : "Start my 7-day free trial")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.indigo)
                .disabled(subscription.isLoading || subscription.hasPremiumAccess)

                if !subscription.storeKitIsConnected {
                    Text("StoreKit products are not connected in this simulator build yet. The preview button below lets you inspect the complete value flow without starting a real charge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                }

                #if DEBUG
                if !subscription.hasPremiumAccess {
                    Button {
                        subscription.enableSimulatorPreview()
                    } label: {
                        Label("Preview AI Pro on this simulator", systemImage: "sparkles.rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else if !subscription.storeKitIsConnected {
                    Button("Reset simulator preview", role: .destructive) {
                        subscription.resetSimulatorPreview()
                    }
                    .frame(maxWidth: .infinity)
                }
                #endif

                HStack(spacing: 16) {
                    Button("Restore purchases") {
                        Task { await subscription.restorePurchases() }
                    }
                    .disabled(subscription.isLoading)
                    Button("Account") { showingAccount = true }
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)

                Text("Subscriptions renew automatically unless canceled at least 24 hours before the current period ends. You can manage or cancel in Apple ID Settings. The trial converts to the selected plan at the price shown by Apple.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Echo Pro")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAccount) { EchoAccountView() }
        .alert("Echo Pro", isPresented: Binding(
            get: { subscription.message != nil },
            set: { if !$0 { subscription.message = nil } }
        )) {
            Button("OK") { subscription.message = nil }
        } message: {
            Text(subscription.message ?? "")
        }
        .task { await subscription.refresh() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.indigo)
            Text("Keep the right relationships warm.")
                .font(.largeTitle.bold())
            Text("AI Pro turns the context already on this iPhone into a calm daily plan: who matters, why now, and what to say next.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(colors: [Color.indigo.opacity(0.18), Color.purple.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What you unlock", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.indigo)
            benefit("Relationship insight and health, ranked from the people who need attention")
            benefit("Daily briefing and sales follow-up advice grounded in your saved context")
            benefit("Personalized openers only when you choose Message or Email")
            benefit("Business-card and policy recognition with local-first privacy")
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func benefit(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.primary)
            .symbolRenderingMode(.hierarchical)
            .tint(.green)
    }

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose your plan")
                .font(.headline)
            ForEach(EchoPlan.allCases) { plan in
                Button { selectedPlan = plan } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedPlan == plan ? .indigo : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.title).font(.subheadline.bold())
                            Text(plan.valueNote).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(subscription.product(for: plan)?.displayPrice ?? plan.fallbackPrice)
                            .font(.subheadline.weight(.semibold))
                    }
                    .contentShape(Rectangle())
                    .padding(14)
                    .background(selectedPlan == plan ? Color.indigo.opacity(0.10) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedPlan == plan ? Color.indigo.opacity(0.45) : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trialDisclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("7-day free trial", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
            Text("You will not be charged during the trial. On day 8, the selected subscription renews at the price shown above unless you cancel in time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

@MainActor
struct EchoAccountView: View {
    @AppStorage("echo.account.email") private var accountEmail = ""
    @AppStorage("echo.account.provider") private var accountProvider = ""
    @AppStorage("echo.account.displayName") private var displayName = ""
    @State private var showingEmailSheet = false
    @State private var isConnectingGoogle = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if accountEmail.isEmpty {
                    Section {
                        SignInWithAppleButton(.signIn, onRequest: configureAppleRequest, onCompletion: handleAppleResult)
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 48)

                        Button {
                            connectGoogle()
                        } label: {
                            HStack {
                                if isConnectingGoogle { ProgressView() }
                                Label("Continue with Google", systemImage: "g.circle.fill")
                            }
                        }
                        .disabled(isConnectingGoogle)

                        Button("Continue with email") { showingEmailSheet = true }
                    } footer: {
                        Text("Use the same account on a future Echo device. Your contact records remain local unless you explicitly enable sync.")
                    }
                } else {
                    Section {
                        LabeledContent("Signed in as", value: displayName.isEmpty ? accountEmail : displayName)
                        LabeledContent("Provider", value: accountProvider)
                        Label("This build keeps your profile on this iPhone.", systemImage: "iphone.gen3")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        Button("Sign out", role: .destructive) {
                            accountEmail = ""
                            accountProvider = ""
                            displayName = ""
                        }
                    }
                }
            }
            .navigationTitle("Echo account")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEmailSheet) {
                EmailAccountSheet { email, name in
                    accountEmail = email
                    displayName = name
                    accountProvider = "Email"
                    showingEmailSheet = false
                    statusMessage = "Your private Echo profile is ready on this iPhone."
                }
            }
            .alert("Echo account", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK") { statusMessage = nil }
            } message: {
                Text(statusMessage ?? "")
            }
        }
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
            accountEmail = credential.email ?? "apple-user@privileged.local"
            displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            accountProvider = "Apple"
            statusMessage = "Signed in with Apple."
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                statusMessage = "Apple sign-in is not available in this simulator profile yet."
            }
        }
    }

    private func connectGoogle() {
        isConnectingGoogle = true
        Task {
            defer { isConnectingGoogle = false }
            do {
                let status = try await GmailSyncService.shared.connect()
                accountEmail = status.email
                displayName = status.email
                accountProvider = "Google"
                statusMessage = "Signed in with Google. Gmail sync can be enabled separately in Settings."
            } catch {
                statusMessage = "Google sign-in was not completed. You can try again or use Apple/email."
            }
        }
    }
}

private struct EmailAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var name = ""
    let onContinue: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Create your private profile") {
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
                        onContinue(email.trimmingCharacters(in: .whitespacesAndNewlines), name.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(!email.contains("@"))
                } footer: {
                    Text("Email sign-in is stored locally in this build. Cloud account verification will be added when Echo's sync backend is connected.")
                }
            }
            .navigationTitle("Email sign-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { EchoProView() }
}
