import SwiftUI
struct SmartMessageComposerView: View {
    let contact: EchoContact
    @State private var selectedTone: MessageTone = .warm
    @State private var generatedMessage: String = ""
    @State private var isGenerating = false
    @State private var showCopied = false
    @State private var variations: [String] = []
    @State private var currentVariation = 0
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                EchoTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        HStack(spacing: 14) { ZStack { Circle().fill(EchoTheme.accentColor.opacity(0.2)).frame(width: 50, height: 50); Text(contact.givenName.prefix(1).uppercased()).font(.system(size: 20, weight: .bold)).foregroundStyle(EchoTheme.accentColor) }; VStack(alignment: .leading, spacing: 2) { Text(contact.fullName).font(.system(size: 17, weight: .semibold)); Text("写给 \(contact.givenName) 的消息").font(.system(size: 13)).foregroundStyle(.secondary) }; Spacer() }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 10) { Text("选择语气").font(.system(size: 15, weight: .bold, design: .rounded)); HStack(spacing: 10) { ForEach(MessageTone.allCases) { tone in Button { UISelectionFeedbackGenerator().selectionChanged(); selectedTone = tone } label: { VStack(spacing: 6) { Image(systemName: tone.icon).font(.system(size: 20)); Text(tone.label).font(.system(size: 13, weight: .medium, design: .rounded)) }.foregroundStyle(selectedTone == tone ? .white : .primary).frame(maxWidth: .infinity).padding(.vertical, 14).background(selectedTone == tone ? AnyShapeStyle(tone.color.gradient) : AnyShapeStyle(Color.gray.opacity(0.1))).clipShape(RoundedRectangle(cornerRadius: 12)) } } } }
                        Button { generateMessages() } label: { HStack(spacing: 8) { Image(systemName: "sparkles"); Text(isGenerating ? "AI 正在撰写..." : "AI 撰写消息") }.font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(LinearGradient(colors: [EchoTheme.accentColor, Color(hex: "00F5FF")], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: EchoTheme.accentColor.opacity(0.3), radius: 12, x: 0, y: 6) }.disabled(isGenerating).opacity(isGenerating ? 0.6 : 1)
                        if !variations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack { Image(systemName: "text.quote.left").font(.system(size: 14)).foregroundStyle(EchoTheme.accentColor); Text("AI 生成的消息").font(.system(size: 14, weight: .semibold)); Spacer(); Button { currentVariation = (currentVariation + 1) % variations.count; generatedMessage = variations[currentVariation]; UISelectionFeedbackGenerator().selectionChanged() } label: { HStack(spacing: 4) { Image(systemName: "arrow.clockwise").font(.system(size: 11)); Text("换一封").font(.system(size: 12)) }.foregroundStyle(EchoTheme.accentColor).padding(.horizontal, 10).padding(.vertical, 6).background(EchoTheme.accentColor.opacity(0.1)).clipShape(Capsule()) } }
                                Text(generatedMessage).font(.system(size: 15)).lineSpacing(6).padding(16).background(Color.gray.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12)).animation(.easeInOut(duration: 0.2), value: currentVariation)
                            }.padding(16).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 16))
                            HStack(spacing: 12) {
                                Button { UIPasteboard.general.string = generatedMessage; showCopied = true; UINotificationFeedbackGenerator().notificationOccurred(.success); DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopied = false } } label: { VStack(spacing: 6) { Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc").font(.system(size: 20)).foregroundStyle(showCopied ? .green : EchoTheme.accentColor); Text(showCopied ? "已复制" : "复制").font(.system(size: 12)).foregroundStyle(.primary) }.frame(maxWidth: .infinity).padding(.vertical, 14).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 12)) }
                                Button { if let p = contact.phoneNumber, let u = URL(string: "sms:\(p)") { UIApplication.shared.open(u) } } label: { VStack(spacing: 6) { Image(systemName: "message.fill").font(.system(size: 20)).foregroundStyle(.white); Text("发短信").font(.system(size: 12)).foregroundStyle(.white) }.frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.blue.gradient).clipShape(RoundedRectangle(cornerRadius: 12)) }
                                Button { if let e = contact.emailAddress, let u = URL(string: "mailto:\(e)") { UIApplication.shared.open(u) } } label: { VStack(spacing: 6) { Image(systemName: "envelope.fill").font(.system(size: 20)).foregroundStyle(.white); Text("发邮件").font(.system(size: 12)).foregroundStyle(.white) }.frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.orange.gradient).clipShape(RoundedRectangle(cornerRadius: 12)) }
                            }
                        }
                    }.padding(.horizontal, 20).padding(.bottom, 40)
                }
            }.navigationTitle("AI 撰写").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(.secondary) } } }
        }
    }
    private func generateMessages() {
        isGenerating = true; let tone = selectedTone; let gap = Int(Date().timeIntervalSince(contact.lastReachedOut ?? Date()) / 86400)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            variations = AIEngine.generateSmartMessages(for: contact, tone: tone, gapDays: gap); currentVariation = 0; generatedMessage = variations.first ?? "Hey \(contact.givenName), it's been a while! Just wanted to reach out and see how you're doing."; isGenerating = false; UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
enum MessageTone: String, CaseIterable, Identifiable {
    var id: String { rawValue }; case warm = "warm"; case casual = "casual"; case professional = "professional"
    var label: String { switch self { case .warm: "温暖"; case .casual: "轻松"; case .professional: "正式" } }
    var icon: String { switch self { case .warm: "heart.fill"; case .casual: "hand.thumbsup.fill"; case .professional: "briefcase.fill" } }
    var color: Color { switch self { case .warm: Color(hex: "FF6B6B"); case .casual: Color(hex: "00B4D8"); case .professional: Color(hex: "6B4DE6") } }
}