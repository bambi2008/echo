import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var hasImported: Bool
    var onImportComplete: (EchoContact?) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var phase: OnboardingPhase = .welcome
    @State private var importProgress: Double = 0
    @State private var importedCount = 0
    @State private var errorMessage: String?
    enum OnboardingPhase { case welcome, importing, done, denied }
    var body: some View {
        ZStack {
            EchoBackground()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: EchoTheme.spacing12) {
                    ZStack {
                        Circle().fill(EchoTheme.accent.opacity(0.06)).frame(width: 88, height: 88)
                        Image(systemName: "wave.3.right").font(.system(size: 40, weight: .light)).foregroundStyle(EchoTheme.accent).symbolEffect(.pulse, options: .repeating)
                    }
                    Text("Echo").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary)
                    Text("Stay in Touch").font(.subheadline).foregroundStyle(EchoTheme.textSecondary)
                }
                Spacer()
                Group {
                    switch phase {
                    case .welcome: welcomeContent.transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                    case .importing: importingContent.transition(.opacity)
                    case .done: doneContent.transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
                    case .denied: deniedContent.transition(.opacity)
                    }
                }
                .animation(.spring(duration: 0.4, bounce: 0.15), value: phase)
                .padding(.horizontal, 32).padding(.bottom, 48)
            }
        }
    }
    private var welcomeContent: some View {
        VStack(spacing: EchoTheme.spacing24) {
            VStack(spacing: EchoTheme.spacing4) {
                Text("念念不忘，必有回响").font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.textSecondary)
                Text("A whisper across time always finds its way back.").font(.caption).foregroundStyle(EchoTheme.textTertiary)
            }
            VStack(alignment: .leading, spacing: EchoTheme.spacing12) {
                featureRow(icon: "person.3.sequence", text: "Import your contacts in one tap")
                featureRow(icon: "hand.wave", text: "See who you haven't talked to in too long")
                featureRow(icon: "lock.fill", text: "Everything stays on your device")
            }
            .padding(.vertical, EchoTheme.spacing8)
            Button { EchoHaptics.light(); Task { await startImport() } } label: {
                Text("Import Contacts").font(.headline).frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(.borderedProminent).tint(EchoTheme.accent)
            Text("Your contacts never leave your device.").font(.caption).foregroundStyle(EchoTheme.textTertiary)
        }
    }
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: EchoTheme.spacing12) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(EchoTheme.accent).frame(width: 28, height: 28).background(EchoTheme.accent.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
            Text(text).foregroundStyle(EchoTheme.textSecondary).font(.subheadline)
        }
    }
    private var importingContent: some View {
        VStack(spacing: EchoTheme.spacing16) {
            ProgressView(value: importProgress).progressViewStyle(.linear).tint(EchoTheme.accent)
            Text("Importing \(importedCount) contacts…").font(.subheadline).foregroundStyle(EchoTheme.textSecondary)
        }
    }
    private var doneContent: some View {
        VStack(spacing: EchoTheme.spacing24) {
            ZStack { Circle().fill(EchoTheme.success.opacity(0.12)).frame(width: 72, height: 72); Image(systemName: "checkmark").font(.system(size: 28, weight: .semibold)).foregroundStyle(EchoTheme.success) }
            VStack(spacing: EchoTheme.spacing4) {
                Text("\(importedCount) contacts imported").font(.headline).foregroundStyle(EchoTheme.textPrimary)
                Text("Your top 15 are in your Echo Layer.\nTap one to reach out.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center)
            }
            Button { EchoHaptics.medium(); finishImport() } label: { Text("Get Started").font(.headline).frame(maxWidth: .infinity).frame(height: 52) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent)
        }
    }
    private var deniedContent: some View {
        VStack(spacing: EchoTheme.spacing24) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(.orange)
            VStack(spacing: EchoTheme.spacing4) {
                Text("Contacts Access Needed").font(.headline).foregroundStyle(EchoTheme.textPrimary)
                Text("Echo needs your contacts to work.\nYou can enable access in Settings.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center)
            }
            VStack(spacing: EchoTheme.spacing12) {
                Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: { Text("Open Settings").font(.headline).frame(maxWidth: .infinity).frame(height: 52) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent)
                Button("Try Again") { Task { await startImport() } }.foregroundStyle(EchoTheme.textSecondary)
            }
        }
    }
    private func startImport() async {
        withAnimation { phase = .importing }; importProgress = 0.2
        let service = ContactImportService(modelContext: modelContext)
        do { let count = try await service.importContacts(); importProgress = 0.7; importedCount = count; importProgress = 1.0; try? await Task.sleep(nanoseconds: 300_000_000); withAnimation { phase = .done } }
        catch ContactImportError.permissionDenied { withAnimation { phase = .denied } }
        catch { errorMessage = error.localizedDescription; withAnimation { phase = .denied } }
    }
    private func finishImport() {
        let descriptor = FetchDescriptor<EchoContact>(predicate: #Predicate { $0.isInEchoLayer }, sortBy: [SortDescriptor(\.lastReachedOut, order: .forward)])
        let contacts = (try? modelContext.fetch(descriptor)) ?? []
        let ahaContact = AhaMomentHelper.findMostOverdue(contacts: contacts)
        UserDefaults.standard.set(true, forKey: "echo_has_imported"); hasImported = true; onImportComplete(ahaContact)
    }
}
