//
//  EchoTests.swift
//  EchoTests
//
//  Created by 茅18 on 2026/7/22.
//

import XCTest
import SwiftData
@testable import Echo

@MainActor
final class EchoTests: XCTestCase {
    func testContactDisplayValues() {
        let contact = EchoContact(givenName: "Lisa", familyName: "Park")

        XCTAssertEqual(contact.fullName, "Lisa Park")
        XCTAssertEqual(contact.initials, "LP")
    }

    func testPriorityRoundTrip() {
        let contact = EchoContact(givenName: "Sarah", priority: .warm)

        XCTAssertEqual(contact.priority, .warm)
        contact.priority = .hot
        XCTAssertEqual(contact.priorityRawValue, PriorityLevel.hot.rawValue)
    }

    func testNeverContactedPersonGetsMaximumAttentionScore() {
        let contact = EchoContact(givenName: "Mike", reachCount: 12)

        XCTAssertEqual(EchoEngine.attentionScore(for: contact), 100)
    }

    func testIncomingEmailRefreshesRelationshipRecency() {
        let contact = EchoContact(
            givenName: "Ava",
            lastReachedOut: Calendar.current.date(byAdding: .day, value: -90, to: .now)
        )
        contact.interactions.append(Interaction(
            date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
            type: .emailed,
            summary: "Received email",
            contact: contact,
            externalIdentifier: "gmail:test:Ava",
            source: "gmail",
            isIncoming: true
        ))

        XCTAssertEqual(contact.daysSinceContact, 2)
        XCTAssertEqual(contact.interactions.first?.sourceRawValue, "gmail")
        XCTAssertEqual(contact.interactions.first?.isIncoming, true)
    }

    func testGmailSyncResultReportsUnmatchedMessages() {
        let result = GmailSyncResult(
            importedInteractions: 3,
            messagesScanned: 10,
            matchedMessages: 2,
            lastSyncAt: .now,
            wasIncremental: true
        )

        XCTAssertEqual(result.unmatchedMessages, 8)
        XCTAssertTrue(result.wasIncremental)
    }

    func testDemoDataSeedsTwoHundredRichContacts() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: EchoContact.self, Interaction.self, EchoNote.self, Deal.self,
            configurations: configuration
        )

        DemoData.seedIfNeeded(in: container.mainContext)

        let contacts = try container.mainContext.fetch(FetchDescriptor<EchoContact>())
        let deals = try container.mainContext.fetch(FetchDescriptor<Deal>())
        XCTAssertEqual(contacts.count, DemoData.targetContactCount)
        XCTAssertEqual(Set(contacts.map(\.systemIdentifier)).count, DemoData.targetContactCount)
        XCTAssertTrue(contacts.allSatisfy { !$0.tags.isEmpty })
        XCTAssertTrue(contacts.filter { $0.systemIdentifier.hasPrefix("echo.demo.contact") }.allSatisfy {
            !$0.interactions.isEmpty && $0.notes.count >= 2 && $0.companyName != nil
        })
        XCTAssertGreaterThan(deals.count, 40)
    }
}
