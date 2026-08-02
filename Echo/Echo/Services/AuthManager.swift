import Foundation
import SwiftUI

struct UserProfile: Codable { let email: String; let provider: AuthProvider; let createdAt: Date; var fullName: String?; init(email: String, provider: AuthProvider, fullName: String? = nil) { self.email = email; self.provider = provider; self.createdAt = Date(); self.fullName = fullName } }
enum AuthProvider: String, Codable { case apple, google, email; var icon: String { switch self { case .apple: return "applelogo"; case .google: return "G"; case .email: return "envelope" } }; var label: String { switch self { case .apple: return "Apple"; case .google: return "Google"; case .email: return "Email" } } }

@MainActor final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private let defaults = UserDefaults.standard
    private let userKey = "echo_user_profile"
    @Published var currentUser: UserProfile?
    private init() { loadUser() }
    var isLoggedIn: Bool { currentUser != nil }
    func saveUser(_ profile: UserProfile) { if let data = try? JSONEncoder().encode(profile) { defaults.set(data, forKey: userKey); currentUser = profile } }
    func loadUser() { if let data = defaults.data(forKey: userKey), let profile = try? JSONDecoder().decode(UserProfile.self, from: data) { currentUser = profile } }
    func logout() { defaults.removeObject(forKey: userKey); currentUser = nil }
}

enum OnboardingStep: Int, CaseIterable { case survey = 0, registration = 1, valueProp = 2, paywall = 3, importContacts = 4, done = 5; var key: String { switch self { case .survey: return "echo_done_survey"; case .registration: return "echo_done_registration"; case .valueProp: return "echo_done_valueprop"; case .paywall: return "echo_done_paywall"; case .importContacts: return "echo_has_imported"; case .done: return "echo_onboarding_complete" } } }

struct OnboardingState {
    static let defaults = UserDefaults.standard
    static var currentStep: OnboardingStep { for step in OnboardingStep.allCases.reversed() { if defaults.bool(forKey: step.key) { return OnboardingStep(rawValue: min(step.rawValue + 1, OnboardingStep.done.rawValue)) ?? .done } }; return .survey }
    static func complete(_ step: OnboardingStep) { defaults.set(true, forKey: step.key) }
    static func reset() { for step in OnboardingStep.allCases { defaults.removeObject(forKey: step.key) } }
    static var isComplete: Bool { defaults.bool(forKey: OnboardingStep.done.key) }
}

@MainActor final class TrialManager: ObservableObject {
    static let shared = TrialManager()
    private let defaults = UserDefaults.standard
    private let trialStartKey = "echo_trial_start_date"
    private let trialDurationDays = 3
    @Published var trialStartDate: Date?
    private init() { loadTrial() }
    var isInTrial: Bool { guard let start = trialStartDate else { return false }; let calendar = Calendar.current; if let end = calendar.date(byAdding: .day, value: trialDurationDays, to: start) { return Date() < end }; return false }
    var trialDaysRemaining: Int { guard let start = trialStartDate else { return 0 }; let calendar = Calendar.current; let remaining = calendar.dateComponents([.day], from: Date(), to: calendar.date(byAdding: .day, value: trialDurationDays, to: start) ?? Date()).day ?? 0; return max(0, remaining) }
    func startTrial() { let now = Date(); defaults.set(now, forKey: trialStartKey); trialStartDate = now }
    func endTrial() { defaults.removeObject(forKey: trialStartKey); trialStartDate = nil }
    private func loadTrial() { if let date = defaults.object(forKey: trialStartKey) as? Date { trialStartDate = date } }
}
