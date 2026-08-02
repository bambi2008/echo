import SwiftUI
import ActivityKit
struct ReachOutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable { var contactName: String; var contactInitial: String; var healthColor: String; var gapDays: Int; var elapsedTime: Double }
    var contactName: String
}
class LiveActivityManager {
    static let shared = LiveActivityManager(); private var currentActivity: Activity<ReachOutAttributes>?
    func startActivity(for contact: EchoContact) { guard #available(iOS 16.2, *) else { return }; stopActivity(); let attributes = ReachOutAttributes(contactName: contact.givenName); let state = ReachOutAttributes.ContentState(contactName: contact.givenName, contactInitial: contact.givenName.prefix(1).uppercased(), healthColor: "00B4D8", gapDays: Int(Date().timeIntervalSince(contact.lastReachedOut ?? Date()) / 86400), elapsedTime: 0); do { currentActivity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil) } catch {} }
    func stopActivity() { guard #available(iOS 16.2, *) else { return }; Task { await currentActivity?.end(nil, dismissalPolicy: .immediate); currentActivity = nil } }
}