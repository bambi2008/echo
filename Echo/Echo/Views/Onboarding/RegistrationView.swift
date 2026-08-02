import SwiftUI
import AuthenticationServices

struct RegistrationView: View {
    var onRegistered: (UserProfile) -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var showEmailForm = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    var body: some View {
        ZStack {
            EchoBackground()
            ScrollView {
                VStack(spacing: EchoTheme.spacing24) {
                    VStack(spacing: EchoTheme.spacing12) {
                        ZStack { Circle().fill(EchoTheme.accent.opacity(0.06)).frame(width: 72, height: 72); Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 32, weight: .light)).foregroundStyle(EchoTheme.accent) }
                        Text("Create your account").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(EchoTheme.textPrimary)
                        Text("Echo keeps your data on your device.\nWe only need your email to sync your subscription.").font(.subheadline).foregroundStyle(EchoTheme.textSecondary).multilineTextAlignment(.center)
                    }.padding(.top, 48)
                    SignInWithAppleButton(.signUp) { request in request.requestedScopes = [.email, .fullName]; request.nonce = "echo_nonce_\(Date().timeIntervalSince1970)" } onCompletion: { result in handleAppleSignIn(result) }.signInWithAppleButtonStyle(.white).frame(height: 54).cornerRadius(EchoTheme.radius14)
                    Button { EchoHaptics.light(); withAnimation { showEmailForm = true } } label: { HStack(spacing: 12) { Text("G").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.98, green: 0.69, blue: 0.25), Color(red: 0.91, green: 0.26, blue: 0.20)], startPoint: .top, endPoint: .bottom)).frame(width: 24, height: 24); Text("Continue with Google").font(.body.weight(.medium)).foregroundStyle(EchoTheme.textPrimary); Spacer() }.frame(height: 54).padding(.horizontal, 20).background(EchoTheme.bgCard).clipShape(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous)).overlay(RoundedRectangle(cornerRadius: EchoTheme.radius14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1)) }.buttonStyle(.plain)
                    HStack { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5); Text("or").font(.caption).foregroundStyle(EchoTheme.textTertiary); Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5) }
                    if showEmailForm {
                        VStack(spacing: EchoTheme.spacing12) {
                            VStack(alignment: .leading, spacing: 6) { Text("Email").font(.caption.weight(.medium)).foregroundStyle(EchoTheme.textTertiary); TextField("you@example.com", text: $email).textFieldStyle(.roundedBorder).keyboardType(.emailAddress).textContentType(.emailAddress).autocapitalization(.none).tint(EchoTheme.accent) }
                            VStack(alignment: .leading, spacing: 6) { Text("Password").font(.caption.weight(.medium)).foregroundStyle(EchoTheme.textTertiary); SecureField("Create a password", text: $password).textFieldStyle(.roundedBorder).textContentType(.newPassword).tint(EchoTheme.accent) }
                            Button { EchoHaptics.medium(); registerWithEmail() } label: { if isLoading { ProgressView().tint(.white).frame(maxWidth: .infinity).frame(height: 54) } else { Text("Create Account").font(.headline).frame(maxWidth: .infinity).frame(height: 54) } }.buttonStyle(.borderedProminent).tint(EchoTheme.accent).disabled(email.isEmpty || password.count < 6).opacity(email.isEmpty || password.count < 6 ? 0.5 : 1)
                        }.transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                    } else {
                        Button { EchoHaptics.selection(); withAnimation(.spring(duration: 0.3)) { showEmailForm = true } } label: { Text("Sign up with email").font(.subheadline.weight(.medium)).foregroundStyle(EchoTheme.textSecondary) }
                    }
                    if let error = errorMessage { Text(error).font(.caption).foregroundStyle(EchoTheme.overdue) }
                    Text("By continuing, you agree to Echo's Terms of Service\nand Privacy Policy. Your contacts never leave your device.").font(.caption2).foregroundStyle(EchoTheme.textTertiary).multilineTextAlignment(.center)
                }.padding(.horizontal, 32).padding(.bottom, 48)
            }
        }
    }
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth): let profile = UserProfile(email: (auth.credential as? ASAuthorizationAppleIDCredential)?.email ?? "(Apple ID)", provider: .apple); AuthManager.shared.saveUser(profile); onRegistered(profile)
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }
    private func registerWithEmail() {
        guard email.contains("@") else { errorMessage = "Please enter a valid email."; return }
        guard password.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return }
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { isLoading = false; let profile = UserProfile(email: email, provider: .email); AuthManager.shared.saveUser(profile); onRegistered(profile) }
    }
}
