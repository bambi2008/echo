import SwiftUI
struct FoundersNoteView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "6B4DE6"), Color(hex: "00F5FF")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 80, height: 80)
                    Image(systemName: "wave.3.right").font(.system(size: 32, weight: .light)).foregroundStyle(.white)
                }.padding(.top, 32)
                Text("A Note from the Builder").font(.system(size: 24, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 14) {
                    Text("Hey,").font(.system(size: 18, weight: .bold))
                    Text("I built Echo because I kept losing touch with people who matter to me. Not because I didn't care — but because life got busy and I simply forgot.").font(.system(size: 16)).lineSpacing(6)
                    Text("Relationships don't fade because of one big fight. They fade through a thousand small moments of 'I'll reach out tomorrow.' Tomorrow becomes next week. Next week becomes next month.").font(.system(size: 16)).lineSpacing(6)
                    Text("Echo is my attempt to fix this. It's not a CRM. It's a quiet companion that gently reminds you when someone you care about is slipping away — and gives you the perfect words to reconnect.").font(.system(size: 16)).lineSpacing(6)
                    Text("Everything runs on your device. Your relationships, your conversations, your memories — they never leave your phone. Privacy isn't a feature. It's a foundation.").font(.system(size: 16)).lineSpacing(6)
                    Text("If Echo helps you reach out to one person you've been meaning to call — then it's done its job.").font(.system(size: 16)).lineSpacing(6)
                    Text("With care,").font(.system(size: 16, weight: .semibold)).padding(.top, 8)
                    Text("— The Echo Team").font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(EchoTheme.accentColor)
                }.padding(.horizontal, 24).padding(.vertical, 20).background(EchoTheme.cardGradient).clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(spacing: 8) {
                    Text("We're live on Product Hunt!").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.accentColor)
                    Text("Your support means everything. Every share, every comment, every 'I needed this' reminds us why we built Echo.").font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                }.padding(.vertical, 16)
                Spacer().frame(height: 40)
                Button { dismiss() } label: { Text("Close").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(EchoTheme.accentColor).padding(.horizontal, 40).padding(.vertical, 12).background(EchoTheme.cardGradient).clipShape(Capsule()) }.padding(.bottom, 32)
            }.padding(.horizontal, 20)
        }.background(EchoTheme.backgroundGradient.ignoresSafeArea())
    }
}