//
//  EchoTests.swift
//  EchoTests
//
//  Created by 茅18 on 2026/7/22.
//

import EchoAI
import Contacts
import SwiftData
import XCTest
@testable import Echo

@MainActor
final class EchoTests: XCTestCase {
    func testPersistenceFailureDoesNotCreateAReplacementStoreAndCanRetry() {
        var attempts = 0
        let controller = EchoPersistenceController {
            attempts += 1
            throw PersistenceTestFailure.unavailable
        }

        XCTAssertNil(controller.container)
        XCTAssertTrue(controller.couldNotOpenStore)
        XCTAssertEqual(attempts, 1)
        controller.retry()
        XCTAssertNil(controller.container)
        XCTAssertEqual(attempts, 2)
    }

    func testContactDisplayValues() {
        let contact = EchoContact(givenName: "Lisa", familyName: "Park")

        XCTAssertEqual(contact.fullName, "Lisa Park")
        XCTAssertEqual(contact.initials, "LP")
    }

    func testPhonePlaceholderDisplaysAsUnnamedAndIsExcludedFromTodaysEcho() {
        let contact = EchoContact(
            givenName: "18111090503",
            phoneNumber: "181 1109 0503",
            relationshipDomain: .personal
        )

        XCTAssertFalse(contact.hasRealName)
        XCTAssertEqual(contact.fullName, "未命名联系人")
        XCTAssertEqual(contact.initials, "?")
        XCTAssertFalse(contact.isEligibleForTodaysEcho)
    }

    func testNamedContactNeedsRelationshipContextForTodaysEcho() {
        let unreviewed = EchoContact(givenName: "Mina")
        let reviewed = EchoContact(givenName: "Mina", relationshipDomain: .personal)

        XCTAssertFalse(unreviewed.isEligibleForTodaysEcho)
        XCTAssertTrue(reviewed.isEligibleForTodaysEcho)
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

    func testMemorySearchMatchesChineseNameWithDifferentHomophoneCharacters() {
        let target = EchoContact(givenName: "茅勤", companyName: "Echo")
        let distractor = EchoContact(givenName: "马强", companyName: "Northstar")

        let matches = RecallSearchEngine.search(
            description: "我想找毛琴，之前聊过产品",
            contacts: [distractor, target]
        )

        XCTAssertEqual(matches.first?.contact.systemIdentifier, target.systemIdentifier)
        XCTAssertTrue(matches.first?.matchedKeywords.contains("similar-sounding name") == true)
        XCTAssertTrue(matches.first?.evidence.contains("a similar-sounding name") == true)
    }

    func testMemorySearchToleratesOneSmallPinyinRecognitionDifference() {
        let target = EchoContact(givenName: "茅勤")

        let matches = RecallSearchEngine.search(
            description: "帮我找一下茅青",
            contacts: [target]
        )

        XCTAssertEqual(matches.first?.contact.systemIdentifier, target.systemIdentifier)
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

        XCTAssertEqual(EchoEngine.recencyAttentionScore(for: contact), 100)
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

    func testStaleContactNeedsInclusionDecisionOnlyWhenLastContactIsKnown() {
        let unknown = EchoContact(givenName: "Unknown history")
        XCTAssertFalse(unknown.needsEchoInclusionReview)

        let stale = EchoContact(
            givenName: "Stale",
            lastReachedOut: Calendar.current.date(byAdding: .day, value: -101, to: .now)
        )
        XCTAssertTrue(stale.needsEchoInclusionReview)
        stale.lastEchoInclusionReviewedAt = .now
        XCTAssertFalse(stale.needsEchoInclusionReview)
        stale.lastReachedOut = Calendar.current.date(byAdding: .day, value: -102, to: .now)
        XCTAssertFalse(stale.needsEchoInclusionReview)
    }

    func testReflectionThemesUseDifferentDecisionBoundaries() {
        XCTAssertFalse(ReflectionTheme.protect.intentChoices.contains(.pause))
        XCTAssertEqual(ReflectionTheme.boundaries.intentChoices.first, .pause)
        XCTAssertEqual(ReflectionTheme.lighten.intentChoices.first, .light)
        XCTAssertNotEqual(ReflectionTheme.protect.intentChoices, ReflectionTheme.boundaries.intentChoices)
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
            for: EchoContact.self, Interaction.self, EchoNote.self, Deal.self, RelationshipReflection.self, RelationshipAction.self, ReflectionJourney.self,
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

    func testLegacyDemoCleanupPreservesRealContacts() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: EchoContact.self, Interaction.self, EchoNote.self, Deal.self, RelationshipReflection.self, RelationshipAction.self, ReflectionJourney.self,
            configurations: configuration
        )

        let demo = DemoContactFactory.makeContact(index: 0)
        let real = EchoContact(
            systemIdentifier: "real-contact",
            givenName: "Real",
            familyName: "Person",
            emailAddress: "real@gmail.com"
        )
        container.mainContext.insert(demo)
        container.mainContext.insert(real)
        container.mainContext.insert(Deal(title: "Demo deal", contact: demo))
        try container.mainContext.save()

        DemoData.removeLegacyDemoContacts(in: container.mainContext)

        let contacts = try container.mainContext.fetch(FetchDescriptor<EchoContact>())
        let deals = try container.mainContext.fetch(FetchDescriptor<Deal>())
        XCTAssertEqual(contacts.map(\.systemIdentifier), ["real-contact"])
        XCTAssertTrue(deals.isEmpty)
    }

    func testSocialMessagingBuildsSafeDestinations() throws {
        let telegram = try XCTUnwrap(SocialMessagingService.destination(
            for: .telegram,
            identifier: "@echo_friend",
            draft: "Hello there"
        ))
        XCTAssertEqual(telegram.url.host, "t.me")
        XCTAssertTrue(telegram.url.absoluteString.contains("text=Hello%20there"))
        XCTAssertTrue(telegram.draftWasIncluded)

        let linkedin = try XCTUnwrap(SocialMessagingService.destination(
            for: .linkedin,
            identifier: "https://www.linkedin.com/in/qin-mao/",
            draft: "Hello"
        ))
        XCTAssertEqual(linkedin.url.absoluteString, "https://www.linkedin.com/in/qin-mao")
        XCTAssertFalse(linkedin.draftWasIncluded)
    }

    func testPhoneCallBuildsSafeDialerDestination() throws {
        let destination = try XCTUnwrap(
            PhoneCallService.destination(for: "+852 (9123) 4567")
        )

        XCTAssertEqual(destination.absoluteString, "tel:+85291234567")
        XCTAssertNil(PhoneCallService.destination(for: "not a phone"))
    }

    func testAPIKeyDiagnosticReportsPresenceWithoutExposingValue() async throws {
        let router = AIModelRouter(defaults: nil)
        let configured = APIKeyDiagnosticService(
            keyStore: DiagnosticKeyStore(value: "secret-value"),
            client: DiagnosticAIClient(),
            router: router
        )
        let missing = APIKeyDiagnosticService(
            keyStore: DiagnosticKeyStore(value: nil),
            client: DiagnosticAIClient(),
            router: router
        )

        XCTAssertEqual(configured.presence(), .configured)
        XCTAssertEqual(missing.presence(), .notConfigured)
        let model = try await configured.testConnection()
        XCTAssertEqual(model, "diagnostic-model")
    }

    func testVCFImportPreviewsAndDeduplicatesByEmailAndPhone() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: EchoContact.self, Interaction.self, EchoNote.self, Deal.self, RelationshipReflection.self, RelationshipAction.self, ReflectionJourney.self,
            configurations: configuration
        )
        let existing = EchoContact(
            systemIdentifier: "existing-ava",
            givenName: "Ava",
            familyName: "Chen",
            emailAddress: "AVA@EXAMPLE.COM"
        )
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let vCard = """
        BEGIN:VCARD
        VERSION:3.0
        N:Chen;Ava;;;
        FN:Ava Chen
        EMAIL;TYPE=INTERNET:ava@example.com
        ORG:Harbor Insurance
        END:VCARD
        BEGIN:VCARD
        VERSION:3.0
        N:Chen;Ava;;;
        FN:Ava Chen
        TEL;TYPE=CELL:+852 9123 4567
        EMAIL;TYPE=INTERNET:ava@example.com
        END:VCARD
        BEGIN:VCARD
        VERSION:3.0
        N:Wong;Ben;;;
        FN:Ben Wong
        TEL;TYPE=CELL:+852 6000 1000
        ORG:Northstar Limited
        END:VCARD
        """
        let service = VCFImportService()
        let data = try XCTUnwrap(vCard.data(using: .utf8))
        let preview = try service.preview(
            data: data,
            fileName: "contacts.vcf",
            in: container.mainContext
        )

        XCTAssertEqual(preview.contacts.count, 2)
        XCTAssertEqual(preview.newCount, 1)
        XCTAssertEqual(preview.updateCount, 1)
        XCTAssertEqual(preview.unchangedCount, 0)
        let ben = try XCTUnwrap(preview.contacts.first { $0.emailAddress == nil })
        XCTAssertEqual(ben.relationshipDomain, .business)

        let result = try service.importContacts(
            preview,
            relationshipOverrides: [ben.id: .personal],
            into: container.mainContext
        )
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(existing.phoneNumber, "+852 9123 4567")
        XCTAssertEqual(existing.companyName, "Harbor Insurance")
        let importedBen = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<EchoContact>())
                .first { $0.phoneNumber == "+852 6000 1000" }
        )
        XCTAssertEqual(importedBen.relationshipDomain, .personal)

        let secondPreview = try service.preview(
            data: data,
            fileName: "contacts.vcf",
            in: container.mainContext
        )
        XCTAssertEqual(secondPreview.newCount, 0)
        XCTAssertEqual(secondPreview.updateCount, 0)
        XCTAssertEqual(secondPreview.unchangedCount, 2)
    }

    func testVCFContactWithoutANameStaysUnnamedAndOutOfTodaysEcho() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: EchoContact.self, Interaction.self, EchoNote.self, Deal.self, RelationshipReflection.self, RelationshipAction.self, ReflectionJourney.self,
            configurations: configuration
        )
        let vCard = """
        BEGIN:VCARD
        VERSION:3.0
        N:;;;;
        FN:
        TEL;TYPE=CELL:18111090503
        END:VCARD
        """
        let service = VCFImportService()
        let preview = try service.preview(
            data: try XCTUnwrap(vCard.data(using: .utf8)),
            fileName: "nameless.vcf",
            in: container.mainContext
        )

        XCTAssertEqual(preview.contacts.first?.fullName, "未命名联系人")
        _ = try service.importContacts(preview, into: container.mainContext)

        let imported = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<EchoContact>()).first
        )
        XCTAssertEqual(imported.givenName, "")
        XCTAssertEqual(imported.fullName, "未命名联系人")
        XCTAssertFalse(imported.isEligibleForTodaysEcho)
    }

    func testRelationshipIntentRawValueRoundTripsAndLegacyContactIsUnreviewed() {
        for intent in RelationshipIntent.allCases {
            XCTAssertEqual(RelationshipIntent(rawValue: intent.rawValue), intent)
        }
        let legacy = EchoContact(givenName: "Legacy")
        XCTAssertNil(legacy.relationshipIntent)
        XCTAssertNil(legacy.desiredCadenceDays)
        XCTAssertNil(legacy.lastRelationshipReviewAt)
        XCTAssertFalse(legacy.relationshipJourneyIncluded)
    }

    func testIntentChangeCreatesReflectionHistory() throws {
        let container = try relationshipContainer()
        let contact = EchoContact(givenName: "Maya")
        container.mainContext.insert(contact)
        let service = RelationshipJourneyService()
        _ = try service.review(contact: contact, intent: .deepen, contextText: "Old friend", theme: .protect, journey: nil, in: container.mainContext)
        _ = try service.review(contact: contact, intent: .maintain, contextText: "Feels steady", theme: .ongoing, journey: nil, in: container.mainContext)
        XCTAssertEqual(contact.relationshipReflections.count, 2)
        XCTAssertEqual(contact.relationshipReflections.sorted { $0.createdAt < $1.createdAt }.last?.previousIntent, .deepen)
        XCTAssertEqual(contact.relationshipIntent, .maintain)
    }

    func testJourneyWeekOrderRecoveryAndRestartPreserveData() throws {
        let container = try relationshipContainer()
        let contact = EchoContact(givenName: "Ari")
        let oldNote = EchoNote(content: "Keep me", contact: contact)
        contact.notes.append(oldNote)
        container.mainContext.insert(contact)
        let service = RelationshipJourneyService()
        let first = try service.startJourney(in: container.mainContext)
        XCTAssertEqual(first.currentTheme, .protect)
        first.activeStepRawValue = "2"
        try container.mainContext.save()
        XCTAssertEqual(try service.activeJourney(in: container.mainContext)?.activeStepRawValue, "2")
        for expected in [ReflectionTheme.protect, .reconnect, .lighten, .boundaries] {
            XCTAssertEqual(first.currentTheme, expected)
            try service.completeWeek(first, in: container.mainContext)
        }
        XCTAssertTrue(first.isComplete)
        let restarted = try service.restartJourney(in: container.mainContext)
        XCTAssertNotEqual(first.id, restarted.id)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<EchoContact>()).count, 1)
        XCTAssertEqual(contact.notes.first?.content, "Keep me")
    }

    func testCompletingAWeekClearsDraftProgressWithoutCreatingFailureState() throws {
        let container = try relationshipContainer()
        let service = RelationshipJourneyService()
        let journey = try service.startJourney(in: container.mainContext)
        journey.selectedContactIdentifiers = ["person-1"]
        journey.draftIntentValues = ["person-1", RelationshipIntent.deepen.rawValue]
        journey.draftContextValues = ["person-1", "Old friend"]
        journey.activeStepRawValue = "2"

        try service.completeWeek(journey, in: container.mainContext)

        XCTAssertEqual(journey.currentWeekIndex, 2)
        XCTAssertEqual(journey.currentTheme, .reconnect)
        XCTAssertNil(journey.activeStepRawValue)
        XCTAssertTrue(journey.selectedContactIdentifiers.isEmpty)
        XCTAssertTrue(journey.draftIntentValues?.isEmpty == true)
        XCTAssertTrue(journey.draftContextValues?.isEmpty == true)
        XCTAssertFalse(journey.isComplete)
    }

    func testGuidanceRespectsPauseAndChosenCadence() {
        let old = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let paused = EchoContact(givenName: "Pause")
        paused.relationshipJourneyIncluded = true; paused.relationshipIntent = .pause; paused.desiredCadenceDays = 7; paused.lastRelationshipReviewAt = old
        let deepen = EchoContact(givenName: "Deepen")
        deepen.relationshipJourneyIncluded = true; deepen.relationshipIntent = .deepen; deepen.desiredCadenceDays = 30; deepen.lastRelationshipReviewAt = old
        let maintain = EchoContact(givenName: "Maintain")
        maintain.relationshipJourneyIncluded = true; maintain.relationshipIntent = .maintain; maintain.desiredCadenceDays = 30; maintain.lastRelationshipReviewAt = old
        let ids = RelationshipGuidanceEngine.guidance(for: [paused, deepen, maintain]).map(\.contactIdentifier)
        XCTAssertFalse(ids.contains(paused.systemIdentifier))
        XCTAssertTrue(ids.contains(deepen.systemIdentifier))
        XCTAssertTrue(ids.contains(maintain.systemIdentifier))
    }

    func testLocalInsightsUseOnlyRecordedLocalSignalsWithoutAIKey() {
        let contact = EchoContact(givenName: "Mina")
        contact.relationshipJourneyIncluded = true
        contact.relationshipIntent = .deepen
        contact.lastRelationshipReviewAt = .now
        let insights = RelationshipGuidanceEngine.insights(contacts: [contact], journeys: [])
        XCTAssertTrue(insights.contains { $0.kind == .intentionAheadOfAction })
        XCTAssertFalse(insights.isEmpty)
    }

    func testRelationshipActionPlanCompleteCancelAndReview() throws {
        let container = try relationshipContainer()
        let contact = EchoContact(givenName: "Noah")
        container.mainContext.insert(contact)
        let service = RelationshipJourneyService()
        let completed = try service.planAction(for: contact, type: .call, journey: nil, in: container.mainContext)
        try service.completeAction(completed, in: container.mainContext)
        XCTAssertEqual(completed.status, .completed)
        XCTAssertNotNil(try service.recordOutcome(.closer, for: completed, in: container.mainContext))
        let cancelled = try service.planAction(for: contact, type: .message, journey: nil, in: container.mainContext)
        try service.cancelAction(cancelled, in: container.mainContext)
        XCTAssertEqual(cancelled.status, .skipped)
    }

    func testReminderReschedulesAndCancels() async throws {
        let scheduler = RecordingNotificationScheduler()
        let service = ReminderService(scheduler: scheduler)
        try await service.scheduleWeekly(weekday: 2, hour: 9, minute: 30)
        XCTAssertEqual(scheduler.scheduled.last?.identifier, ReminderService.weeklyIdentifier)
        XCTAssertTrue(scheduler.cancelled.contains(ReminderService.weeklyIdentifier))
        service.cancelWeekly()
        XCTAssertEqual(scheduler.cancelled.filter { $0 == ReminderService.weeklyIdentifier }.count, 2)
    }

    func testActionAndReviewRemindersOnlyScheduleForEligibleActionsAndCancelTogether() async throws {
        let scheduler = RecordingNotificationScheduler()
        let service = ReminderService(scheduler: scheduler)
        let contact = EchoContact(givenName: "Alex")
        let action = RelationshipAction(
            plannedFor: Date(timeIntervalSince1970: 1_800_000_000),
            type: .call,
            status: .planned,
            contact: contact
        )

        try await service.scheduleAction(action, contactName: contact.fullName)
        XCTAssertEqual(scheduler.scheduled.last?.identifier, ReminderService.actionPrefix + action.id.uuidString)

        action.status = .completed
        try await service.scheduleReview(for: action, date: Date(timeIntervalSince1970: 1_800_086_400))
        XCTAssertEqual(scheduler.scheduled.last?.identifier, ReminderService.reviewPrefix + action.id.uuidString)

        service.cancelAction(action)
        XCTAssertTrue(scheduler.cancelled.contains(ReminderService.actionPrefix + action.id.uuidString))
        XCTAssertTrue(scheduler.cancelled.contains(ReminderService.reviewPrefix + action.id.uuidString))
    }

    func testOngoingQuestionsIncreaseInDepthWithoutExceedingTheBank() {
        XCTAssertEqual(
            OngoingReflectionQuestionBank.question(completedReflectionCount: 0),
            String(localized: "Who has unexpectedly come to mind lately?")
        )
        XCTAssertEqual(
            OngoingReflectionQuestionBank.question(completedReflectionCount: 100),
            String(localized: "Who do you hope will still be beside you three years from now?")
        )
        XCTAssertGreaterThanOrEqual(OngoingReflectionQuestionBank.questions.count, 9)
    }

    func testProductionStartupDoesNotSeedOrSyncGmail() {
        XCTAssertFalse(AppStartupPolicy.seedsDemoData)
        XCTAssertFalse(AppStartupPolicy.automaticallySyncsGmail)
    }

    func testSelectedContactKeysExcludeNotes() {
        XCTAssertFalse(SelectedContactImportService.requestedKeys.contains(CNContactNoteKey))
        XCTAssertFalse(ContactImportService.requestedKeys.contains(CNContactNoteKey))
        XCTAssertTrue(SelectedContactImportService.requestedKeys.contains(CNContactGivenNameKey))
        XCTAssertTrue(SelectedContactImportService.requestedKeys.contains(CNContactThumbnailImageDataKey))
        XCTAssertEqual(Set(SelectedContactImportService.requestedKeys), Set([
            CNContactIdentifierKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactOrganizationNameKey,
            CNContactJobTitleKey,
            CNContactThumbnailImageDataKey,
        ]))
    }

    func testPipelineCreationAndMultiplePipelinesPersist() throws {
        let container = try agenticContainer()
        container.mainContext.insert(Pipeline(name: "Recruiting", objective: "Meet a teammate"))
        container.mainContext.insert(Pipeline(name: "Projects", objective: "Move meaningful work forward", autonomyLevel: .manual))
        try container.mainContext.save()

        let stored = try container.mainContext.fetch(FetchDescriptor<Pipeline>())
        XCTAssertEqual(Set(stored.map(\.name)), ["Recruiting", "Projects"])
        XCTAssertEqual(stored.first { $0.name == "Projects" }?.autonomyLevel, .manual)
        XCTAssertEqual(stored.first?.stages, DealStage.defaultAgenticStages)
    }

    func testOrganizationSupportsMultipleContactsAndItems() throws {
        let container = try agenticContainer()
        let organization = Organization(name: "Northstar", industry: "Design")
        let first = EchoContact(givenName: "Mina"); let second = EchoContact(givenName: "Noah")
        first.organization = organization; second.organization = organization
        let pipeline = Pipeline(name: "Partnerships")
        let item = Deal(title: "Shared studio", contact: first, pipeline: pipeline,
                        organization: organization, relatedContacts: [first, second])
        container.mainContext.insert(organization); container.mainContext.insert(first)
        container.mainContext.insert(second); container.mainContext.insert(pipeline); container.mainContext.insert(item)
        try container.mainContext.save()

        let stored = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Organization>()).first)
        XCTAssertEqual(Set(stored.contacts.map(\.givenName)), ["Mina", "Noah"])
        XCTAssertEqual(stored.pipelineItems.first?.title, "Shared studio")
        XCTAssertEqual(item.allContacts.count, 2)
    }

    func testPipelineItemCanBeNonMonetaryAndCurrencyIsOptionalBehavior() {
        let nonMonetary = Deal(title: "Introduce two friends")
        let monetary = Deal(title: "Renewal", value: 15_000, currency: "HKD")
        XCTAssertFalse(nonMonetary.hasMonetaryValue)
        XCTAssertTrue(monetary.hasMonetaryValue)
        XCTAssertEqual(monetary.resolvedCurrency, "HKD")
    }

    func testStageTransitionIsAuditedAndHumanAttentionIsFirstClass() throws {
        let container = try agenticContainer()
        let item = Deal(title: "Potential collaboration", stage: .qualified)
        container.mainContext.insert(item); try container.mainContext.save()

        try PipelineService().transition(item, to: .humanAttention, source: "Test agent", in: container.mainContext)
        XCTAssertEqual(item.stage, .humanAttention)
        XCTAssertTrue(item.humanAttentionRequired)
        XCTAssertEqual(item.agentActions.first?.actionType, .stageChange)
        XCTAssertTrue(item.agentActions.first?.summary.contains("Qualified") == true)

        item.status = .won
        try PipelineService().transition(item, to: .engaged, source: "Test agent", in: container.mainContext)
        XCTAssertEqual(item.status, .active)

        try PipelineService().setHumanAttention(false, for: item, reason: "Reviewed", in: container.mainContext)
        XCTAssertFalse(item.humanAttentionRequired)
        XCTAssertEqual(item.agentActions.filter { $0.actionType == .escalation }.count, 1)
    }

    func testAgentIntelligenceActionAndEvidencePersistSeparatelyFromHumanNotes() throws {
        let container = try agenticContainer()
        let item = Deal(title: "Partnership", humanNotes: "Met at a conference")
        let intelligence = AgentIntelligence(score: 91, confidence: 0.82, summary: "Strong mutual fit",
                                             whyItMatters: "Two warm introductions", pipelineItem: item)
        let evidence = Evidence(title: "Public profile", url: "https://example.com", sourceType: .web,
                                excerptOrSummary: "Leadership biography", intelligence: intelligence)
        let action = AgentAction(actionType: .research, summary: "Reviewed public profile", source: "Research provider", pipelineItem: item)
        item.intelligence = intelligence
        container.mainContext.insert(item); container.mainContext.insert(intelligence)
        container.mainContext.insert(evidence); container.mainContext.insert(action)
        try container.mainContext.save()

        let stored = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Deal>()).first)
        XCTAssertEqual(stored.humanNotes, "Met at a conference")
        XCTAssertEqual(stored.intelligence?.score, 91)
        XCTAssertEqual(stored.intelligence?.evidence.first?.sourceType, .web)
        XCTAssertEqual(stored.agentActions.first?.source, "Research provider")
    }

    func testInteractionActorAndDirectionMetadataPersist() throws {
        let container = try agenticContainer()
        let interaction = Interaction(type: .emailed, summary: "Reply received", source: "gmail",
                                      actor: .external, direction: .inbound)
        let legacy = Interaction(type: .messaged, summary: "Legacy reply", isIncoming: true)
        legacy.actorRawValue = nil; legacy.directionRawValue = nil
        container.mainContext.insert(interaction); container.mainContext.insert(legacy); try container.mainContext.save()
        let stored = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Interaction>()).first { $0.summary == "Reply received" })
        XCTAssertEqual(stored.actor, .external)
        XCTAssertEqual(stored.direction, .inbound)
        XCTAssertEqual(legacy.actor, .human)
        XCTAssertEqual(legacy.direction, .inbound)
    }

    func testAcceptanceFixtureCoversOrganizationsStagesActionsAndInteractionsIdempotently() throws {
        let container = try agenticContainer()
        let service = PipelineService()
        try service.seedAcceptanceScenario(in: container.mainContext)
        try service.seedAcceptanceScenario(in: container.mainContext)

        let organizations = try container.mainContext.fetch(FetchDescriptor<Organization>())
        let items = try container.mainContext.fetch(FetchDescriptor<Deal>())
        let interactions = try container.mainContext.fetch(FetchDescriptor<Interaction>())
        let actions = try container.mainContext.fetch(FetchDescriptor<AgentAction>())
        XCTAssertEqual(organizations.count, 2)
        XCTAssertTrue(organizations.allSatisfy { $0.contacts.count == 2 })
        XCTAssertEqual(Set(items.map(\.stage)), [.qualified, .opportunity])
        XCTAssertEqual(items.filter(\.humanAttentionRequired).count, 1)
        XCTAssertEqual(interactions.count, 2)
        XCTAssertGreaterThanOrEqual(actions.filter { $0.actionType == .stageChange }.count, 4)
        XCTAssertEqual(items.filter { $0.title == "Potential Partnership" }.first?.intelligence?.evidence.count, 1)
    }

    func testExistingDealMigrationAssignsDefaultPipelineAndOrganization() throws {
        let container = try agenticContainer()
        let contact = EchoContact(givenName: "Ava", companyName: "Harbor")
        let legacy = Deal(title: "Legacy renewal", value: 5000, stage: .quoted, contact: contact)
        legacy.pipeline = nil; legacy.organization = nil; legacy.updatedAt = nil; legacy.valueIsSet = nil
        container.mainContext.insert(contact); container.mainContext.insert(legacy); try container.mainContext.save()

        let pipeline = try PipelineService().migrateExistingData(in: container.mainContext)
        XCTAssertEqual(legacy.pipeline?.id, pipeline.id)
        XCTAssertEqual(legacy.organization?.name, "Harbor")
        XCTAssertEqual(contact.organization?.name, "Harbor")
        XCTAssertTrue(legacy.hasMonetaryValue)
        XCTAssertEqual(legacy.stage, .quoted)
    }

    func testPipelineFilteringAndSortingBusinessLogic() {
        let pipeline = Pipeline(name: "Main")
        let other = Pipeline(name: "Other")
        let organization = Organization(name: "Echo")
        let urgent = Deal(title: "Urgent", stage: .engaged, nextActionDate: Date(timeIntervalSince1970: 100), pipeline: pipeline, organization: organization, priority: .urgent, humanAttentionRequired: true)
        urgent.intelligence = AgentIntelligence(score: 75, pipelineItem: urgent)
        let highScore = Deal(title: "High score", stage: .qualified, pipeline: pipeline, organization: organization, priority: .low)
        highScore.intelligence = AgentIntelligence(score: 95, pipelineItem: highScore)
        let unrelated = Deal(title: "Elsewhere", pipeline: other)
        let source = [highScore, unrelated, urgent]

        let attention = PipelineQuery.items(source, matching: PipelineFilter(pipelineID: pipeline.id, humanAttentionOnly: true), sortedBy: .newest)
        XCTAssertEqual(attention.map(\.title), ["Urgent"])
        let byPriority = PipelineQuery.items(source, matching: PipelineFilter(pipelineID: pipeline.id), sortedBy: .priority)
        XCTAssertEqual(byPriority.first?.title, "Urgent")
        let byScore = PipelineQuery.items(source, matching: PipelineFilter(pipelineID: pipeline.id), sortedBy: .aiScore)
        XCTAssertEqual(byScore.first?.title, "High score")
    }

    func testCustomPipelineStagesRenameReorderFilterAndProtectUsedData() throws {
        let container = try agenticContainer()
        let pipeline = Pipeline(name: "Custom workflow")
        let item = Deal(title: "Review relationship", stage: .qualified, pipeline: pipeline)
        container.mainContext.insert(pipeline); container.mainContext.insert(item)
        try container.mainContext.save()

        try PipelineService().updateStages(
            for: pipeline,
            orderedNames: [DealStage.discovered.rawValue, "Review", DealStage.won.rawValue, DealStage.lost.rawValue],
            renames: [DealStage.qualified.rawValue: "Review"],
            in: container.mainContext
        )
        XCTAssertEqual(pipeline.stageDefinitions.map(\.title), ["Discovered", "Review", "Won", "Lost"])
        XCTAssertEqual(item.stageIdentifier, "Review")
        XCTAssertEqual(
            PipelineQuery.items([item], matching: PipelineFilter(stageIdentifier: "Review"), sortedBy: .newest).map(\.title),
            ["Review relationship"]
        )

        XCTAssertThrowsError(try PipelineService().updateStages(
            for: pipeline,
            orderedNames: [DealStage.discovered.rawValue, DealStage.won.rawValue, DealStage.lost.rawValue],
            renames: [:],
            in: container.mainContext
        ))
        XCTAssertEqual(item.stageIdentifier, "Review")
    }

    func testDeepSeekPipelineAgentPersistsStructuredIntelligenceAndAudit() async throws {
        let container = try agenticContainer()
        let organization = Organization(name: "Private Company")
        let contact = EchoContact(givenName: "Ava", familyName: "Lee", companyName: organization.name)
        contact.organization = organization
        let item = Deal(title: "Potential collaboration", contact: contact,
                        organization: organization, humanNotes: "Met at an event", relatedContacts: [contact])
        container.mainContext.insert(organization); container.mainContext.insert(contact); container.mainContext.insert(item)
        try container.mainContext.save()
        let client = PipelineAIClient(text: #"{"score":82,"confidence":0.7,"intent_level":"medium","summary":"Useful context","why_it_matters":"A follow-up is timely","recommended_next_action":"Ask for a short call","risk_notes":"Budget is unknown"}"#)
        let features = EchoAIFeatures(service: AIService(client: client, router: AIModelRouter(defaults: nil)))

        try await DeepSeekPipelineAgentService(features: features).evaluate(item: item, in: container.mainContext)

        XCTAssertEqual(item.intelligence?.score, 82)
        XCTAssertEqual(item.intelligence?.recommendedNextAction, "Ask for a short call")
        XCTAssertEqual(item.humanNotes, "Met at an event")
        XCTAssertEqual(item.agentActions.last?.status, .completed)
        let requestedModel = await client.requestedTaskModel
        XCTAssertEqual(requestedModel, "deepseek-v4-pro")
    }

    func testResearchCoordinatorPersistsEvidenceAndCompletedAudit() async throws {
        let container = try agenticContainer()
        let organization = Organization(name: "Source Org", website: "https://example.com")
        let item = Deal(title: "Research", organization: organization)
        container.mainContext.insert(organization); container.mainContext.insert(item); try container.mainContext.save()

        try await PipelineResearchCoordinator().research(item: item, provider: PipelineResearchStub(), in: container.mainContext)

        XCTAssertEqual(item.intelligence?.evidence.first?.sourceType, .web)
        XCTAssertEqual(item.intelligence?.evidence.first?.url, "https://example.com")
        XCTAssertEqual(item.agentActions.first?.status, .completed)
    }

    func testApprovedEmailIsRecordedOnlyAfterProviderSuccess() async throws {
        let container = try agenticContainer()
        let contact = EchoContact(givenName: "Mina", emailAddress: "mina@example.com")
        let item = Deal(title: "Follow-up", contact: contact)
        container.mainContext.insert(contact); container.mainContext.insert(item); try container.mainContext.save()
        let outreach = PreparedOutreach(subject: "Hello", body: "A reviewed message", model: "test-model")
        let sentAt = Date(timeIntervalSince1970: 1_800_000_000)

        _ = try await PipelineEmailService().send(outreach, for: item,
            using: PipelineEmailStub(result: .success(OutreachDeliveryReceipt(externalIdentifier: "message-1", sentAt: sentAt))),
            in: container.mainContext)

        let interactions = try container.mainContext.fetch(FetchDescriptor<Interaction>())
        XCTAssertEqual(interactions.count, 1)
        XCTAssertEqual(interactions.first?.direction, .outbound)
        XCTAssertEqual(interactions.first?.externalIdentifier, "gmail:message-1:\(contact.systemIdentifier)")
        XCTAssertEqual(item.agentActions.filter { $0.status == .completed }.count, 1)

        do {
            _ = try await PipelineEmailService().send(outreach, for: item,
                using: PipelineEmailStub(result: .failure(PipelineEmailTestError.rejected)),
                in: container.mainContext)
            XCTFail("A rejected provider must throw")
        } catch { }
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Interaction>()).count, 1)
        XCTAssertEqual(item.agentActions.filter { $0.status == .failed }.count, 1)
    }

    func testGmailMessageEncodingPreventsHeaderInjectionAndPreservesUnicode() throws {
        XCTAssertThrowsError(try GmailMessageEncoder.encodedMessage(
            to: "person@example.com\r\nBcc: attacker@example.com",
            subject: "Hello",
            body: "Body"
        ))
        let raw = try GmailMessageEncoder.encodedMessage(
            to: "person@example.com",
            subject: "你好\r\nBcc: hidden@example.com",
            body: "关系跟进：下周见"
        )
        let padded = raw.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - raw.count % 4) % 4)
        let decodedData = try XCTUnwrap(Data(base64Encoded: padded))
        let decoded = String(decoding: decodedData, as: UTF8.self)

        XCTAssertTrue(decoded.contains("To: person@example.com\r\n"))
        XCTAssertFalse(decoded.contains("\r\nBcc: hidden@example.com\r\n"))
        XCTAssertTrue(decoded.contains("Content-Type: text/plain; charset=UTF-8"))
    }

    private func agenticContainer() throws -> ModelContainer {
        try ModelContainer(
            for: EchoContact.self, Interaction.self, EchoNote.self, Deal.self,
            RelationshipReflection.self, RelationshipAction.self, ReflectionJourney.self,
            Pipeline.self, Organization.self, AgentIntelligence.self, AgentAction.self, Evidence.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func relationshipContainer() throws -> ModelContainer {
        try ModelContainer(
            for: EchoContact.self, Interaction.self, EchoNote.self, Deal.self, RelationshipReflection.self, RelationshipAction.self, ReflectionJourney.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

private final class RecordingNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    var scheduled: [EchoReminderRequest] = []
    var cancelled: [String] = []
    func requestAuthorization() async throws -> Bool { true }
    func schedule(_ request: EchoReminderRequest) async throws { scheduled.append(request) }
    func cancel(identifiers: [String]) { cancelled.append(contentsOf: identifiers) }
}

private actor PipelineAIClient: AIProviderClient {
    let text: String
    private(set) var requestedTaskModel: AIModelID?
    init(text: String) { self.text = text }
    func complete(messages: [AIMessage], model: AIModelID, options: AICompletionOptions) async throws -> AIResult {
        requestedTaskModel = model
        return AIResult(text: text, model: model)
    }
}

private struct PipelineResearchStub: ResearchProvider {
    func research(organization: Organization) async throws -> [Evidence] {
        [Evidence(title: "Source", url: organization.website, sourceType: .web, excerptOrSummary: "Verified fixture")]
    }
}

private enum PipelineEmailTestError: Error { case rejected }
private enum PersistenceTestFailure: Error { case unavailable }
private struct PipelineEmailStub: EmailDeliveryProvider {
    let result: Result<OutreachDeliveryReceipt, Error>
    func send(_ outreach: PreparedOutreach, to recipient: String) async throws -> OutreachDeliveryReceipt {
        try result.get()
    }
}

private struct DiagnosticKeyStore: AIAPIKeyStore {
    let value: String?
    func readAPIKey() throws -> String? { value }
    func saveAPIKey(_ apiKey: String) throws {}
    func deleteAPIKey() throws {}
}

private struct DiagnosticAIClient: AIProviderClient {
    func complete(
        messages: [AIMessage],
        model: AIModelID,
        options: AICompletionOptions
    ) async throws -> AIResult {
        AIResult(text: "OK", model: "diagnostic-model")
    }
}
