import Foundation
import SwiftData

@MainActor
enum DemoData {
    static let targetContactCount = 200
    static let reviewSampleContactPrefix = "echo.review.sample.contact."

    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<EchoContact>()
        var contacts = (try? context.fetch(descriptor)) ?? []

        if contacts.isEmpty {
            let curated = curatedContacts()
            curated.forEach(context.insert)
            contacts.append(contentsOf: curated)

            if let mike = curated.first(where: { $0.givenName == "Mike" }) {
                context.insert(Deal(title: "Family protection review", value: 12_000, stage: .quoted, nextActionDate: .now, contact: mike))
            }
            if let sarah = curated.first(where: { $0.givenName == "Sarah" }) {
                context.insert(Deal(title: "Founder benefits plan", value: 8_500, stage: .contacted, contact: sarah))
            }
        }

        var identifiers = Set(contacts.map(\.systemIdentifier))
        var index = 0

        while contacts.count < targetContactCount {
            let identifier = DemoContactFactory.identifier(for: index)
            defer { index += 1 }
            guard !identifiers.contains(identifier) else { continue }

            let contact = DemoContactFactory.makeContact(index: index)
            context.insert(contact)
            contacts.append(contact)
            identifiers.insert(identifier)

            if let deal = DemoContactFactory.makeDeal(index: index, contact: contact) {
                context.insert(deal)
            }
        }

        try? context.save()
    }

    /// Removes contacts shipped only for the early product demo. This is
    /// intentionally idempotent so upgraded installs are cleaned as well as
    /// fresh installs, without touching user-created or imported contacts.
    static func removeLegacyDemoContacts(in context: ModelContext) {
        let contacts = (try? context.fetch(FetchDescriptor<EchoContact>())) ?? []
        let demoContacts = contacts.filter(isLegacyDemoContact)
        guard !demoContacts.isEmpty else { return }

        let identifiers = Set(demoContacts.map(\.systemIdentifier))
        let deals = (try? context.fetch(FetchDescriptor<Deal>())) ?? []
        for deal in deals where deal.contact.map({ identifiers.contains($0.systemIdentifier) }) == true {
            context.delete(deal)
        }
        demoContacts.forEach(context.delete)
        try? context.save()
    }

    /// Adds a small, clearly fictional business workspace only after the user
    /// explicitly asks to explore the sample. Reserved `.invalid` addresses
    /// ensure the sample cannot accidentally reach a real inbox.
    static func seedReviewWorkspace(in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<EchoContact>())
        guard !existing.contains(where: { $0.systemIdentifier.hasPrefix(reviewSampleContactPrefix) }) else { return }

        let calendar = Calendar.current
        let prospect = EchoContact(
            systemIdentifier: reviewSampleContactPrefix + "prospect",
            givenName: "林嘉诚",
            emailAddress: "jiacheng.lin@qinghe.example.invalid",
            priority: .hot,
            relationshipDomain: .business,
            businessRole: .prospect,
            lastReachedOut: calendar.date(byAdding: .day, value: -12, to: .now),
            reachCount: 2,
            companyName: "青禾制造",
            jobTitle: "采购负责人"
        )
        prospect.tags = ["示例数据", "设备采购"]
        prospect.relationshipContext = "正在评估新一代生产设备，预计本月确定供应商。"
        prospect.notes.append(EchoNote(content: "已沟通产线升级计划；需要确认交付时间和售后服务范围。", contact: prospect))

        let client = EchoContact(
            systemIdentifier: reviewSampleContactPrefix + "client",
            givenName: "周雅雯",
            emailAddress: "yawen.zhou@xinghe.example.invalid",
            priority: .warm,
            relationshipDomain: .business,
            businessRole: .client,
            lastReachedOut: calendar.date(byAdding: .day, value: -5, to: .now),
            reachCount: 7,
            companyName: "星河零售",
            jobTitle: "运营总监"
        )
        client.tags = ["示例数据", "重点客户"]
        client.relationshipContext = "现有客户，正在讨论第二阶段门店部署。"

        let partner = EchoContact(
            systemIdentifier: reviewSampleContactPrefix + "partner",
            givenName: "陈思远",
            emailAddress: "siyuan.chen@lianchuang.example.invalid",
            priority: .warm,
            relationshipDomain: .business,
            businessRole: .partner,
            lastReachedOut: calendar.date(byAdding: .day, value: -21, to: .now),
            reachCount: 4,
            companyName: "联创科技",
            jobTitle: "渠道总经理"
        )
        partner.tags = ["示例数据", "渠道合作"]
        partner.relationshipContext = "正在讨论联合拓展华东地区的渠道合作。"

        [prospect, client, partner].forEach(context.insert)

        let firstDeal = Deal(
            title: "青禾制造 · 产线设备升级",
            value: 180_000,
            currency: "CNY",
            stage: .qualified,
            nextActionDate: calendar.date(byAdding: .day, value: 2, to: .now),
            nextActionNote: "发送交付周期和售后服务方案",
            contact: prospect,
            priority: .high,
            humanNotes: "仅用于产品体验的虚构商机"
        )
        let secondDeal = Deal(
            title: "星河零售 · 第二阶段部署",
            value: 96_000,
            currency: "CNY",
            stage: .opportunity,
            nextActionDate: calendar.date(byAdding: .day, value: 4, to: .now),
            nextActionNote: "预约方案评审会议",
            contact: client,
            priority: .medium,
            humanNotes: "仅用于产品体验的虚构商机"
        )
        context.insert(firstDeal)
        context.insert(secondDeal)

        context.insert(Interaction(
            date: calendar.date(byAdding: .day, value: -12, to: .now) ?? .now,
            type: .called,
            summary: "了解产线升级需求，并约定提供设备方案。",
            contact: prospect,
            source: "Echo 示例工作区",
            direction: .outbound,
            pipelineItem: firstDeal
        ))
        context.insert(Interaction(
            date: calendar.date(byAdding: .day, value: -5, to: .now) ?? .now,
            type: .emailed,
            summary: "发送第二阶段部署范围，客户希望进一步确认排期。",
            contact: client,
            source: "Echo 示例工作区",
            direction: .inbound,
            pipelineItem: secondDeal
        ))

        do {
            try context.save()
            _ = try PipelineService().migrateExistingData(in: context)
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Removes only the fictional records created by the opt-in sample mode.
    static func removeReviewWorkspaceSample(in context: ModelContext) throws {
        let contacts = try context.fetch(FetchDescriptor<EchoContact>())
        let sampleContacts = contacts.filter { $0.systemIdentifier.hasPrefix(reviewSampleContactPrefix) }
        guard !sampleContacts.isEmpty else { return }

        let identifiers = Set(sampleContacts.map(\.systemIdentifier))
        let deals = try context.fetch(FetchDescriptor<Deal>())
        for deal in deals where deal.allContacts.contains(where: { identifiers.contains($0.systemIdentifier) }) {
            context.delete(deal)
        }
        sampleContacts.forEach(context.delete)
        try context.save()
    }

    private static func isLegacyDemoContact(_ contact: EchoContact) -> Bool {
        if contact.systemIdentifier.hasPrefix("echo.demo.contact.") { return true }
        if contact.emailAddress?.lowercased().hasSuffix("@example.com") == true { return true }

        let curatedSignatures: Set<String> = [
            "Sarah|Chen|Northstar Studio",
            "Mike|Johnson|Harbor Financial",
            "Lisa|Park|",
        ]
        let signature = "\(contact.givenName)|\(contact.familyName)|\(contact.companyName ?? "")"
        guard curatedSignatures.contains(signature) else { return false }
        let demoPhrases = [
            "Her mom is recovering well",
            "Discussed a job change",
            "Monthly coaching session",
        ]
        return contact.notes.contains { note in
            demoPhrases.contains { note.content.contains($0) }
        }
    }

    private static func curatedContacts() -> [EchoContact] {
        let calendar = Calendar.current
        let sarah = EchoContact(
            givenName: "Sarah",
            familyName: "Chen",
            priority: .warm,
            lastReachedOut: calendar.date(byAdding: .day, value: -19, to: .now),
            reachCount: 8,
            companyName: "Northstar Studio",
            jobTitle: "Founder"
        )
        sarah.tags = ["Founder", "Client", "Design"]
        sarah.notes.append(EchoNote(content: "Her mom is recovering well. Check in this week.", contact: sarah))

        let mike = EchoContact(
            givenName: "Mike",
            familyName: "Johnson",
            priority: .hot,
            lastReachedOut: calendar.date(byAdding: .day, value: -7, to: .now),
            reachCount: 14,
            companyName: "Harbor Financial",
            jobTitle: "Advisor"
        )
        mike.tags = ["Advisor", "Client", "Finance"]
        mike.notes.append(EchoNote(content: "Discussed a job change and education planning.", contact: mike))

        let lisa = EchoContact(
            givenName: "Lisa",
            familyName: "Park",
            priority: .cold,
            lastReachedOut: calendar.date(byAdding: .day, value: -35, to: .now),
            reachCount: 5,
            jobTitle: "Mentor"
        )
        lisa.tags = ["Mentor", "Friend"]
        lisa.notes.append(EchoNote(content: "Monthly coaching session; ask about her upcoming talk.", contact: lisa))

        return [sarah, mike, lisa]
    }
}
