import SwiftUI

struct OnboardingView: View {
    let finish: () -> Void
    @State private var page = 0

    private let pages: [(String, String, String)] = [
        ("wave.3.right.circle.fill", "Relationships have a rhythm", "Echo helps you remember the people who matter without turning friendship into a task list."),
        ("lock.shield.fill", "Private by design", "Your relationship history stays on your device. AI receives only the minimum anonymized context you approve."),
        ("sparkles", "Know what to say", "Get a warm opening message, relationship insight, or follow-up suggestion when you need it."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.18), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                Image(systemName: pages[page].0)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .contentTransition(.symbolEffect(.replace))

                VStack(spacing: 12) {
                    Text(pages[page].1)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(pages[page].2)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.indigo : Color.secondary.opacity(0.25))
                            .frame(width: index == page ? 28 : 8, height: 8)
                    }
                }

                Button {
                    if page == pages.count - 1 { finish() }
                    else { withAnimation { page += 1 } }
                } label: {
                    Text(page == pages.count - 1 ? "Start with Echo" : "Continue")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.indigo)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}
