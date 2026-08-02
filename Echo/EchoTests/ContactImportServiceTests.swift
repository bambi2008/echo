import XCTest
import SwiftData
@testable import Echo

final class ContactImportServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    override func setUpWithError() throws {
        let schema = Schema([EchoContact.self, Interaction.self, Note.self, Deal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }
    func testImportServiceCreation() {
        let service = ContactImportService(modelContext: context)
        XCTAssertNotNil(service)
    }
    func testContactInsertion() {
        let contact = EchoContact(systemIdentifier: "test-1", givenName: "Sarah", familyName: "Chen", phoneNumber: "+86 138 0000 0000", emailAddress: "sarah@example.com")
        context.insert(contact); try? context.save()
        let descriptor = FetchDescriptor<EchoContact>()
        let contacts = try? context.fetch(descriptor)
        XCTAssertEqual(contacts?.count, 1)
        XCTAssertEqual(contacts?.first?.givenName, "Sarah")
        XCTAssertEqual(contacts?.first?.fullName, "Sarah Chen")
        XCTAssertTrue(contacts?.first?.isInEchoLayer ?? false)
    }
    func testEchoLayerDefaultTrue() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        XCTAssertTrue(contact.isInEchoLayer)
    }
    func testInteractionRelationship() {
        let contact = EchoContact(systemIdentifier: "1", givenName: "Test")
        context.insert(contact)
        let interaction = Interaction(type: .called, note: "Quick chat")
        interaction.contact = contact; contact.interactions.append(interaction); context.insert(interaction); try? context.save()
        XCTAssertEqual(contact.interactions.count, 1)
        XCTAssertEqual(contact.interactions.first?.note, "Quick chat")
        XCTAssertEqual(contact.interactions.first?.interactionType, .called)
    }
}
