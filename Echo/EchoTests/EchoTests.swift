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
