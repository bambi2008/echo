import SwiftUI

struct MilestoneSheet: View {
    let totalReach: Int
    let totalContacts: Int
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?
    var body: some View {
        NavigationStack {
            ZStack {
                EchoBackground()
                VStack(spacing: EchoTheme.spacing32) {
                    Spacer()
                    VStack(spacing: EchoTheme.spacing12) {
                        ZStack { Circle().fill(EchoTheme.accent.opacity(0.08)).frame(width: 80, height: 80); Image(systemName: "wave.3.right.fill").font(.system(size: 36, weight: .light)).foregroundStyle(EchoTheme.accent) }
                        Text("\(totalReach)").font(.system(size: 56, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary)
                        Text("reaches logged").font(.headline).foregroundStyle(EchoTheme.textSecondary)
                        Text("You're staying connected with \(totalContacts) people.").font(.subheadline).foregroundStyle(EchoTheme.textTertiary)
                    }
                    ShareCard(totalReach: totalReach, totalContacts: totalContacts).frame(width: 280).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)
                    if let url = shareURL {
                        ShareLink(item: url, preview: SharePreview("My Echo Stats")) { HStack(spacing: EchoTheme.spacing8) { Image(systemName: "square.and.arrow.up"); Text("Share My Stats") }.font(.headline).frame(maxWidth: .infinity).frame(height: 50) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).padding(.horizontal, 32)
                    }
                    Spacer()
                }
            }.navigationTitle("Milestone").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(EchoTheme.textSecondary) } }.onAppear { generateShareURL() }
        }
    }
    private func generateShareURL() {
        let view = ShareCard(totalReach: totalReach, totalContacts: totalContacts).frame(width: 280)
        let renderer = ImageRenderer(content: view); renderer.scale = 3.0
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("echo-milestone-\(totalReach).png")
        try? data.write(to: url); shareURL = url
    }
}

private struct ShareCard: View {
    let totalReach: Int; let totalContacts: Int
    var body: some View {
        VStack(spacing: EchoTheme.spacing16) {
            Image(systemName: "wave.3.right").font(.system(size: 32, weight: .light)).foregroundStyle(EchoTheme.accent)
            Text("Echo").font(.title.weight(.bold)).foregroundStyle(EchoTheme.textPrimary)
            Text("I've reached out \(totalReach) times\nto \(totalContacts) people.").font(.body).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center)
            Text("Stay in touch with who matters.").font(.caption).foregroundStyle(EchoTheme.textTertiary)
        }.padding(EchoTheme.spacing32).background(EchoTheme.bgPrimary).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}
