import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var hasImported: Bool
    var onImportComplete: (EchoContact?) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var phase: ImportPhase = .ready
    @State private var importProgress: Double = 0
    @State private var importedCount = 0
    @State private var errorMessage: String?
    enum ImportPhase { case ready, importing, done, denied }
    var body: some View {
        ZStack {
            EchoBackground()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: EchoTheme.spacing12) { ZStack { Circle().fill(EchoTheme.accent.opacity(0.06)).frame(width: 88, height: 88); Image(systemName: "person.2.arrow.2.squarepath").font(.system(size: 40, weight: .light)).foregroundStyle(EchoTheme.accent) }; Text("Import Your Contacts").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary); Text("One tap to see who you've been missing.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) }
                Spacer()
                Group { switch phase { case .ready: readyContent.transition(.opacity); case .importing: importingContent.transition(.opacity); case .done: doneContent.transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity)); case .denied: deniedContent.transition(.opacity) } }.animation(.spring(duration: 0.4, bounce: 0.15), value: phase).padding(.horizontal, 32).padding(.bottom, 48)
            }
        }
    }
    private var readyContent: some View {
        VStack(spacing: EchoTheme.spacing24) {
            VStack(spacing: EchoTheme.spacing8) { HStack(spacing: EchoTheme.spacing8) { Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(EchoTheme.success); Text("Your contacts never leave your device.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) }; Text("Echo reads your address book to show who you haven't talked to. Nothing is uploaded — ever.").font(.caption).foregroundStyle(EchoTheme.textTertiary).multilineTextAlignment(.center) }
            Button { EchoHaptics.light(); Task { await startImport() } } label: { Text("Import Contacts").font(.headline).frame(maxWidth: .infinity).frame(height: 54) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent)
        }
    }
    private var importingContent: some View { VStack(spacing: EchoTheme.spacing16) { ProgressView(value: importProgress).progressViewStyle(.linear).tint(EchoTheme.accent); Text("Importing \(importedCount) contacts…").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) } }
    private var doneContent: some View {
        VStack(spacing: EchoTheme.spacing24) {
            ZStack { Circle().fill(EchoTheme.success.opacity(0.12)).frame(width: 72, height: 72); Image(systemName: "checkmark").font(.system(size: 28, weight: .semibold)).foregroundStyle(EchoTheme.success) }
            VStack(spacing: EchoTheme.spacing4) { Text("\(importedCount) contacts imported").font(.headline).foregroundStyle(EchoTheme.textPrimary); Text("Your top 15 are in your Echo Layer.\nTap one to reach out.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center) }
            Button { EchoHaptics.medium(); finishImport() } label: { Text("Enter Echo").font(.headline).frame(maxWidth: .infinity).frame(height: 54) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent)
        }
    }
    private var deniedContent: some View {
        VStack(spacing: EchoTheme.spacing24) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(.orange)
            VStack(spacing: EchoTheme.spacing4) { Text("Contacts Access Needed").font(.headline).foregroundStyle(EchoTheme.textPrimary); Text("Echo needs your contacts to work.\nYou can enable access in Settings.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center) }
            VStack(spacing: EchoTheme.spacing12) { Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: { Text("Open Settings").font(.headline).frame(maxWidth: .infinity).frame(height: 52) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent); Button("Try Again") { Task { await startImport() } }.foregroundStyle(EchoTheme.textSecondary) }
        }
    }
    private func startImport() async {
        withAnimation { phase = .importing }; importProgress = 0.2
        let service = ContactImportService(modelContext: modelContext)
        do { let count = try await service.importContacts(); importProgress = 0.7; importedCount = count; importProgress = 1.0; try? await Task.sleep(nanoseconds: 300_000_000); withAnimation { phase = .done } } catch ContactImportError.permissionDenied { withAnimation { phase = .denied } } catch { errorMessage = error.localizedDescription; withAnimation { phase = .denied } }
    }
    private func finishImport() {
        let descriptor = FetchDescriptor<EchoContact>(predicate: #Predicate { $0.isInEchoLayer }, sortBy: [SortDescriptor(\.lastReachedOut, order: .forward)]); let contacts = (try? modelContext.fetch(descriptor)) ?? []; let ahaContact = AhaMomentHelper.findMostOverdue(contacts: contacts)
        UserDefaults.standard.set(true, forKey: "echo_has_imported"); hasImported = true; onImportComplete(ahaContact)
    }
}
