import XCTest
import SwiftData
@testable import Echo

final class EchoEngineTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    override func setUpWithError() throws {
        let schema = Schema([EchoContact.self, Interaction.self, Note.self, Deal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }
    func testGapDescriptionNeverReachedOut() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        let gap = EchoEngine.gapDescription(for: contact)
        XCTAssertEqual(gap, "Never reached out")
    }
    func testGapDescriptionToday() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        contact.lastReachedOut = Date()
        let gap = EchoEngine.gapDescription(for: contact)
        XCTAssertEqual(gap, "Reached out today")
    }
    func testGapDescriptionDaysAgo() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        contact.lastReachedOut = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        let gap = EchoEngine.gapDescription(for: contact)
        XCTAssertEqual(gap, "3 days ago")
    }
    func testIsOverdueNeverReached() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        XCTAssertTrue(EchoEngine.isOverdue(contact))
    }
    func testIsOverdueRecentlyReached() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        contact.lastReachedOut = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        XCTAssertFalse(EchoEngine.isOverdue(contact))
    }
    func testIsOverdueTwoWeeksAgo() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        contact.lastReachedOut = Calendar.current.date(byAdding: .day, value: -14, to: Date())
        XCTAssertTrue(EchoEngine.isOverdue(contact))
    }
    func testSortedEchoLayerPutsOverdueFirst() {
        let recent = EchoContact(systemIdentifier: "1", givenName: "Recent"); recent.lastReachedOut = Date()
        let old = EchoContact(systemIdentifier: "2", givenName: "Old"); old.lastReachedOut = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let never = EchoContact(systemIdentifier: "3", givenName: "Never")
        let sorted = EchoEngine.sortedEchoLayer(from: [recent, old, never])
        XCTAssertEqual(sorted.map(\.givenName), ["Never", "Old", "Recent"])
    }
    func testRecordReachCreatesInteraction() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        context.insert(contact)
        EchoEngine.recordReach(on: contact, type: .called, context: context)
        XCTAssertEqual(contact.reachCount, 1)
        XCTAssertEqual(contact.interactions.count, 1)
        XCTAssertEqual(contact.interactions.first?.interactionType, .called)
        XCTAssertNotNil(contact.lastReachedOut)
    }
    func testRecordReachMultiple() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        context.insert(contact)
        EchoEngine.recordReach(on: contact, type: .called, context: context)
        EchoEngine.recordReach(on: contact, type: .messaged, context: context)
        EchoEngine.recordReach(on: contact, type: .emailed, context: context)
        XCTAssertEqual(contact.reachCount, 3)
        XCTAssertEqual(contact.interactions.count, 3)
    }
}
