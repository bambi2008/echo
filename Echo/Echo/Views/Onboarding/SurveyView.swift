import SwiftUI

struct SurveyView: View {
    var onComplete: () -> Void
    @State private var step = 0
    @State private var importantCount = 20
    @State private var lastReachChoice = 2
    @State private var guiltChoice = 1
    @State private var showResult = false
    private let totalSteps = 4
    var body: some View {
        ZStack {
            EchoBackground()
            VStack(spacing: 0) {
                HStack(spacing: 6) { ForEach(0..<totalSteps, id: \.self) { i in Capsule().fill(i <= step ? EchoTheme.accent : Color.white.opacity(0.15)).frame(width: i == step ? 24 : 8, height: 8).animation(.spring(duration: 0.3), value: step) } }.padding(.top, 60).padding(.bottom, 20)
                Spacer()
                Group { if showResult { resultView.transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity)) } else { switch step { case 0: stepZero.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))); case 1: stepOne.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))); case 2: stepTwo.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))); case 3: stepThree.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))); default: EmptyView() } } }.animation(.spring(duration: 0.45, bounce: 0.12), value: step).animation(.spring(duration: 0.5, bounce: 0.2), value: showResult).padding(.horizontal, 32)
                Spacer()
                if !showResult { bottomButton.padding(.bottom, 48).padding(.horizontal, 32) }
            }
        }
    }
    private var stepZero: some View {
        VStack(spacing: EchoTheme.spacing24) {
            VStack(spacing: EchoTheme.spacing12) { ZStack { Circle().fill(EchoTheme.accent.opacity(0.06)).frame(width: 88, height: 88); Image(systemName: "person.3.sequence.fill").font(.system(size: 38, weight: .light)).foregroundStyle(EchoTheme.accent) }; Text("Quick question").font(.caption.weight(.medium)).foregroundStyle(EchoTheme.textTertiary).textCase(.uppercase).tracking(1.5) }
            Text("How many people in your life\ntruly matter to you?").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary).multilineTextAlignment(.center)
            VStack(spacing: EchoTheme.spacing8) { Text("\(importantCount)").font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.accent).contentTransition(.numericText()).animation(.spring(duration: 0.3), value: importantCount); Stepper(value: $importantCount, in: 1...200, step: 1) { Text("People who matter").font(.subheadline).foregroundStyle(EchoTheme.textSecondary) }.labelsHidden().tint(EchoTheme.accent); Text("Family, close friends, mentors, colleagues…").font(.caption).foregroundStyle(EchoTheme.textTertiary) }
        }
    }
    private var stepOne: some View {
        VStack(spacing: EchoTheme.spacing24) {
            Text("When was the last time you\nreached out to most of them?").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary).multilineTextAlignment(.center)
            VStack(spacing: EchoTheme.spacing8) { ForEach(Array(reachOptions.enumerated()), id: \.offset) { index, option in Button { EchoHaptics.selection(); withAnimation(.spring(duration: 0.3)) { lastReachChoice = index } } label: { HStack { Text(option.emoji); Text(option.text).font(.body.weight(.medium)).foregroundStyle(EchoTheme.textPrimary); Spacer(); if lastReachChoice == index { Image(systemName: "checkmark.circle.fill").foregroundStyle(EchoTheme.accent) } }.padding(.horizontal, 20).frame(height: 56).background(lastReachChoice == index ? EchoTheme.accent.opacity(0.12) : EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous).stroke(lastReachChoice == index ? EchoTheme.accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)) }.buttonStyle(.plain) } }
        }
    }
    private var reachOptions: [(emoji: String, text: String)] { [("😌", "This week"), ("📅", "This month"), ("🗓️", "A few months ago"), ("🤔", "Honestly… I can't remember")] }
    private var stepTwo: some View {
        VStack(spacing: EchoTheme.spacing24) {
            Text("How does it feel when you realize\nyou've lost touch with someone?").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary).multilineTextAlignment(.center)
            VStack(spacing: EchoTheme.spacing8) { ForEach(Array(guiltOptions.enumerated()), id: \.offset) { index, option in Button { EchoHaptics.selection(); withAnimation(.spring(duration: 0.3)) { guiltChoice = index } } label: { HStack { Text(option.emoji).font(.title3); Text(option.text).font(.body.weight(.medium)).foregroundStyle(EchoTheme.textPrimary); Spacer(); if guiltChoice == index { Image(systemName: "checkmark.circle.fill").foregroundStyle(EchoTheme.accent) } }.padding(.horizontal, 20).frame(height: 56).background(guiltChoice == index ? EchoTheme.accent.opacity(0.12) : EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous).stroke(guiltChoice == index ? EchoTheme.accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)) }.buttonStyle(.plain) } }
        }
    }
    private var guiltOptions: [(emoji: String, text: String)] { [("😔", "Guilty — I should do better"), ("😢", "Sad — I miss them"), ("😤", "Frustrated — life gets busy"), ("🤷", "It happens, nothing I can do")] }
    private var stepThree: some View {
        VStack(spacing: EchoTheme.spacing24) {
            ZStack { Circle().fill(EchoTheme.accent.opacity(0.06)).frame(width: 88, height: 88); Image(systemName: "wave.3.right.fill").font(.system(size: 38, weight: .light)).foregroundStyle(EchoTheme.accent).symbolEffect(.pulse, options: .repeating) }
            Text("What if you never\nlost touch again?").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary).multilineTextAlignment(.center)
            Text("Echo quietly tracks who you haven't talked to.\nIt takes 10 seconds a day to stay connected\nto everyone who matters.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center)
        }
    }
    private var resultView: some View {
        VStack(spacing: EchoTheme.spacing24) {
            VStack(spacing: EchoTheme.spacing16) {
                VStack(spacing: EchoTheme.spacing4) { Text("\(importantCount)").font(.system(size: 72, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.accent); Text("people matter to you").font(.headline).foregroundStyle(EchoTheme.textSecondary) }
                VStack(spacing: EchoTheme.spacing8) {
                    HStack(spacing: EchoTheme.spacing12) { statBox(value: "\(reachOptions[lastReachChoice].emoji)", label: "Last reached out"); statBox(value: "\(guiltOptions[guiltChoice].emoji)", label: "How it feels") }
                    Text(reachInsight).font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.overdue).multilineTextAlignment(.center).padding(.horizontal, 24).padding(.vertical, 12).background(EchoTheme.overdue.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius12, style: .continuous))
                }
            }
            VStack(spacing: EchoTheme.spacing12) { Text("It doesn't have to be this way.").font(.title3.weight(.semibold)).foregroundStyle(EchoTheme.textPrimary); Text("Echo will remind you before you lose touch.\nLet's set it up — it takes 2 minutes.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center) }
            Button { EchoHaptics.medium(); onComplete() } label: { Text("Let's Fix This").font(.headline).frame(maxWidth: .infinity).frame(height: 54) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).padding(.horizontal, 32).padding(.bottom, 48)
        }
    }
    private var reachInsight: String {
        switch lastReachChoice {
        case 0: return "You're doing great! Echo will help you keep the streak."
        case 1: return "You're doing okay, but \(importantCount - Int(ceil(Double(importantCount) * 0.3))) people are waiting to hear from you."
        case 2: return "Most of your \(importantCount) people haven't heard from you in months."
        default: return "If you can't remember… they probably can't either. \(importantCount) people are slipping away."
        }
    }
    private func statBox(value: String, label: String) -> some View { VStack(spacing: 4) { Text(value).font(.title2); Text(label).font(.caption2).foregroundStyle(EchoTheme.textTertiary) }.frame(maxWidth: .infinity).padding(.vertical, EchoTheme.spacing12).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius12, style: .continuous)) }
    private var bottomButton: some View {
        Button { EchoHaptics.light(); if step < totalSteps - 1 { withAnimation { step += 1 } } else { withAnimation { showResult = true } } } label: { Text(step < totalSteps - 1 ? "Continue" : "See My Results").font(.headline).frame(maxWidth: .infinity).frame(height: 54) }.buttonStyle(.borderedProminent).tint(EchoTheme.accent)
    }
}
