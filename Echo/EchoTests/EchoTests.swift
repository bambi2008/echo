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

    func testRelationshipDomainSupportsPersonalBusinessAndBothWithoutDuplicatingContact() {
        let personal = EchoContact(givenName: "Maya", relationshipDomain: .personal)
        let business = EchoContact(givenName: "Noah", relationshipDomain: .business)
        let both = EchoContact(givenName: "Ari", relationshipDomain: .both)

        XCTAssertTrue(personal.isPersonalRelationship)
        XCTAssertFalse(personal.isBusinessRelationship)
        XCTAssertFalse(business.isPersonalRelationship)
        XCTAssertTrue(business.isBusinessRelationship)
        XCTAssertTrue(both.isPersonalRelationship)
        XCTAssertTrue(both.isBusinessRelationship)
    }

    func testLegacyContactDomainIsInferredFromExistingProfile() {
        let friend = EchoContact(givenName: "Leah")
        friend.tags = [ContactIdentity.friend.rawValue]
        let clientFriend = EchoContact(givenName: "Owen", companyName: "Acme")
        clientFriend.tags = [ContactIdentity.friend.rawValue, ContactIdentity.client.rawValue]

        XCTAssertEqual(friend.relationshipDomain, .personal)
        XCTAssertEqual(clientFriend.relationshipDomain, .both)
        XCTAssertNil(friend.relationshipDomainRawValue)
        XCTAssertNil(clientFriend.relationshipDomainRawValue)
    }

    func testMemorySearchFindsAPersonWithoutUsingTheirName() {
        let calendar = Calendar.current
        let lastYear = calendar.date(byAdding: .year, value: -1, to: .now)!
        let target = EchoContact(
            givenName: "Jing",
            familyName: "Chen",
            companyName: "Harbor Insurance",
            jobTitle: "Enterprise Advisor"
        )
        target.tags = [ContactIdentity.client.rawValue, "Insurance"]
        target.notes.append(EchoNote(
            createdAt: lastYear,
            content: "去年在上海保险活动认识，王总介绍，负责企业客户。",
            contact: target
        ))
        let distractor = EchoContact(
            givenName: "Leo",
            familyName: "Wu",
            companyName: "Northstar Design",
            jobTitle: "Designer"
        )
        distractor.notes.append(EchoNote(
            content: "Discussed a new product design.",
            contact: distractor
        ))

        let matches = RecallSearchEngine.search(
            description: "去年上海保险活动认识，王总介绍，做企业客户",
            contacts: [distractor, target],
            now: .now
        )

        XCTAssertEqual(matches.first?.contact.systemIdentifier, target.systemIdentifier)
        XCTAssertTrue(matches.first?.matchedKeywords.contains("上海") == true)
        XCTAssertTrue(matches.first?.evidence.contains("a saved note") == true)
    }

    func testMemorySearchReturnsNoGuessWithoutMatchingEvidence() {
        let contact = EchoContact(givenName: "Mina", companyName: "Echo")

        let matches = RecallSearchEngine.search(
            description: "在南极科考站认识的天文学家",
            contacts: [contact]
        )

        XCTAssertTrue(matches.isEmpty)
    }

    func testMemorySearchBridgesChineseCluesToEnglishContactData() {
        let financeColleague = EchoContact(
            givenName: "Kevin",
            companyName: "Evergreen Wealth",
            jobTitle: "Financial Advisor"
        )
        financeColleague.tags = ["Former colleague", "Finance"]
        let designer = EchoContact(
            givenName: "Nora",
            companyName: "Canvas",
            jobTitle: "Design Lead"
        )
        designer.tags = ["Friend", "Design"]

        let matches = RecallSearchEngine.search(
            description: "以前的同事，后来去了金融行业",
            contacts: [designer, financeColleague]
        )

        XCTAssertEqual(matches.first?.contact.systemIdentifier, financeColleague.systemIdentifier)
        XCTAssertTrue(matches.first?.matchedKeywords.contains("finance") == true)
        XCTAssertTrue(matches.first?.matchedKeywords.contains("colleague") == true)
    }

    func testVoiceTranscriptKeepsExistingMemoryText() {
        let combined = VoiceTranscriptComposer.combine(
            existing: "去年在上海",
            spoken: "保险活动认识"
        )

        XCTAssertEqual(combined, "去年在上海 保险活动认识")
        XCTAssertEqual(
            VoiceTranscriptComposer.combine(existing: "", spoken: "王总介绍"),
            "王总介绍"
        )
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

    func testContactIdentityAndLinkedDealPersistTogether() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: EchoContact.self, Interaction.self, EchoNote.self, Deal.self,
            configurations: configuration
        )
        let contact = EchoContact(
            systemIdentifier: "test-contact",
            givenName: "Mina",
            familyName: "Chen",
            priority: .hot,
            relationshipDomain: .business,
            companyName: "Northstar",
            jobTitle: "Founder"
        )
        contact.tags = [ContactIdentity.prospect.rawValue]
        let nextActionDate = Date(timeIntervalSince1970: 1_800_000_000)
        let deal = Deal(
            title: "Northstar renewal",
            value: 25_000,
            stage: .quoted,
            nextActionDate: nextActionDate,
            contact: contact
        )

        container.mainContext.insert(contact)
        container.mainContext.insert(deal)
        try container.mainContext.save()

        let storedDeal = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Deal>()).first)
        XCTAssertEqual(storedDeal.contact?.systemIdentifier, "test-contact")
        XCTAssertEqual(storedDeal.contact?.priority, .hot)
        XCTAssertEqual(storedDeal.contact?.relationshipDomain, .business)
        XCTAssertEqual(storedDeal.contact?.tags, [ContactIdentity.prospect.rawValue])
        XCTAssertEqual(storedDeal.stage, .quoted)
        XCTAssertEqual(storedDeal.nextActionDate, nextActionDate)
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
