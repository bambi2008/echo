import SwiftUI

struct OnboardingTour: View {
    @Binding var isActive: Bool
    var highlightContact: EchoContact? = nil
    @State private var step = 0
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().background(.ultraThinMaterial).onTapGesture { EchoHaptics.light(); isActive = false }
            VStack {
                Spacer()
                VStack(spacing: EchoTheme.spacing16) {
                    Group {
                        switch step {
                        case 0: tourStep(icon: "person.3.sequence.fill", title: "This is your Echo Layer", desc: "The people you care about most. Echo tracks when you last reached out.")
                        case 1: tourStep(icon: "hand.wave.fill", title: "Tap to Reach Out", desc: "Tap the wave icon to call, message, or email — Echo logs it automatically.")
                        case 2: tourStep(icon: "clock.fill", title: "Echo Remembers", desc: "Every interaction is saved on your device. Echo reminds you when it's time to reconnect.")
                        default: EmptyView()
                        }
                    }
                    .id(step).transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading)))).animation(.spring(duration: 0.35, bounce: 0.1), value: step)
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule().fill(i == step ? EchoTheme.accent : Color.white.opacity(0.2)).frame(width: i == step ? 20 : 7, height: 7).animation(.spring(duration: 0.3), value: step)
                        }
                    }
                    Button { EchoHaptics.selection(); if step < 2 { withAnimation { step += 1 } } else { isActive = false } } label: {
                        Text(step < 2 ? "Next" : "Got it!").font(.headline).frame(maxWidth: .infinity).frame(height: 48)
                    }.buttonStyle(.borderedProminent).tint(EchoTheme.accent)
                }
                .padding(EchoTheme.spacing24).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius24, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5)).shadow(color: Color.black.opacity(0.3), radius: 20, y: 8).padding(.horizontal, 32)
                Spacer()
            }
        }
    }
    private func tourStep(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: EchoTheme.spacing12) {
            ZStack { Circle().fill(EchoTheme.accent.opacity(0.1)).frame(width: 56, height: 56); Image(systemName: icon).font(.system(size: 24, weight: .light)).foregroundStyle(EchoTheme.accent) }
            Text(title).font(.headline).foregroundStyle(EchoTheme.textPrimary)
            Text(desc).font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center)
        }
    }
}
