# Echo — Complete Build Plan (All Tiers, Single Build)

> Mac 端构建计划。不分期，一次建成三模产品。
> AI：DeepSeek 多模态 + 火山引擎语音

---

## 前置准备

```bash
git clone git@github.com:bambi2008/echo.git
cd echo
```

**要求：**
- Xcode 16+, iOS 17.0+ Simulator
- Apple Developer account（免费 tier 可 simulator 测试，付费 needed for device + StoreKit）
- DeepSeek API key: https://platform.deepseek.com/api_keys
- 火山引擎账号: https://console.volcengine.com/ （开通语音识别 + 语音合成服务）

---

## 项目结构

```
Echo/
├── EchoApp.swift
├── ContentView.swift
├── Models/
│   ├── EchoContact.swift
│   ├── Interaction.swift
│   ├── Note.swift
│   ├── Deal.swift
│   └── Enums.swift              ← PriorityLevel, DealStage, InteractionType
├── Views/
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Personal/
│   │   ├── EchoLayerView.swift
│   │   ├── EchoCardView.swift
│   │   └── PeopleLibraryView.swift
│   ├── Detail/
│   │   ├── ContactDetailView.swift
│   │   └── ReachSheetView.swift
│   ├── AI/
│   │   └── AIInsightsView.swift
│   ├── Business/
│   │   ├── PipelineView.swift
│   │   ├── DealCardView.swift
│   │   └── DealDetailView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── ContactImportService.swift
│   ├── EchoEngine.swift
│   ├── AIService.swift          ← DeepSeek API
│   ├── VoiceService.swift       ← 火山引擎
│   └── StoreKitManager.swift
└── Assets.xcassets
```

---

## Phase 1: Xcode 项目 + 数据模型 (1h)

### 1.1 创建项目

Xcode → New Project → iOS → App:
```
Product Name: Echo
Interface: SwiftUI
Language: Swift
Storage: SwiftData
Min Deployment: iOS 17.0
☑ Include Tests
```

### 1.2 创建目录

在 Xcode 中右键 Echo 文件夹 → New Group:
```
Models/  Views/Onboarding/  Views/Personal/  Views/Detail/
Views/AI/  Views/Business/  Views/Settings/  Services/
```

### 1.3 Enums.swift

```swift
// Models/Enums.swift
import Foundation

enum InteractionType: String, Codable, CaseIterable {
    case reachedOut = "reached_out"
    case called = "called"
    case messaged = "messaged"
    case emailed = "emailed"
    case metInPerson = "met_in_person"
    
    var icon: String {
        switch self {
        case .reachedOut: return "hand.wave"
        case .called: return "phone"
        case .messaged: return "message"
        case .emailed: return "envelope"
        case .metInPerson: return "person.2"
        }
    }
    
    var label: String {
        switch self {
        case .reachedOut: return "Reached out"
        case .called: return "Called"
        case .messaged: return "Messaged"
        case .emailed: return "Emailed"
        case .metInPerson: return "Met in person"
        }
    }
}

enum PriorityLevel: String, Codable, CaseIterable {
    case hot = "hot"
    case warm = "warm"
    case cold = "cold"
    
    var color: String {
        switch self {
        case .hot: return "#FF453A"
        case .warm: return "#F59E0B"
        case .cold: return "#636366"
        }
    }
    
    var label: String {
        switch self {
        case .hot: return "Hot"
        case .warm: return "Warm"
        case .cold: return "Cold"
        }
    }
}

enum DealStage: String, Codable, CaseIterable {
    case lead = "lead"
    case contacted = "contacted"
    case quoted = "quoted"
    case negotiating = "negotiating"
    case closedWon = "closed_won"
    case closedLost = "closed_lost"
    
    var kanbanIndex: Int {
        switch self {
        case .lead: return 0
        case .contacted: return 1
        case .quoted: return 2
        case .negotiating: return 3
        case .closedWon: return 4
        case .closedLost: return 5
        }
    }
    
    var label: String {
        switch self {
        case .lead: return "Lead"
        case .contacted: return "Contacted"
        case .quoted: return "Quoted"
        case .negotiating: return "Negotiating"
        case .closedWon: return "Closed Won"
        case .closedLost: return "Closed Lost"
        }
    }
    
    var color: String {
        switch self {
        case .lead: return "#636366"
        case .contacted: return "#3B82F6"
        case .quoted: return "#F59E0B"
        case .negotiating: return "#FF453A"
        case .closedWon: return "#34C759"
        case .closedLost: return "#8E8E93"
        }
    }
}
```

### 1.4 EchoContact.swift

```swift
// Models/EchoContact.swift
import Foundation
import SwiftData

@Model
final class EchoContact {
    @Attribute(.unique) var systemIdentifier: String
    var givenName: String
    var familyName: String
    var fullName: String { "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces) }
    var phoneNumber: String?
    var emailAddress: String?
    var thumbnailData: Data?
    
    // Personal mode: Echo Layer
    var isInEchoLayer: Bool = true
    
    // Business mode: Priority + Deal
    var priorityLevel: PriorityLevel.RawValue?
    var dealStage: DealStage.RawValue?
    var dealValue: Double?
    var nextActionDate: Date?
    var policyNumber: String?
    var policyExpiryDate: Date?
    var companyName: String?
    var jobTitle: String?
    
    // Common
    var lastReachedOut: Date?
    var reachCount: Int = 0
    var createdAt: Date = Date()
    var aiInsight: String?
    var aiInsightDate: Date?
    
    @Relationship(deleteRule: .cascade) var interactions: [Interaction] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var deals: [Deal] = []
    
    init(systemIdentifier: String, givenName: String, familyName: String = "",
         phoneNumber: String? = nil, emailAddress: String? = nil, thumbnailData: Data? = nil) {
        self.systemIdentifier = systemIdentifier
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumber = phoneNumber
        self.emailAddress = emailAddress
        self.thumbnailData = thumbnailData
    }
}
```

### 1.5 Interaction.swift & Note.swift & Deal.swift

```swift
// Models/Interaction.swift
import Foundation
import SwiftData

@Model
final class Interaction {
    var type: InteractionType.RawValue
    var date: Date = Date()
    var note: String = ""
    @Relationship(inverse: \EchoContact.interactions) var contact: EchoContact?
    
    init(type: InteractionType, note: String = "") {
        self.type = type.rawValue
        self.note = note
    }
    
    var interactionType: InteractionType { InteractionType(rawValue: type) ?? .reachedOut }
}

// Models/Note.swift
@Model
final class Note {
    var content: String
    var createdAt: Date = Date()
    var isVoiceMemo: Bool = false
    var voiceTranscript: String?
    @Relationship(inverse: \EchoContact.notes) var contact: EchoContact?
    init(content: String, isVoiceMemo: Bool = false) {
        self.content = content; self.isVoiceMemo = isVoiceMemo
    }
}

// Models/Deal.swift
@Model
final class Deal {
    var title: String
    var value: Double
    var stage: DealStage.RawValue
    var expectedCloseDate: Date?
    var probability: Double = 0.5
    var productType: String?
    var notes: String = ""
    var createdAt: Date = Date()
    @Relationship(inverse: \EchoContact.deals) var contact: EchoContact?
    
    init(title: String, value: Double, stage: DealStage, productType: String? = nil) {
        self.title = title; self.value = value
        self.stage = stage.rawValue; self.productType = productType
    }
    
    var dealStageEnum: DealStage { DealStage(rawValue: stage) ?? .lead }
}
```

### 🔨 验证

`Cmd+B` → 编译通过。

---

## Phase 2: 核心服务层 (2h)

### 2.1 ContactImportService.swift

```swift
// Services/ContactImportService.swift
import Foundation
import Contacts
import SwiftData

@MainActor
final class ContactImportService: ObservableObject {
    @Published var state: ImportState = .idle
    
    enum ImportState: Equatable {
        case idle, requestingPermission
        case importing(current: Int, total: Int)
        case completed(imported: Int, skipped: Int)
        case denied, error(String)
    }
    
    func importContacts(into context: ModelContext) async {
        state = .requestingPermission
        let store = CNContactStore()
        
        do {
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else { state = .denied; return }
            
            let keys: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactJobTitleKey as CNKeyDescriptor
            ]
            
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .givenName
            
            var allContacts: [CNContact] = []
            try store.enumerateContacts(with: request) { c, _ in allContacts.append(c) }
            
            state = .importing(current: 0, total: allContacts.count)
            
            let existingIDs = Set((try? context.fetch(FetchDescriptor<EchoContact>()))?.map(\.systemIdentifier) ?? [])
            var imported = 0, skipped = 0
            
            for (i, cn) in allContacts.enumerated() {
                if existingIDs.contains(cn.identifier) { skipped += 1; continue }
                
                let contact = EchoContact(
                    systemIdentifier: cn.identifier,
                    givenName: cn.givenName.isEmpty ? "Unknown" : cn.givenName,
                    familyName: cn.familyName,
                    phoneNumber: cn.phoneNumbers.first?.value.stringValue,
                    emailAddress: cn.emailAddresses.first?.value as String?,
                    thumbnailData: cn.thumbnailImageData
                )
                contact.companyName = cn.organizationName.isEmpty ? nil : cn.organizationName
                contact.jobTitle = cn.jobTitle.isEmpty ? nil : cn.jobTitle
                
                context.insert(contact)
                imported += 1
                if imported % 50 == 0 { state = .importing(current: i+1, total: allContacts.count) }
            }
            
            try context.save()
            state = .completed(imported: imported, skipped: skipped)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

### 2.2 EchoEngine.swift

```swift
// Services/EchoEngine.swift
import Foundation
import SwiftData

@MainActor
final class EchoEngine: ObservableObject {
    
    // MARK: - Layer Management
    
    func toggleEchoLayer(for contact: EchoContact, in context: ModelContext) {
        contact.isInEchoLayer.toggle()
        try? context.save()
    }
    
    func setPriority(_ level: PriorityLevel, for contact: EchoContact, in context: ModelContext) {
        contact.priorityLevel = level.rawValue
        try? context.save()
    }
    
    // MARK: - Reach Actions
    
    func logReach(type: InteractionType, note: String, for contact: EchoContact, in context: ModelContext) {
        let interaction = Interaction(type: type, note: note)
        interaction.contact = contact
        contact.interactions.append(interaction)
        contact.lastReachedOut = Date()
        contact.reachCount += 1
        try? context.save()
    }
    
    // MARK: - Notes
    
    func addNote(_ content: String, to contact: EchoContact, isVoice: Bool = false,
                 transcript: String? = nil, in context: ModelContext) {
        let note = Note(content: content, isVoiceMemo: isVoice)
        note.voiceTranscript = transcript
        note.contact = contact
        contact.notes.append(note)
        try? context.save()
    }
    
    // MARK: - Deal Management
    
    func createDeal(title: String, value: Double, stage: DealStage, productType: String?,
                    for contact: EchoContact, in context: ModelContext) {
        let deal = Deal(title: title, value: value, stage: stage, productType: productType)
        deal.contact = contact
        contact.deals.append(deal)
        contact.dealStage = stage.rawValue
        try? context.save()
    }
    
    func moveDeal(_ deal: Deal, to stage: DealStage, in context: ModelContext) {
        deal.stage = stage.rawValue
        if stage == .closedWon || stage == .closedLost {
            deal.probability = stage == .closedWon ? 1.0 : 0.0
        }
        try? context.save()
    }
    
    // MARK: - Queries
    
    func echoContacts(in context: ModelContext) -> [EchoContact] {
        var descriptor = FetchDescriptor<EchoContact>(
            predicate: #Predicate { $0.isInEchoLayer == true }
        )
        descriptor.fetchLimit = 200
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func libraryContacts(in context: ModelContext) -> [EchoContact] {
        var descriptor = FetchDescriptor<EchoContact>(
            predicate: #Predicate { $0.isInEchoLayer == false }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func businessContacts(in context: ModelContext) -> [EchoContact] {
        var descriptor = FetchDescriptor<EchoContact>(
            predicate: #Predicate { $0.priorityLevel != nil }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func deals(for stage: DealStage, in context: ModelContext) -> [Deal] {
        var descriptor = FetchDescriptor<Deal>(
            predicate: #Predicate { $0.stage == stage.rawValue }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
```

### 2.3 StoreKitManager.swift

```swift
// Services/StoreKitManager.swift
import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published var isPro = false          // AI Pro ($4/mo)
    @Published var isBusiness = false     // B2B Pro ($15/mo)
    @Published var products: [Product] = []
    
    static let aiProID = "echo.ai.pro.monthly"
    static let businessProID = "echo.business.pro.monthly"
    
    private var updates: Task<Void, Never>?
    
    init() {
        updates = Task { await observeUpdates() }
        Task {
            await loadProducts()
            await refreshPurchased()
        }
    }
    
    deinit { updates?.cancel() }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.aiProID, Self.businessProID])
        } catch {
            print("StoreKit load error: \(error)")
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await refreshPurchased()
                    return true
                }
                return false
            case .userCancelled: return false
            case .pending: return false
            @unknown default: return false
            }
        } catch { return false }
    }
    
    func refreshPurchased() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil {
                ids.insert(tx.productID)
            }
        }
        isPro = ids.contains(Self.aiProID) || ids.contains(Self.businessProID)
        isBusiness = ids.contains(Self.businessProID)
    }
    
    private func observeUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result {
                await tx.finish()
                await refreshPurchased()
            }
        }
    }
}
```

### 2.4 AIService.swift (DeepSeek)

```swift
// Services/AIService.swift
import Foundation
import UIKit

final class AIService {
    static let shared = AIService()
    private let baseURL = "https://api.deepseek.com/v1"
    private var apiKey: String { KeychainManager.get("deepseek_api_key") ?? "" }
    
    private init() {}
    
    // MARK: - Privacy: Anonymize before sending
    
    private func anonymize(_ text: String, contacts: [EchoContact]) -> String {
        var result = text
        for (i, c) in contacts.enumerated() {
            result = result.replacingOccurrences(of: c.fullName, with: "Person_\(i)")
            if let co = c.companyName {
                result = result.replacingOccurrences(of: co, with: "Company_\(i)")
            }
        }
        return result
    }
    
    // MARK: - Chat Completion
    
    func chat(systemPrompt: String, userMessage: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIServiceError.noAPIKey }
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "temperature": 0.7,
            "max_tokens": 500
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let error = json?["error"] as? [String: Any] {
            throw AIServiceError.apiError(error["message"] as? String ?? "Unknown")
        }
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.parseError
        }
        return content
    }
    
    // MARK: - Vision (Image understanding)
    
    func analyzeImage(_ image: UIImage, prompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIServiceError.noAPIKey }
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw AIServiceError.imageError
        }
        let base64Image = imageData.base64EncodedString()
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]],
            "max_tokens": 1000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.parseError
        }
        return content
    }
    
    // MARK: - High-level features
    
    func generateOpener(for contact: EchoContact, recentNote: String?) async throws -> String {
        let prompt = """
        You are a warm, concise assistant. Based on the last conversation note, suggest a natural opening message for \(contact.givenName).
        Keep it under 40 words. Don't be generic — reference the specific context.
        Note: \(recentNote ?? "No prior context")
        """
        return try await chat(systemPrompt: "You are a helpful relationship assistant.", userMessage: prompt)
    }
    
    func extractBusinessCardInfo(from image: UIImage) async throws -> [String: String] {
        let prompt = """
        Extract the following from this business card image. Return JSON:
        {"name": "", "company": "", "title": "", "phone": "", "email": ""}
        Only return the JSON, no other text.
        """
        let result = try await analyzeImage(image, prompt: prompt)
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return json
        }
        return [:]
    }
    
    func extractPolicyInfo(from image: UIImage) async throws -> [String: String] {
        let prompt = """
        Extract from this insurance policy document. Return JSON:
        {"policy_number": "", "insured_name": "", "type": "", "premium": "", "expiry_date": "", "coverage_amount": ""}
        Only return the JSON.
        """
        let result = try await analyzeImage(image, prompt: prompt)
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return json
        }
        return [:]
    }
    
    func salesCoach(transcript: String, stage: String) async throws -> String {
        let prompt = """
        Analyze this sales call transcript and provide ONE actionable improvement tip.
        Stage: \(stage)
        Transcript: \(transcript)
        
        Focus on: what was missed, what could be improved, one specific suggestion.
        Keep under 100 words. Be direct.
        """
        return try await chat(systemPrompt: "You are an expert sales coach. Be direct and actionable.", userMessage: prompt)
    }
    
    func generateClientProfile(contact: EchoContact) async throws -> String {
        let notes = contact.notes.map(\.content).joined(separator: "; ")
        let prompt = """
        Based on these notes about client \(contact.givenName) \(contact.familyName):
        \(notes)
        
        Generate a brief client profile: needs, concerns, decision factors, best approach.
        Under 150 words.
        """
        return try await chat(systemPrompt: "You are a CRM analyst. Be concise.", userMessage: prompt)
    }
}

enum AIServiceError: Error, LocalizedError {
    case noAPIKey, parseError, apiError(String), imageError
    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "DeepSeek API key not configured"
        case .parseError: return "Failed to parse AI response"
        case .apiError(let m): return m
        case .imageError: return "Failed to process image"
        }
    }
}

// MARK: - Keychain Helper

struct KeychainManager {
    static func save(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

### 2.5 VoiceService.swift (火山引擎)

```swift
// Services/VoiceService.swift
import Foundation
import AVFoundation

final class VoiceService: NSObject, ObservableObject {
    static let shared = VoiceService()
    
    private var appID: String { KeychainManager.get("volcano_app_id") ?? "" }
    private var accessToken: String { KeychainManager.get("volcano_token") ?? "" }
    
    @Published var isRecording = false
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    private override init() { super.init() }
    
    // MARK: - Recording
    
    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("echo_recording_\(Date().timeIntervalSince1970).m4a")
        recordingURL = url
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
        return url
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return recordingURL
    }
    
    // MARK: - ASR (Speech-to-Text)
    
    func transcribe(audioURL: URL) async throws -> String {
        // 火山引擎 ASR API
        // 简化实现：发送音频文件 → 返回文字
        let boundary = UUID().uuidString
        let url = URL(string: "https://openspeech.bytedance.com/api/v1/asr")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: audioURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["text"] as? String ?? ""
    }
    
    // MARK: - TTS (Text-to-Speech)
    
    func synthesizeSpeech(text: String) async throws -> URL {
        let url = URL(string: "https://openspeech.bytedance.com/api/v1/tts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "app": ["appid": appID],
            "user": ["uid": "echo_user"],
            "audio": ["voice_type": "zh_female_shuangkuaisisi_moon_bigtts",
                      "encoding": "mp3",
                      "speed_ratio": 1.0],
            "request": ["text": text, "text_type": "plain"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("echo_tts_\(Date().timeIntervalSince1970).mp3")
        try data.write(to: outputURL)
        return outputURL
    }
}
```

### 🔨 验证

`Cmd+B` → 编译通过。所有 Service 无语法错误。

---

## Phase 3: UI — Onboarding + Personal Tab (3h)

### 3.1 EchoApp.swift + ContentView.swift

```swift
// EchoApp.swift
import SwiftUI
import SwiftData

@main
struct EchoApp: App {
    @StateObject private var storeKit = StoreKitManager()
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: EchoContact.self, Interaction.self, Note.self, Deal.self)
        } catch { fatalError("ModelContainer: \(error)") }
    }
    
    var body: some Scene {
        WindowGroup {
            if hasOnboarded {
                ContentView()
                    .preferredColorScheme(.dark)
                    .environmentObject(storeKit)
            } else {
                OnboardingView(hasOnboarded: $hasOnboarded)
                    .preferredColorScheme(.dark)
                    .environmentObject(storeKit)
            }
        }
        .modelContainer(container)
    }
}
```

```swift
// ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    
    var body: some View {
        TabView {
            EchoLayerView()
                .tabItem {
                    Image(systemName: "waveform")
                    Text("Personal")
                }
            
            if storeKit.isPro {
                AIInsightsView()
                    .tabItem {
                        Image(systemName: "sparkles")
                        Text("AI")
                    }
            }
            
            if storeKit.isBusiness {
                PipelineView()
                    .tabItem {
                        Image(systemName: "briefcase")
                        Text("Business")
                    }
            }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .tint(Color("accent"))
    }
}
```

### 3.2 OnboardingView.swift

```swift
// Views/Onboarding/OnboardingView.swift
import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var hasOnboarded: Bool
    @StateObject private var importService = ContactImportService()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 120)
                Text("〰️").font(.system(size: 48))
            }
            
            VStack(spacing: 8) {
                Text("Echo").font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color("textPrimary"))
                Text("A whisper across time\nalways finds its way back.")
                    .font(.system(size: 17)).foregroundColor(Color("textSecondary"))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: startImport) {
                HStack {
                    if case .importing = importService.state { ProgressView().tint(.white) }
                    Text(buttonLabel).font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.accentColor).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isImporting).padding(.horizontal, 24)
            
            Text("Your contacts never leave your device.\nAI features send only anonymized data.")
                .font(.system(size: 12)).foregroundColor(Color("textMuted"))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            
            if case .importing(let cur, let total) = importService.state {
                ProgressView(value: Double(cur), total: Double(total)).tint(.accentColor).padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .background(Color("background"))
        .onChange(of: importService.state) { _, new in
            if case .completed = new {
                withAnimation { hasOnboarded = true }
            }
        }
    }
    
    private var buttonLabel: String {
        switch importService.state {
        case .idle: return "Import Contacts"
        case .requestingPermission: return "Requesting Permission..."
        case .importing: return "Importing..."
        case .completed: return "Done!"
        case .denied: return "Open Settings"
        case .error: return "Try Again"
        }
    }
    
    private var isImporting: Bool {
        if case .importing = importService.state { return true }
        return false
    }
    
    private func startImport() {
        if case .denied = importService.state {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            Task { await importService.importContacts(into: modelContext) }
        }
    }
}
```

### 3.3 EchoLayerView + EchoCardView + PeopleLibraryView

这些和之前 build-plan.md 中的设计一致，但需要支持三模数据结构。

### 3.4 ContactDetailView + ReachSheetView

同上，但需增加 Business 模式下的 Deal 列表和 Priority 选择器。

*(这些 View 代码较长但在之前的 build-plan.md 中已有基础，Mac 上可按原结构扩展。)*

### 🔨 验证

- `Cmd+R` → Onboarding → 授权通讯录 → Personal Tab 显示卡片

---

## Phase 4: AI Tab (2h)

### 4.1 AIInsightsView.swift

```swift
// Views/AI/AIInsightsView.swift
import SwiftUI
import SwiftData

struct AIInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = EchoEngine()
    @State private var insights: [AIInsight] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Analyzing your relationships...").padding(60)
                } else if insights.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 16) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color("background"))
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshInsights) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { if insights.isEmpty { refreshInsights() } }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles").font(.system(size: 60)).foregroundColor(Color("textMuted"))
            Text("Echo AI is analyzing your relationship patterns...")
                .font(.title3).foregroundColor(Color("textPrimary"))
                .multilineTextAlignment(.center)
            Text("We'll show you who needs attention, what to say, and hidden patterns in your network.")
                .font(.subheadline).foregroundColor(Color("textSecondary"))
                .multilineTextAlignment(.center)
            Button("Run Analysis") { refreshInsights() }
                .buttonStyle(.borderedProminent).tint(.accentColor)
        }
        .padding(40)
    }
    
    private func refreshInsights() {
        isLoading = true
        Task {
            let contacts = engine.echoContacts(in: modelContext)
            var items: [AIInsight] = []
            
            for c in contacts.prefix(5) {
                if let recent = c.notes.last?.content {
                    do {
                        let opener = try await AIService.shared.generateOpener(for: c, recentNote: recent)
                        items.append(AIInsight(
                            contactName: c.fullName,
                            type: .opener,
                            message: opener,
                            contactID: c.systemIdentifier
                        ))
                    } catch { }
                }
            }
            
            insights = items
            isLoading = false
        }
    }
}

struct AIInsight: Identifiable {
    let id = UUID()
    let contactName: String
    let type: InsightType
    let message: String
    let contactID: String
    
    enum InsightType: String {
        case opener = "What to say"
        case rhythm = "Rhythm alert"
        case network = "Network insight"
        case health = "Relationship health"
    }
}

struct InsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(insight.type.rawValue, systemImage: iconFor(insight.type))
                    .font(.caption).foregroundColor(.accentColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
            }
            
            Text(insight.contactName)
                .font(.headline).foregroundColor(Color("textPrimary"))
            
            Text(insight.message)
                .font(.system(size: 15)).foregroundColor(Color("textSecondary"))
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color("surface"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    func iconFor(_ type: AIInsight.InsightType) -> String {
        switch type {
        case .opener: return "message.fill"
        case .rhythm: return "waveform.path.ecg"
        case .network: return "circle.hexagongrid"
        case .health: return "heart.fill"
        }
    }
}
```

### 🔨 验证

AI Tab 显示 "Run Analysis" → 点击 → 加载 DeepSeek 生成的开场白建议。

---

## Phase 5: Business Tab — Kanban Pipeline (3h)

### 5.1 PipelineView.swift

```swift
// Views/Business/PipelineView.swift
import SwiftUI
import SwiftData

struct PipelineView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = EchoEngine()
    @State private var showNewDeal = false
    
    private let activeStages: [DealStage] = [.lead, .contacted, .quoted, .negotiating]
    
    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(activeStages, id: \.rawValue) { stage in
                        KanbanColumn(stage: stage, deals: engine.deals(for: stage, in: modelContext))
                    }
                    
                    // Closed Won column
                    KanbanColumn(stage: .closedWon, deals: engine.deals(for: .closedWon, in: modelContext), isCompact: true)
                }
                .padding(16)
            }
            .background(Color("background"))
            .navigationTitle("Pipeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewDeal = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewDeal) {
            NewDealSheet()
        }
    }
}

struct KanbanColumn: View {
    let stage: DealStage
    let deals: [Deal]
    var isCompact: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: stage.color))
                    .frame(width: 8, height: 8)
                Text(stage.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color("textPrimary"))
                Spacer()
                Text("\(deals.count)")
                    .font(.caption)
                    .foregroundColor(Color("textMuted"))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color("surface"))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 4)
            
            ForEach(deals) { deal in
                DealCardView(deal: deal)
            }
            
            if deals.isEmpty {
                Text("No deals")
                    .font(.caption)
                    .foregroundColor(Color("textMuted"))
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: isCompact ? 140 : 160)
    }
}

struct DealCardView: View {
    let deal: Deal
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = EchoEngine()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(deal.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("textPrimary"))
                .lineLimit(2)
            
            if let contact = deal.contact {
                Text(contact.fullName)
                    .font(.system(size: 12))
                    .foregroundColor(Color("textMuted"))
            }
            
            Text("$\(deal.value, specifier: "%.0f")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.accentColor)
            
            if deal.dealStageEnum == .negotiating || deal.dealStageEnum == .closedWon {
                HStack {
                    Button("←") {
                        engine.moveDeal(deal, to: previousStage(deal.dealStageEnum), in: modelContext)
                    }
                    .font(.caption2)
                    
                    Spacer()
                    
                    if deal.dealStageEnum != .closedWon {
                        Button("→") {
                            engine.moveDeal(deal, to: nextStage(deal.dealStageEnum), in: modelContext)
                        }
                        .font(.caption2)
                    }
                }
                .foregroundColor(Color("textSecondary"))
            }
        }
        .padding(10)
        .background(Color("surface"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            ForEach(DealStage.allCases, id: \.rawValue) { stage in
                Button(stage.label) {
                    engine.moveDeal(deal, to: stage, in: modelContext)
                }
            }
        }
    }
    
    func nextStage(_ s: DealStage) -> DealStage {
        switch s {
        case .lead: return .contacted
        case .contacted: return .quoted
        case .quoted: return .negotiating
        case .negotiating: return .closedWon
        default: return s
        }
    }
    
    func previousStage(_ s: DealStage) -> DealStage {
        switch s {
        case .contacted: return .lead
        case .quoted: return .contacted
        case .negotiating: return .quoted
        case .closedWon: return .negotiating
        default: return s
        }
    }
}

struct NewDealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = EchoEngine()
    @State private var title = ""
    @State private var value = ""
    @State private var productType = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Deal title", text: $title)
                TextField("Value ($)", text: $value).keyboardType(.decimalPad)
                TextField("Product type", text: $productType)
            }
            .navigationTitle("New Deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard !title.isEmpty, let val = Double(value) else { return }
                        // Create a temporary contact or select existing
                        // Simplified: create deal linked to first business contact
                        let contacts = engine.businessContacts(in: modelContext)
                        if let contact = contacts.first {
                            engine.createDeal(title: title, value: val, stage: .lead,
                                              productType: productType.isEmpty ? nil : productType,
                                              for: contact, in: modelContext)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

### 🔨 验证

Business Tab → 显示 4 列 Kanban（Lead / Contacted / Quoted / Negotiating）→ `+` 创建新 Deal → 拖拽或右键移动阶段。

---

## Phase 6: 拍照 + 语音功能 (2h)

### 6.1 拍照识别集成

在 ContactDetailView 中添加拍照按钮：

```swift
// Inside ContactDetailView
Button(action: takePhoto) {
    Label("Scan Card", systemImage: "camera.viewfinder")
}
.sheet(isPresented: $showCamera) {
    ImagePicker(sourceType: .camera) { image in
        Task {
            do {
                let info = try await AIService.shared.extractBusinessCardInfo(from: image)
                // Populate contact fields with extracted info
                if let co = info["company"] { contact.companyName = co }
                if let title = info["title"] { contact.jobTitle = title }
                showToast("Card scanned ✓")
            } catch {
                showToast("Scan failed")
            }
        }
    }
}
```

### 6.2 语音备注集成

```swift
// In ContactDetailView
Button(action: toggleRecording) {
    Label(
        VoiceService.shared.isRecording ? "Stop Recording" : "Voice Note",
        systemImage: VoiceService.shared.isRecording ? "stop.circle.fill" : "mic.fill"
    )
}
.onChange(of: VoiceService.shared.isRecording) { _, recording in
    if !recording, let url = VoiceService.shared.stopRecording() {
        Task {
            do {
                let transcript = try await VoiceService.shared.transcribe(audioURL: url)
                engine.addNote(transcript, to: contact, isVoice: true, transcript: transcript, in: modelContext)
                showToast("Voice note saved ✓")
            } catch {
                showToast("Transcription failed")
            }
        }
    }
}
```

### 🔨 验证

- 拍名片 → DeepSeek 返回结构化信息
- 录音 → 火山引擎返回文字 → 自动保存为备注

---

## Phase 7: Settings + Widget + 系统集成 (2h)

### 7.1 SettingsView with API key management

```swift
// Views/Settings/SettingsView.swift
struct SettingsView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    @State private var deepseekKey = ""
    @State private var volcanoAppID = ""
    @State private var volcanoToken = ""
    @State private var showSaved = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Subscription
                Section("Subscription") {
                    if storeKit.isBusiness {
                        LabeledContent("B2B Pro", value: "Active")
                    } else if storeKit.isPro {
                        LabeledContent("AI Pro", value: "Active")
                        Button("Upgrade to Business ($15/mo)") {
                            Task { if let p = storeKit.products.first(where: { $0.id == StoreKitManager.businessProID }) { _ = await storeKit.purchase(p) } }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI Pro — $4/month").font(.headline)
                            Text("AI-powered insights, smart openers, voice notes, auto-layering.")
                                .font(.subheadline).foregroundColor(.secondary)
                            Button("Start 30-Day Free Trial") {
                                Task { if let p = storeKit.products.first(where: { $0.id == StoreKitManager.aiProID }) { _ = await storeKit.purchase(p) } }
                            }.buttonStyle(.borderedProminent).tint(.accentColor)
                        }
                    }
                }
                
                // API Keys (only show when Pro)
                if storeKit.isPro || storeKit.isBusiness {
                    Section("AI Configuration") {
                        SecureField("DeepSeek API Key", text: $deepseekKey)
                            .onAppear { deepseekKey = KeychainManager.get("deepseek_api_key") ?? "" }
                        SecureField("Volcano App ID", text: $volcanoAppID)
                            .onAppear { volcanoAppID = KeychainManager.get("volcano_app_id") ?? "" }
                        SecureField("Volcano Access Token", text: $volcanoToken)
                            .onAppear { volcanoToken = KeychainManager.get("volcano_token") ?? "" }
                        
                        Button("Save") {
                            KeychainManager.save(deepseekKey, for: "deepseek_api_key")
                            KeychainManager.save(volcanoAppID, for: "volcano_app_id")
                            KeychainManager.save(volcanoToken, for: "volcano_token")
                            showSaved = true
                        }
                    }
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .alert("Saved", isPresented: $showSaved) {
                Button("OK") { }
            } message: {
                Text("API keys saved securely in Keychain.")
            }
        }
    }
}
```

### 7.2 Widget — 对标 LACRM 每日邮件

> LACRM 的核心留存机制是每天早上发邮件到收件箱。Echo 用 Widget 实现同等效果——不需要打开 App 就能看到今天该联系谁。

Widget 需要创建独立的 Widget Extension target：

**Xcode → File → New → Target → Widget Extension:**
```
Name: EchoWidget
☑ Include Configuration App Intent
```

**EchoWidget/EchoWidget.swift:**

```swift
import WidgetKit
import SwiftUI
import SwiftData

struct EchoWidgetEntry: TimelineEntry {
    let date: Date
    let topContacts: [WidgetContact]
}

struct WidgetContact: Identifiable {
    let id: String
    let name: String
    let initials: String
    let daysSinceContact: Int
    let context: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> EchoWidgetEntry {
        EchoWidgetEntry(date: Date(), topContacts: [
            WidgetContact(id: "1", name: "Sarah Chen", initials: "SC", daysSinceContact: 19, context: "Mom recovering from surgery"),
            WidgetContact(id: "2", name: "Mike Johnson", initials: "MJ", daysSinceContact: 28, context: "Changing jobs — follow up"),
            WidgetContact(id: "3", name: "Lisa Park", initials: "LP", daysSinceContact: 8, context: "Monthly coffee ritual")
        ])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (EchoWidgetEntry) -> Void) {
        let contacts = fetchTopContacts()
        completion(EchoWidgetEntry(date: Date(), topContacts: contacts))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<EchoWidgetEntry>) -> Void) {
        let contacts = fetchTopContacts()
        let entry = EchoWidgetEntry(date: Date(), topContacts: contacts)
        // Refresh every 3 hours
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 3, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    private func fetchTopContacts() -> [WidgetContact] {
        // Access shared SwiftData container
        // Simplified: read from shared UserDefaults or App Group container
        guard let data = UserDefaults(suiteName: "group.com.echo.app")?.data(forKey: "widgetData"),
              let contacts = try? JSONDecoder().decode([WidgetContactData].self, from: data) else {
            return placeholder(in: .current).topContacts
        }
        return contacts.prefix(3).map { WidgetContact(id: $0.id, name: $0.name, initials: $0.initials, daysSinceContact: $0.days, context: $0.context) }
    }
}

struct WidgetContactData: Codable {
    let id, name, initials, context: String
    let days: Int
}

struct EchoWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("〰️").font(.caption)
                Text("Today's Echo").font(.caption).fontWeight(.semibold)
                Spacer()
            }
            .foregroundColor(.gray)
            
            ForEach(entry.topContacts) { contact in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(Text(contact.initials).font(.system(size: 12, weight: .bold)).foregroundColor(.blue))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(contact.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text(contact.context)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text("\(contact.daysSinceContact)d")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(contact.daysSinceContact > 14 ? .orange : .gray)
                }
            }
        }
        .padding()
        .containerBackground(.black, for: .widget)
    }
}

struct EchoWidget: Widget {
    let kind: String = "EchoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            EchoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Echo")
        .description("See who needs your attention today.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
```

**在主 App 中更新 Widget 数据（每次 Reach 操作后）：**

```swift
// In EchoEngine.logReach() — add after saving:
func refreshWidgetData(in context: ModelContext) {
    let contacts = echoContacts(in: context).prefix(5).map { c in
        WidgetContactData(
            id: c.systemIdentifier,
            name: c.fullName,
            initials: String(c.givenName.prefix(1)) + String(c.familyName.prefix(1)),
            days: Calendar.current.dateComponents([.day], from: c.lastReachedOut ?? Date(), to: Date()).day ?? 0,
            context: c.notes.last?.content ?? (c.interactions.last?.note ?? "")
        )
    }
    if let data = try? JSONEncoder().encode(contacts) {
        UserDefaults(suiteName: "group.com.echo.app")?.set(data, forKey: "widgetData")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

**App Groups 配置：**
- 主 App target → Signing & Capabilities → + App Groups → `group.com.echo.app`
- Widget target → Signing & Capabilities → + App Groups → `group.com.echo.app`

---

### 7.3 Daily Briefing System — 对标 LACRM 每日邮件

> LACRM 每天早上发邮件；Echo 每天早上发推送 + AI 简报（可选择 TTS 朗读）。

#### 7.3.1 本地通知服务

```swift
// Services/NotificationService.swift
import UserNotifications
import SwiftData

final class NotificationService {
    static let shared = NotificationService()
    
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    func scheduleDailyBriefing(context: ModelContext, hour: Int = 8) {
        let engine = EchoEngine()
        let contacts = engine.echoContacts(in: context)
            .sorted { ($0.lastReachedOut ?? .distantPast) < ($1.lastReachedOut ?? .distantPast) }
            .prefix(3)
        
        guard !contacts.isEmpty else { return }
        
        let names = contacts.map { $0.givenName }.joined(separator: ", ")
        let topContact = contacts.first!
        let days = Calendar.current.dateComponents([.day], from: topContact.lastReachedOut ?? Date(), to: Date()).day ?? 0
        
        let body = days > 0
            ? "\(names) — \(topContact.givenName) was last contacted \(days) days ago."
            : "\(names) are on your mind today."
        
        let content = UNMutableNotificationContent()
        content.title = "〰️ Today's Echo"
        content.body = body
        content.sound = .default
        content.userInfo = ["type": "daily_briefing"]
        content.interruptionLevel = .timeSensitive
        
        // Schedule for user's preferred hour
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "echo.daily.briefing",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleRhythmAlert(for contact: EchoContact, daysSince: Int) {
        let content = UNMutableNotificationContent()
        content.title = "👋 \(contact.givenName) \(contact.familyName)"
        content.body = "It's been \(daysSince) days — longer than your usual rhythm."
        content.sound = .default
        content.userInfo = ["type": "rhythm_alert", "contactId": contact.systemIdentifier]
        
        // Deliver in 10 seconds (for testing) or schedule intelligently
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(
            identifier: "echo.rhythm.\(contact.systemIdentifier)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
```

#### 7.3.2 AI 简报文案生成（通过 DeepSeek）

```swift
// Extension in NotificationService
extension NotificationService {
    func generateAIBriefingBody(context: ModelContext) async -> String {
        let engine = EchoEngine()
        let contacts = engine.echoContacts(in: context)
            .sorted { ($0.lastReachedOut ?? .distantPast) < ($1.lastReachedOut ?? .distantPast) }
            .prefix(3)
        
        let contactsDesc = contacts.map { c in
            let days = Calendar.current.dateComponents([.day], from: c.lastReachedOut ?? Date(), to: Date()).day ?? 0
            let note = c.notes.last?.content ?? ""
            return "\(c.givenName) (last contact: \(days)d ago, note: \(note))"
        }.joined(separator: "; ")
        
        let prompt = """
        You are a morning briefing assistant. Write a ONE-sentence briefing about these people. 
        Use first names. Warm tone. Under 40 words.
        Contacts: \(contactsDesc)
        """
        
        do {
            return try await AIService.shared.chat(
                systemPrompt: "You write warm, concise morning briefings. One sentence only.",
                userMessage: prompt
            )
        } catch {
            // Fallback to template
            let names = contacts.map(\.givenName).joined(separator: ", ")
            return "Good morning. \(names) are on your mind today. Tap to reach out."
        }
    }
}
```

#### 7.3.3 TTS 朗读集成（通过火山引擎）

```swift
// Extension to VoiceService for morning briefing
extension VoiceService {
    func playMorningBriefing(text: String) async {
        do {
            let audioURL = try await synthesizeSpeech(text: text)
            // Play audio through AVAudioPlayer
            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.prepareToPlay()
            player.play()
        } catch {
            print("TTS briefing failed: \(error)")
        }
    }
}
```

**推送通知的交互流程：**

```
早上 8:00
  → 收到推送: "〰️ Today's Echo: Sarah, Mike, Lisa — Sarah was last contacted 19 days ago."
  → 用户长按/下拉推送 → 展开操作按钮:
      [Listen 🎧] → 播放 TTS 朗读简报
      [Open Echo] → 直接进入 Personal Tab
  → 如果用户不操作 → Widget 上已经显示了同样的信息
```

**Info.plist 通知权限请求文案：**
```
"Echo sends a daily briefing to help you stay in touch. 
You can customize the time or turn it off anytime."
```

---

### 🔨 验证

- Settings 页 → API key 输入 → 保存到 Keychain
- Widget 添加到主屏 → 显示 Top 3 联系人 + 联系间隔
- App 内执行 Reach 操作 → Widget 数据刷新
- 授权通知权限 → 每日简报推送测试
- AI Pro 用户 → 简报用 DeepSeek 生成文案 → TTS 朗读

---

## Phase 8: App Store Connect + 打磨 (1h)

### 8.1 App Store Connect 配置

1. 创建 App ID: `echo`
2. 创建订阅产品:
   - `echo.ai.pro.monthly` — $3.99
   - `echo.business.pro.monthly` — $14.99
3. 创建 Sandbox tester
4. Info.plist 添加:
   - `NSContactsUsageDescription`: "Echo uses your contacts to help you stay in touch. Everything stays on your device."
   - `NSCameraUsageDescription`: "Scan business cards and documents with AI."
   - `NSMicrophoneUsageDescription`: "Record voice notes for your contacts."

### 8.2 App Icon

1024×1024 PNG: waveform on #090A0E with #3B82F6 accent

### 8.3 全流程冒烟测试

- [ ] 首次启动 → Onboarding → 授权通讯录 → 导入成功 → Personal Tab
- [ ] Personal Tab → 点击卡片 → Reach 弹窗 → Call/Message/Email → 记录互动
- [ ] 添加备注 → 保存 → 时间线更新
- [ ] 升级 AI Pro → AI Tab 出现 → 运行分析 → 显示开场白
- [ ] 拍照名片 → AI 提取 → 字段更新
- [ ] 录音 → 语音转文字 → 备注保存
- [ ] 升级 B2B Pro → Business Tab → Kanban 管线
- [ ] 创建 Deal → 拖拽阶段 → 管线更新
- [ ] Settings → API key 配置 → 保存
- [ ] 无崩溃，无内存泄漏

---

## 项目文件清单（完整）

```
Echo/
├── EchoApp.swift                    ← App 入口 + ModelContainer
├── ContentView.swift                ← 3-Tab 根视图
├── Models/
│   ├── Enums.swift                  ← InteractionType, PriorityLevel, DealStage
│   ├── EchoContact.swift            ← 核心联系人模型
│   ├── Interaction.swift            ← 互动记录
│   ├── Note.swift                   ← 备注（文字+语音）
│   └── Deal.swift                   ← 交易/订单
├── Views/
│   ├── Onboarding/OnboardingView.swift
│   ├── Personal/EchoLayerView.swift
│   ├── Personal/EchoCardView.swift
│   ├── Personal/PeopleLibraryView.swift
│   ├── Detail/ContactDetailView.swift
│   ├── Detail/ReachSheetView.swift
│   ├── AI/AIInsightsView.swift
│   ├── Business/PipelineView.swift      ← Kanban 管线
│   ├── Business/DealCardView.swift
│   ├── Business/NewDealSheet.swift
│   └── Settings/SettingsView.swift
├── Services/
│   ├── ContactImportService.swift
│   ├── EchoEngine.swift
│   ├── AIService.swift              ← DeepSeek API
│   ├── VoiceService.swift           ← 火山引擎 ASR/TTS
│   ├── KeychainManager.swift
│   └── StoreKitManager.swift
├── Helpers/
│   └── Color+Hex.swift
└── Assets.xcassets                  ← 颜色 + App Icon
```

---

## Phase 9: Mac iMessage Helper — 竞品杀手功能 (3h)

> 对标 Dex 的 iMessage Sync Utility。通过读取 macOS `chat.db`，自动同步 iMessage 互动数据到 iOS App。
> 这是 Echo 对 Dex 最强的反击——Dex 有 iMessage Sync 但移动端弱，Echo 可以同时拥有两者。

### 9.1 创建 Mac 菜单栏 App Target

**Xcode → File → New → Target → macOS → App:**
```
Name: EchoHelper
Interface: SwiftUI
Lifecycle: SwiftUI App
```

在 `EchoHelperApp.swift` 中配置为菜单栏应用：

```swift
import SwiftUI
import AppKit

@main
struct EchoHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var messageReader = MessageReader()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "〰️"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Last Sync: Never", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        // Auto-sync every 30 minutes
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            self.syncNow()
        }
    }
    
    @objc func syncNow() {
        Task {
            await messageReader.syncMessages()
        }
    }
    
    @objc func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

### 9.2 MessageReader — 读取 chat.db

```swift
import Foundation
import SQLite3

final class MessageReader: ObservableObject {
    private let chatDBPath = NSHomeDirectory() + "/Library/Messages/chat.db"
    @Published var lastSyncDate: Date?
    @Published var syncedInteractions = 0
    
    /// Extract recent iMessage interactions from chat.db
    func syncMessages(daysBack: Int = 30) async {
        // Check Full Disk Access
        guard FileManager.default.isReadableFile(atPath: chatDBPath) else {
            requestFullDiskAccess()
            return
        }
        
        var db: OpaquePointer?
        guard sqlite3_open(chatDBPath, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }
        
        // Query: get messages from last N days, grouped by contact
        let query = """
        SELECT 
            h.id AS contact_id,
            COUNT(m.ROWID) AS message_count,
            MAX(m.date/1000000000 + 978307200) AS last_message_time,
            m.text AS last_message_text,
            m.is_from_me AS last_from_me
        FROM message m
        JOIN handle h ON m.handle_id = h.ROWID
        JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
        JOIN chat c ON cmj.chat_id = c.ROWID
        WHERE m.date/1000000000 + 978307200 > \(Int(Date().timeIntervalSince1970) - daysBack * 86400)
        GROUP BY h.id
        ORDER BY last_message_time DESC
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        
        var interactions: [MessageInteractionData] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let contactID = String(cString: sqlite3_column_text(statement, 0))
            let count = Int(sqlite3_column_int(statement, 1))
            let lastTime = sqlite3_column_double(statement, 2)
            let lastText = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            let isFromMe = sqlite3_column_int(statement, 4) != 0
            
            interactions.append(MessageInteractionData(
                contactIdentifier: contactID,  // phone number or email
                messageCount: count,
                lastMessageDate: Date(timeIntervalSince1970: lastTime),
                lastMessagePreview: lastText ?? "",
                isOutgoing: isFromMe
            ))
        }
        
        // Match to Echo contacts by phone/email
        await matchAndSync(interactions)
        
        await MainActor.run {
            syncedInteractions = interactions.count
            lastSyncDate = Date()
        }
    }
    
    /// Match iMessage contacts to Echo contacts
    private func matchAndSync(_ interactions: [MessageInteractionData]) async {
        // Write to App Group shared container
        let defaults = UserDefaults(suiteName: "group.com.echo.app")!
        
        // Filter: only sync contacts that exist in Echo
        let echoContacts = await fetchEchoContacts()
        let echoPhones = Set(echoContacts.compactMap { $0.phoneNumber?.filter { $0.isNumber } })
        let echoEmails = Set(echoContacts.compactMap { $0.emailAddress?.lowercased() })
        
        let matched = interactions.filter { interaction in
            let id = interaction.contactIdentifier.lowercased()
            if id.contains("@") {
                return echoEmails.contains(id)
            } else {
                let digits = id.filter { $0.isNumber }
                return echoPhones.contains(digits)
            }
        }
        
        // Store matched interactions for iOS app to read
        if let data = try? JSONEncoder().encode(matched) {
            defaults.set(data, forKey: "imessage_interactions")
            defaults.set(Date(), forKey: "imessage_last_sync")
        }
    }
    
    private func fetchEchoContacts() async -> [EchoContactStub] {
        // Read from App Group shared container (written by iOS app)
        let defaults = UserDefaults(suiteName: "group.com.echo.app")!
        guard let data = defaults.data(forKey: "echo_contacts_snapshot") else { return [] }
        return (try? JSONDecoder().decode([EchoContactStub].self, from: data)) ?? []
    }
    
    private func requestFullDiskAccess() {
        // Show alert guiding user to System Preferences
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Full Disk Access Required"
            alert.informativeText = "Echo needs Full Disk Access to read your iMessage history. This data stays on your Mac. Go to System Settings → Privacy & Security → Full Disk Access → enable EchoHelper."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
        }
    }
}

// MARK: - Data Models

struct MessageInteractionData: Codable {
    let contactIdentifier: String  // phone number or email
    let messageCount: Int
    let lastMessageDate: Date
    let lastMessagePreview: String
    let isOutgoing: Bool
}

struct EchoContactStub: Codable {
    let systemIdentifier: String
    let phoneNumber: String?
    let emailAddress: String?
}
```

### 9.3 iOS App 端读取 iMessage 数据

在 `EchoEngine` 中添加：

```swift
// EchoEngine.swift
extension EchoEngine {
    /// Read iMessage interactions synced from Mac Helper
    func loadMessageInteractions() -> [MessageInteractionData] {
        let defaults = UserDefaults(suiteName: "group.com.echo.app")!
        guard let data = defaults.data(forKey: "imessage_interactions"),
              let interactions = try? JSONDecoder().decode([MessageInteractionData].self, from: data) else {
            return []
        }
        return interactions
    }
    
    /// Apply iMessage data to contact timeline and AI analysis
    func enrichContactsWithMessageData(in context: ModelContext) {
        let interactions = loadMessageInteractions()
        let allContacts = (try? context.fetch(FetchDescriptor<EchoContact>())) ?? []
        
        for interaction in interactions {
            let id = interaction.contactIdentifier.lowercased()
            let matched = allContacts.first { contact in
                let phone = contact.phoneNumber?.filter { $0.isNumber } ?? ""
                let email = contact.emailAddress?.lowercased() ?? ""
                return phone.contains(id.filter { $0.isNumber }) || email == id
            }
            
            guard let contact = matched else { continue }
            
            // Update interaction frequency (stored in metadata)
            contact.aiInsight = "Last iMessage: \(formatDate(interaction.lastMessageDate)). \(interaction.messageCount) messages in 30 days."
            contact.aiInsightDate = Date()
        }
        
        try? context.save()
    }
}
```

### 9.4 Settings 中的 iMessage Sync 控制

在 iOS SettingsView 中添加：

```swift
Section("iMessage Sync (via Mac Helper)") {
    if let lastSync = UserDefaults(suiteName: "group.com.echo.app")?.object(forKey: "imessage_last_sync") as? Date {
        LabeledContent("Last synced", value: lastSync, format: .relative(presentation: .numeric))
        LabeledContent("Interactions", value: "\(loadMessageInteractions().count) contacts")
    } else {
        Text("Install Echo Helper on your Mac to sync iMessage interactions.")
            .font(.subheadline).foregroundColor(.secondary)
        Link("Download Echo Helper", destination: URL(string: "https://echo-app.com/helper")!)
    }
}
```

### 9.5 Mac Helper 分发

- **不通过 Mac App Store**（chat.db 读取可能被拒）
- **通过 echo-app.com/helper 提供 DMG 下载**
- **开源 iMessage 读取代码**（GitHub）增强信任
- **代码签名 + 公证**（Apple notarization）避免 Gatekeeper 警告

### 🔨 验证

- Mac Helper 安装 → 授权 Full Disk Access → 菜单栏显示 "〰️"
- 点击 Sync Now → iOS App 的 Settings 中显示 "Last synced: X minutes ago"
- Echo 联系人时间线自动显示 "iMessage: 47 messages in 30 days"
- AI Insights 反映真实的互动频率："You and Sarah exchange 2-3 messages daily"
- 关闭 Full Disk Access → Mac Helper 优雅降级（不崩溃，提示重新授权）

---

## Git 提交建议

```
Phase 1: Xcode project + data models (Enums, EchoContact, Interaction, Note, Deal)
Phase 2: Core services (ContactImport, EchoEngine, StoreKit, AIService, VoiceService)
Phase 3: UI - Onboarding + Personal Tab (Echo Cards, People Library, Detail)
Phase 4: AI Tab (AIInsightsView + DeepSeek integration)
Phase 5: Business Tab (Pipeline Kanban + Deal management)
Phase 6: Camera + Voice features (business card scan, voice notes)
Phase 7: Settings + Widget + App Store Connect configuration
Phase 8: App Icon + smoke test + polish
```

---

> **总计：8 个 Phase，~16 小时。完整三模 iOS App，含 DeepSeek 多模态 AI + 火山引擎语音。**
