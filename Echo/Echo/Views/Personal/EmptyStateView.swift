import SwiftUI

struct EmptyStateView: View {
    let type: EmptyStateType
    let action: (() -> Void)?
    init(type: EmptyStateType, action: (() -> Void)? = nil) { self.type = type; self.action = action }
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().stroke(LinearGradient(colors: [type.color.opacity(0.3), type.color.opacity(0.05)], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 2, dash: [4, 4])).frame(width: 140, height: 140)
                Circle().fill(type.color.opacity(0.08)).frame(width: 100, height: 100)
                Image(systemName: type.icon).font(.system(size: 40, weight: .light)).foregroundStyle(type.color).symbolEffect(.bounce, options: .nonRepeating)
            }
            Spacer().frame(height: 28)
            Text(type.title).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.primary)
            Spacer().frame(height: 8)
            Text(type.subtitle).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer().frame(height: 32)
            if let action = action {
                Button { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); action() } label: {
                    HStack(spacing: 8) { Image(systemName: type.buttonIcon); Text(type.buttonText) }
                    .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 32).padding(.vertical, 14)
                    .background(LinearGradient(colors: [type.color, type.color.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule()).shadow(color: type.color.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum EmptyStateType {
    case noContacts, noInteractions, noSearchResults, noAchievements
    var icon: String { switch self { case .noContacts: "person.2.slash"; case .noInteractions: "wave.3.right"; case .noSearchResults: "magnifyingglass"; case .noAchievements: "trophy" } }
    var title: String { switch self { case .noContacts: "Your Echo Starts Here"; case .noInteractions: "Say Hello"; case .noSearchResults: "No Results"; case .noAchievements: "No Achievements Yet" } }
    var subtitle: String { switch self {
        case .noContacts: "Import your contacts to see who matters most. Echo will help you never lose touch."
        case .noInteractions: "You haven't recorded any interactions yet. Reach out to someone today."
        case .noSearchResults: "Try a different name or keyword. Your perfect contact might be hiding."
        case .noAchievements: "Start reaching out to unlock your first achievement. Every interaction counts."
    }}
    var buttonText: String { switch self { case .noContacts: "Import Contacts"; case .noInteractions: "Reach Out"; case .noSearchResults: "Clear Search"; case .noAchievements: "Get Started" } }
    var buttonIcon: String { switch self { case .noContacts: "person.crop.circle.badge.plus"; case .noInteractions: "hand.wave"; case .noSearchResults: "xmark"; case .noAchievements: "sparkles" } }
    var color: Color { switch self { case .noContacts: Color(hex: "6B4DE6"); case .noInteractions: Color(hex: "00B4D8"); case .noSearchResults: Color(hex: "FFB347"); case .noAchievements: Color(hex: "FF6B35") } }
}