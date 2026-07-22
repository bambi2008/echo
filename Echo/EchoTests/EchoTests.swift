//
//  EchoTests.swift
//  EchoTests
//
//  Created by 茅18 on 2026/7/22.
//

import XCTest
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
}
