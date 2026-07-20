# Echo MVP — Mac Build Plan

> 念念不忘，必有回响。
> A whisper across time always finds its way back.

---

## Before You Start

```bash
git clone git@github.com:bambi2008/echo.git
cd echo
```

**Prerequisites on your Mac:**
- Xcode 16+ (App Store)
- iOS 17.0+ Simulator (Xcode → Settings → Platforms)
- Apple Developer account (free tier OK for simulator; paid needed for device testing)

---

## Architecture Decisions

| Layer | Choice | Why |
|-------|--------|-----|
| **UI** | SwiftUI | iOS native, same DNA as SnapDeduct |
| **Data** | SwiftData | iOS 17+ native persistence, auto iCloud sync |
| **Contacts** | Contacts framework | Read-only, on-device, no permission issues |
| **IAP** | StoreKit 2 | Modern Swift concurrency, Apple-recommended |
| **AI** | Create ML (v1.1) | On-device Core ML models. NOT in v1.0 MVP |
| **Min target** | iOS 17.0 | Required by SwiftData; covers ~90% active devices |

---

## Project Structure

```
echo/
├── Echo.xcodeproj
├── Echo/
│   ├── EchoApp.swift                  # App entry point
│   ├── ContentView.swift              # TabView root
│   ├── Models/
│   │   ├── EchoContact.swift          # SwiftData model
│   │   ├── Interaction.swift          # SwiftData model
│   │   └── Note.swift                 # SwiftData model
│   ├── Views/
│   │   ├── EchoLayer/
│   │   │   ├── EchoLayerView.swift    # Main screen: Echo Cards grid/list
│   │   │   └── EchoCardView.swift     # Single person card
│   │   ├── PeopleLibrary/
│   │   │   └── PeopleLibraryView.swift # All contacts, searchable
│   │   ├── ContactDetail/
│   │   │   ├── ContactDetailView.swift # Full detail + timeline
│   │   │   └── ReachActionSheet.swift  # Call / Message / Email picker
│   │   └── Settings/
│   │       └── SettingsView.swift      # Pro upgrade, about
│   ├── Services/
│   │   ├── ContactImportService.swift  # Contacts framework → SwiftData
│   │   ├── EchoEngine.swift           # Layer management logic (v1 manual)
│   │   └── StoreKitManager.swift      # StoreKit 2 IAP
│   └── Assets.xcassets                # Colors, icons, app icon
└── EchoTests/
    ├── ContactImportServiceTests.swift
    └── EchoEngineTests.swift
```

---

## Phase 1: Project Scaffold (30 min)

### Task 1.1: Create Xcode Project

```bash
# Open Xcode
open -a Xcode

# File → New → Project → iOS → App
# Product Name: Echo
# Team: [Your Apple ID]
# Organization Identifier: com.snapdeduct  (or your own reverse-domain)
# Interface: SwiftUI
# Language: Swift
# Storage: SwiftData
# Host in CloudKit: UNCHECKED (v1 = local only)
# Minimum Deployment: iOS 17.0
# [✓] Include Tests
```

**Wait, easier way — use Terminal:**

```bash
mkdir -p Echo
cd Echo
```

Then in Xcode, create the project in this directory. OR use this exact config:

```
Product Name: Echo
Interface: SwiftUI
Language: Swift
Storage: SwiftData
Min: iOS 17.0
Tests: Yes
```

**Verify:** Build → `Cmd+B`. Should compile with default "Hello World" template.

### Task 1.2: Set Up Gitignore

Create `.gitignore` if not present:

```bash
cat > .gitignore << 'EOF'
# Xcode
*.xcuserdata
*.xcworkspace/xcuserdata
DerivedData/
*.xcuserstate
*.xcbkptlist

# CocoaPods / SPM
Pods/

# SwiftPM
.build/

# Misc
.DS_Store
EOF
```

### Task 1.3: Create Folder Structure

In Xcode project navigator, create these groups (right-click Echo folder → New Group):

```
Models/
Views/
  EchoLayer/
  PeopleLibrary/
  ContactDetail/
  Settings/
Services/
```

Or use Terminal:

```bash
cd Echo/Echo/
mkdir -p Models Views/EchoLayer Views/PeopleLibrary Views/ContactDetail Views/Settings Services
```

Then drag folders into Xcode (Create groups, NOT folder references).

**Verify:** `Cmd+B` — project structure visible, no build errors.

### Task 1.4: Define Color Palette

In `Assets.xcassets`, create Color Sets:

| Name | Hex | Usage |
|------|-----|-------|
| `background` | #090A0E | Main background |
| `surface` | #1A1B1F | Card background |
| `accent` | #3B82F6 | Buttons, highlights |
| `textPrimary` | #FFFFFF | Headlines |
| `textSecondary` | #8E8E93 | Subtitles (iOS systemGray) |
| `textMuted` | #636366 | Timestamps |

**How:** In Assets.xcassets → right-click → New Color Set. Set "Any Appearance" and "Dark" to same value (dark-only app).

Then in `EchoApp.swift`, force dark mode:

```swift
import SwiftUI

@main
struct EchoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
```

**Verify:** `Cmd+B` — build passes. App launches with dark background in simulator.

---

## Phase 2: Data Models (1 hour)

### Task 2.1: EchoContact Model

Create `Echo/Models/EchoContact.swift`:

```swift
import Foundation
import SwiftData

@Model
final class EchoContact {
    /// Unique identifier from CNContact.identifier
    @Attribute(.unique) var systemIdentifier: String
    
    var givenName: String
    var familyName: String
    var fullName: String { "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces) }
    
    var phoneNumber: String?
    var emailAddress: String?
    var thumbnailData: Data?  // Contact photo
    
    // Echo-specific
    var isInEchoLayer: Bool = true  // true = Echo Layer, false = People Library
    var lastReachedOut: Date?
    var reachCount: Int = 0
    var createdAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .cascade) var interactions: [Interaction] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    
    init(
        systemIdentifier: String,
        givenName: String,
        familyName: String = "",
        phoneNumber: String? = nil,
        emailAddress: String? = nil,
        thumbnailData: Data? = nil
    ) {
        self.systemIdentifier = systemIdentifier
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumber = phoneNumber
        self.emailAddress = emailAddress
        self.thumbnailData = thumbnailData
    }
}
```

### Task 2.2: Interaction Model

Create `Echo/Models/Interaction.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Interaction {
    var type: InteractionType.RawValue  // Store as String for SwiftData
    var date: Date = Date()
    var note: String = ""
    
    @Relationship(inverse: \EchoContact.interactions) var contact: EchoContact?
    
    init(type: InteractionType, note: String = "") {
        self.type = type.rawValue
        self.note = note
    }
    
    var interactionType: InteractionType {
        InteractionType(rawValue: type) ?? .reachedOut
    }
}

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
```

### Task 2.3: Note Model

Create `Echo/Models/Note.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Note {
    var content: String
    var createdAt: Date = Date()
    
    @Relationship(inverse: \EchoContact.notes) var contact: EchoContact?
    
    init(content: String) {
        self.content = content
    }
}
```

**Verify:** `Cmd+B` — all three models compile. No SwiftData errors.

---

## Phase 3: Contact Import Service (1.5 hours)

### Task 3.1: ContactImportService

Create `Echo/Services/ContactImportService.swift`:

```swift
import Foundation
import Contacts
import SwiftUI

@MainActor
final class ContactImportService: ObservableObject {
    @Published var importProgress: ImportState = .idle
    
    enum ImportState {
        case idle
        case requestingPermission
        case importing(current: Int, total: Int)
        case completed(imported: Int, skipped: Int)
        case denied
        case error(String)
    }
    
    /// Request CNContacts permission and import all contacts into SwiftData
    func importContacts(into context: ModelContext) async {
        importProgress = .requestingPermission
        
        let store = CNContactStore()
        
        do {
            let granted = try await store.requestAccess(for: .contacts)
            
            guard granted else {
                importProgress = .denied
                return
            }
            
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            request.sortOrder = .givenName
            
            var allContacts: [CNContact] = []
            try store.enumerateContacts(with: request) { contact, _ in
                allContacts.append(contact)
            }
            
            importProgress = .importing(current: 0, total: allContacts.count)
            
            var imported = 0
            var skipped = 0
            
            // Fetch existing identifiers to skip duplicates
            let existingIDs = try context.fetch(FetchDescriptor<EchoContact>())
                .map { $0.systemIdentifier }
            let existingSet = Set(existingIDs)
            
            for (index, cnContact) in allContacts.enumerated() {
                if existingSet.contains(cnContact.identifier) {
                    skipped += 1
                    continue
                }
                
                let echoContact = EchoContact(
                    systemIdentifier: cnContact.identifier,
                    givenName: cnContact.givenName.isEmpty ? "Unknown" : cnContact.givenName,
                    familyName: cnContact.familyName,
                    phoneNumber: cnContact.phoneNumbers.first?.value.stringValue,
                    emailAddress: cnContact.emailAddresses.first?.value as String?,
                    thumbnailData: cnContact.thumbnailImageData
                )
                
                context.insert(echoContact)
                imported += 1
                
                // Update progress every 50 contacts
                if imported % 50 == 0 {
                    importProgress = .importing(current: index + 1, total: allContacts.count)
                }
            }
            
            try context.save()
            importProgress = .completed(imported: imported, skipped: skipped)
            
        } catch {
            importProgress = .error(error.localizedDescription)
        }
    }
}
```

**Note on `ModelContext` injection:**

In `EchoApp.swift`, add the model container and pass context:

```swift
@main
struct EchoApp: App {
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: EchoContact.self, Interaction.self, Note.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
```

**Verify:** 
- Add a button in ContentView that calls `importContacts`
- Run in simulator (simulator has no real contacts, but shouldn't crash)
- **TRICK:** Add test contacts to simulator: `Simulator → Features → Contacts → +` add a few, then test import

---

## Phase 4: Echo Engine (Manual Layer Management — v1)

### Task 4.1: EchoEngine

Create `Echo/Services/EchoEngine.swift`:

```swift
import Foundation
import SwiftData

/// Manages Echo Layer vs People Library logic.
/// v1.0: Manual management only. 
/// v1.1: AI auto-classification (Core ML).
@MainActor
final class EchoEngine: ObservableObject {
    
    /// Toggle a contact between Echo Layer and People Library
    func toggleLayer(for contact: EchoContact, in context: ModelContext) {
        contact.isInEchoLayer.toggle()
        try? context.save()
    }
    
    /// Mark that the user reached out to this contact
    func logReach(type: InteractionType, note: String = "", for contact: EchoContact, in context: ModelContext) {
        let interaction = Interaction(type: type, note: note)
        interaction.contact = contact
        contact.interactions.append(interaction)
        contact.lastReachedOut = Date()
        contact.reachCount += 1
        try? context.save()
    }
    
    /// Add a note to a contact (Free limit: 1 note)
    func addNote(_ content: String, to contact: EchoContact, in context: ModelContext) -> Bool {
        // Free tier limit check (simplified — full check uses StoreKit status)
        if contact.notes.count >= 1 {
            return false  // Pro required
        }
        
        let note = Note(content: content)
        note.contact = contact
        contact.notes.append(note)
        try? context.save()
        return true
    }
    
    /// Get contacts in Echo Layer, sorted by lastReachedOut (oldest first — they need you most)
    func echoLayerContacts(in context: ModelContext) -> [EchoContact] {
        var descriptor = FetchDescriptor<EchoContact>(
            predicate: #Predicate { $0.isInEchoLayer == true },
            sortBy: [SortDescriptor(\.lastReachedOut, order: .forward)]
        )
        descriptor.fetchLimit = 30
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Get contacts in People Library, sorted alphabetically
    func peopleLibraryContacts(in context: ModelContext) -> [EchoContact] {
        var descriptor = FetchDescriptor<EchoContact>(
            predicate: #Predicate { $0.isInEchoLayer == false },
            sortBy: [SortDescriptor(\.givenName), SortDescriptor(\.familyName)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
```

**Verify:** `Cmd+B` — compiles.

---

## Phase 5: UI — Echo Layer (Main Screen) (2 hours)

### Task 5.1: EchoCardView

Create `Echo/Views/EchoLayer/EchoCardView.swift`:

```swift
import SwiftUI
import SwiftData

struct EchoCardView: View {
    let contact: EchoContact
    let onReach: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Photo + Name
            HStack(spacing: 12) {
                // Contact photo or placeholder
                if let data = contact.thumbnailData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(contact.givenName.prefix(1).uppercased())
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.accentColor)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(Color("textPrimary"))
                    
                    if let last = contact.lastReachedOut {
                        Text(timeAgo(from: last))
                            .font(.system(size: 13))
                            .foregroundColor(Color("textMuted"))
                    }
                }
                
                Spacer()
            }
            
            // Context: Last interaction note preview
            if let lastNote = contact.notes.last?.content, !lastNote.isEmpty {
                Text(lastNote)
                    .font(.system(size: 14))
                    .foregroundColor(Color("textSecondary"))
                    .lineLimit(2)
            } else {
                Text("No notes yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color("textMuted"))
                    .italic()
            }
            
            // Reach button
            Button(action: onReach) {
                HStack {
                    Image(systemName: "hand.wave.fill")
                    Text("Reach out")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color("surface"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

### Task 5.2: EchoLayerView

Create `Echo/Views/EchoLayer/EchoLayerView.swift`:

```swift
import SwiftUI
import SwiftData

struct EchoLayerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = EchoEngine()
    @State private var showReachSheet = false
    @State private var selectedContact: EchoContact?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    let contacts = engine.echoLayerContacts(in: modelContext)
                    
                    if contacts.isEmpty {
                        emptyState
                    } else {
                        ForEach(contacts) { contact in
                            EchoCardView(contact: contact) {
                                selectedContact = contact
                                showReachSheet = true
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color("background"))
            .navigationTitle("Echo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: PeopleLibraryView()) {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showReachSheet) {
                if let contact = selectedContact {
                    ReachActionSheet(contact: contact)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 60))
                .foregroundColor(Color("textMuted"))
            
            Text("No Echoes yet")
                .font(.title2)
                .foregroundColor(Color("textPrimary"))
            
            Text("Import your contacts to see who matters most.")
                .font(.subheadline)
                .foregroundColor(Color("textSecondary"))
                .multilineTextAlignment(.center)
            
            Button("Import Contacts") {
                // Trigger import
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(40)
    }
}
```

### Task 5.3: ContentView (Tab Root)

Update `ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var hasImported = false
    
    var body: some View {
        Group {
            if hasImported {
                EchoLayerView()
            } else {
                OnboardingView(hasImported: $hasImported)
            }
        }
    }
}
```

**Note:** We'll create `OnboardingView` next. For now, set `hasImported = true` to test the main view.

**Verify:** `Cmd+B` → `Cmd+R` in simulator. Should see dark screen with "No Echoes yet" empty state.

---

## Phase 6: Onboarding (30 min)

### Task 6.1: OnboardingView

Create `Echo/Views/OnboardingView.swift`:

```swift
import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var hasImported: Bool
    @StateObject private var importService = ContactImportService()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App icon area
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text("Echo")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color("textPrimary"))
                
                Text("A whisper across time\nalways finds its way back.")
                    .font(.system(size: 17))
                    .foregroundColor(Color("textSecondary"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Spacer()
            
            // Import button
            Button(action: startImport) {
                HStack {
                    if case .importing = importService.importProgress {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(buttonLabel)
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(importService.importProgress == .requestingPermission || isImporting)
            .padding(.horizontal, 24)
            
            // Privacy note
            Text("Your contacts never leave your device.\nAll processing happens locally.")
                .font(.system(size: 12))
                .foregroundColor(Color("textMuted"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Progress indicator
            if case .importing(let current, let total) = importService.importProgress {
                VStack(spacing: 8) {
                    ProgressView(value: Double(current), total: Double(total))
                        .tint(.accentColor)
                        .padding(.horizontal, 40)
                    Text("Importing \(current) of \(total)...")
                        .font(.caption)
                        .foregroundColor(Color("textMuted"))
                }
                .transition(.opacity)
            }
            
            Spacer()
        }
        .background(Color("background"))
        .onChange(of: importService.importProgress) { _, newState in
            if case .completed = newState {
                withAnimation {
                    hasImported = true
                }
            }
        }
    }
    
    private var buttonLabel: String {
        switch importService.importProgress {
        case .idle: return "Import Contacts"
        case .requestingPermission: return "Requesting Permission..."
        case .importing: return "Importing..."
        case .completed: return "Done!"
        case .denied: return "Permission Denied — Open Settings"
        case .error: return "Try Again"
        }
    }
    
    private var isImporting: Bool {
        if case .importing = importService.importProgress { return true }
        return false
    }
    
    private func startImport() {
        Task {
            await importService.importContacts(into: modelContext)
        }
    }
}
```

**Verify:** 
- Run app fresh → should see onboarding
- Tap "Import Contacts" → should request permission
- Grant → import complete → transition to EchoLayerView
- If denied → shows "Permission Denied" button

---

## Phase 7: People Library (1 hour)

### Task 7.1: PeopleLibraryView

Create `Echo/Views/PeopleLibrary/PeopleLibraryView.swift`:

```swift
import SwiftUI
import SwiftData

struct PeopleLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = EchoEngine()
    @State private var searchText = ""
    
    var body: some View {
        List {
            let contacts = filteredContacts
            
            if contacts.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(contacts) { contact in
                    NavigationLink(destination: ContactDetailView(contact: contact)) {
                        HStack(spacing: 12) {
                            // Thumbnail
                            contactThumbnail(for: contact)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.fullName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("textPrimary"))
                                
                                if let phone = contact.phoneNumber {
                                    Text(phone)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color("textMuted"))
                                }
                            }
                            
                            Spacer()
                            
                            // Echo Layer toggle
                            Button {
                                engine.toggleLayer(for: contact, in: modelContext)
                            } label: {
                                Image(systemName: contact.isInEchoLayer ? "star.fill" : "star")
                                    .foregroundColor(contact.isInEchoLayer ? .accentColor : Color("textMuted"))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search contacts")
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("background"))
        .scrollContentBackground(.hidden)
    }
    
    private var filteredContacts: [EchoContact] {
        let allContacts = engine.peopleLibraryContacts(in: modelContext)
        
        if searchText.isEmpty {
            return allContacts
        }
        
        return allContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            ($0.phoneNumber ?? "").contains(searchText) ||
            ($0.emailAddress ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    @ViewBuilder
    private func contactThumbnail(for contact: EchoContact) -> some View {
        if let data = contact.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(contact.givenName.prefix(1).uppercased())
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.accentColor)
                )
        }
    }
}
```

**Verify:** `Cmd+B`, navigate to People tab → should see all imported contacts.

---

## Phase 8: Contact Detail + Reach (1.5 hours)

### Task 8.1: ReachActionSheet

Create `Echo/Views/ContactDetail/ReachActionSheet.swift`:

```swift
import SwiftUI
import SwiftData
import MessageUI

struct ReachActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let contact: EchoContact
    
    @State private var noteText = ""
    @State private var selectedType: InteractionType = .reachedOut
    @State private var showMessageComposer = false
    @State private var showMailComposer = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    if let data = contact.thumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                    }
                    
                    Text("Reach out to \(contact.givenName)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("textPrimary"))
                }
                .padding(.top, 20)
                
                // Action buttons
                VStack(spacing: 8) {
                    reachButton(icon: "phone.fill", label: "Call", type: .called)
                    reachButton(icon: "message.fill", label: "Message", type: .messaged)
                    reachButton(icon: "envelope.fill", label: "Email", type: .emailed)
                }
                .padding(.horizontal, 24)
                
                // Quick note
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick note (optional)")
                        .font(.caption)
                        .foregroundColor(Color("textMuted"))
                    
                    TextField("What did you talk about?", text: $noteText)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("textPrimary"))
                }
                .padding(.horizontal, 24)
                
                // Log button
                Button("Log as Reached Out") {
                    logReach()
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.accentColor)
                .padding(.top, 8)
                
                Spacer()
            }
            .background(Color("background"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func reachButton(icon: String, label: String, type: InteractionType) -> some View {
        Button {
            selectedType = type
            // Open system action (call, message, email)
            openSystemAction(for: type)
            // Log immediately
            logReach()
        } label: {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(label)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundColor(Color("textMuted"))
            }
            .padding(14)
            .background(Color("surface"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .foregroundColor(Color("textPrimary"))
    }
    
    private func openSystemAction(for type: InteractionType) {
        switch type {
        case .called:
            if let phone = contact.phoneNumber,
               let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") {
                UIApplication.shared.open(url)
            }
        case .messaged:
            if let phone = contact.phoneNumber,
               let url = URL(string: "sms:\(phone.replacingOccurrences(of: " ", with: ""))") {
                UIApplication.shared.open(url)
            }
        case .emailed:
            if let email = contact.emailAddress,
               let url = URL(string: "mailto:\(email)") {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }
    
    private func logReach() {
        let engine = EchoEngine()
        engine.logReach(type: selectedType, note: noteText, for: contact, in: modelContext)
        dismiss()
    }
}
```

### Task 8.2: ContactDetailView

Create `Echo/Views/ContactDetail/ContactDetailView.swift`:

```swift
import SwiftUI
import SwiftData

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = EchoEngine()
    
    let contact: EchoContact
    
    @State private var showReach = false
    @State private var newNoteText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if let data = contact.thumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(contact.givenName.prefix(1).uppercased())
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .foregroundColor(.accentColor)
                            )
                    }
                    
                    Text(contact.fullName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color("textPrimary"))
                    
                    if let last = contact.lastReachedOut {
                        Text("Last reached out \(last, style: .relative) ago")
                            .font(.subheadline)
                            .foregroundColor(Color("textMuted"))
                    }
                    
                    // Echo Layer toggle
                    Button {
                        engine.toggleLayer(for: contact, in: modelContext)
                    } label: {
                        Label(
                            contact.isInEchoLayer ? "In Echo Layer" : "In People Library",
                            systemImage: contact.isInEchoLayer ? "star.fill" : "star"
                        )
                        .font(.caption)
                    }
                    .tint(contact.isInEchoLayer ? .accentColor : Color("textMuted"))
                }
                .padding(.top, 16)
                
                // Reach button
                Button {
                    showReach = true
                } label: {
                    HStack {
                        Image(systemName: "hand.wave.fill")
                        Text("Reach out")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                
                // Notes section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(Color("textPrimary"))
                    
                    if contact.notes.isEmpty {
                        Text("No notes yet. Add one to remember what you talked about.")
                            .font(.subheadline)
                            .foregroundColor(Color("textMuted"))
                    } else {
                        ForEach(contact.notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                            HStack {
                                Text(note.content)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color("textSecondary"))
                                Spacer()
                                Text(note.createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(Color("textMuted"))
                            }
                            .padding(12)
                            .background(Color("surface"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    
                    // Add note (Free limit)
                    HStack {
                        TextField("Add a note...", text: $newNoteText)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("textPrimary"))
                        
                        Button("Save") {
                            guard !newNoteText.isEmpty else { return }
                            let success = engine.addNote(newNoteText, to: contact, in: modelContext)
                            if success {
                                newNoteText = ""
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .disabled(newNoteText.isEmpty)
                    }
                }
                .padding(.horizontal, 24)
                
                // Interaction Timeline
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline")
                        .font(.headline)
                        .foregroundColor(Color("textPrimary"))
                    
                    if contact.interactions.isEmpty {
                        Text("No interactions yet. Reach out to start the timeline.")
                            .font(.subheadline)
                            .foregroundColor(Color("textMuted"))
                    } else {
                        ForEach(contact.interactions.sorted(by: { $0.date > $1.date })) { interaction in
                            HStack(spacing: 12) {
                                Image(systemName: interaction.interactionType.icon)
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(interaction.interactionType.label)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color("textPrimary"))
                                    
                                    if !interaction.note.isEmpty {
                                        Text(interaction.note)
                                            .font(.system(size: 13))
                                            .foregroundColor(Color("textSecondary"))
                                    }
                                }
                                
                                Spacer()
                                
                                Text(interaction.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(Color("textMuted"))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .background(Color("background"))
        .sheet(isPresented: $showReach) {
            ReachActionSheet(contact: contact)
        }
    }
}
```

**Verify:** `Cmd+B` → `Cmd+R`. Tap a contact → detail view with Reach button, notes, timeline.

---

## Phase 9: StoreKit 2 — Free/Pro (1.5 hours)

### Task 9.1: StoreKitManager

Create `Echo/Services/StoreKitManager.swift`:

```swift
import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published var isPro = false
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    
    // ⚠️ Replace with your actual Product ID from App Store Connect
    static let proMonthlyID = "echo.pro.monthly"
    static let proAnnualID = "echo.pro.annual"  // Future
    
    private var updates: Task<Void, Never>?
    
    init() {
        updates = observeTransactionUpdates()
        
        Task {
            await loadProducts()
            await updatePurchasedStatus()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    func loadProducts() async {
        do {
            let ids = [Self.proMonthlyID]
            products = try await Product.products(for: ids)
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedStatus()
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("Purchase failed: \(error)")
            return false
        }
    }
    
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedStatus()
    }
    
    private func updatePurchasedStatus() async {
        var purchasedIDs = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            }
        }
        
        purchasedProductIDs = purchasedIDs
        isPro = purchasedIDs.contains(Self.proMonthlyID) || purchasedIDs.contains(Self.proAnnualID)
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                await transaction.finish()
                await updatePurchasedStatus()
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitError.failedVerification
        }
    }
}

enum StoreKitError: Error {
    case failedVerification
}
```

### Task 9.2: Integrate StoreKit into App

Update `EchoApp.swift`:

```swift
@main
struct EchoApp: App {
    @StateObject private var storeKit = StoreKitManager()
    
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: EchoContact.self, Interaction.self, Note.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environmentObject(storeKit)
        }
        .modelContainer(container)
    }
}
```

### Task 9.3: Pro gate in EchoEngine

Update `EchoEngine.addNote` to check Pro for multiple notes:

```swift
func addNote(_ content: String, to contact: EchoContact, in context: ModelContext, isPro: Bool = false) -> Bool {
    if !isPro && contact.notes.count >= 1 {
        return false
    }
    // ... same as before
}
```

### Task 9.4: SettingsView with Pro upgrade

Create `Echo/Views/Settings/SettingsView.swift`:

```swift
import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if storeKit.isPro {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.accentColor)
                            Text("Echo Pro")
                            Spacer()
                            Text("Active")
                                .foregroundColor(.green)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Echo Pro")
                                .font(.headline)
                            
                            Text("Unlock AI-powered Echo Engine, unlimited notes, calendar integration, and more.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Upgrade — $4/month") {
                                Task {
                                    if let product = storeKit.products.first {
                                        _ = await storeKit.purchase(product)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

**Important for App Store Connect:**

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Your App → Subscriptions → Create Subscription
3. Product ID: `echo.pro.monthly`
4. Price: $3.99 USD (Tier 1)
5. Create a Sandbox tester account for testing

---

## Phase 10: Polish & Testing (1 hour)

### Task 10.1: App Icon

Add app icon to `Assets.xcassets` → `AppIcon`:
- 1024×1024 PNG
- Design: Waveform icon on #090A0E background with #3B82F6 accent
- Use SF Symbol "waveform" as reference

Quick way: Use Apple's SF Symbol app to export waveform → overlay on dark bg in Preview/Sketch/Figma.

### Task 10.2: Final Integration

1. Wire up the tab bar in ContentView:

```swift
struct ContentView: View {
    @State private var hasImported = UserDefaults.standard.bool(forKey: "hasImportedContacts")
    
    var body: some View {
        Group {
            if hasImported {
                TabView {
                    EchoLayerView()
                        .tabItem {
                            Image(systemName: "waveform")
                            Text("Echo")
                        }
                    
                    PeopleLibraryView()
                        .tabItem {
                            Image(systemName: "person.2")
                            Text("People")
                        }
                    
                    SettingsView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                }
                .tint(.accentColor)
            } else {
                OnboardingView(hasImported: $hasImported)
            }
        }
    }
}
```

2. Save import state to UserDefaults in OnboardingView:

```swift
// After successful import:
UserDefaults.standard.set(true, forKey: "hasImportedContacts")
```

### Task 10.3: Smoke Test Checklist

Run through this on simulator:

- [ ] Fresh launch → Onboarding screen shows
- [ ] "Import Contacts" → permission prompt appears
- [ ] Grant permission → import runs → transitions to main app
- [ ] Deny permission → shows "Permission Denied" alternative
- [ ] Echo tab → shows imported contacts as cards
- [ ] Empty state without contacts → shows "No Echoes yet"
- [ ] Tap a card → Reach action sheet opens
- [ ] "Call" → opens phone app (simulator won't actually call)
- [ ] "Message" → opens Messages
- [ ] "Log as Reached Out" → logs interaction, updates "last reached out"
- [ ] People tab → shows all contacts in list
- [ ] Search → filters by name/phone/email
- [ ] Star toggle → moves between Echo Layer and People Library
- [ ] Contact detail → shows notes, timeline, reach button
- [ ] Add note → saves, appears in list
- [ ] Settings → shows free status, upgrade button
- [ ] No crash on any screen

---

## Phase 11: Git Commits

After each task, commit:

```bash
git add -A
git commit -m "Phase X: Description"
git push
```

Use these commit messages:

```
Phase 1: Xcode project scaffold + dark theme + colors
Phase 2: SwiftData models (EchoContact, Interaction, Note)
Phase 3: Contact import service with CNContacts
Phase 4: EchoEngine — manual layer management
Phase 5: EchoCardView + EchoLayerView main screen
Phase 6: Onboarding flow with permission handling
Phase 7: PeopleLibraryView with search
Phase 8: ContactDetailView + ReachActionSheet
Phase 9: StoreKit 2 integration + Settings
Phase 10: Polish, tab bar, final integration
```

---

## If Something Goes Wrong

| Problem | Fix |
|---------|-----|
| `ModelContext` not found | Make sure `import SwiftData` at top of file |
| `#Predicate` not working | Ensure iOS 17+ deployment target, clean build folder |
| Contacts permission not showing | Add `NSContactsUsageDescription` to Info.plist: "Echo uses your contacts to help you stay in touch. Everything stays on your device." |
| StoreKit product not loading | Must use Sandbox tester account. Product ID must exactly match App Store Connect. |
| SwiftData crash on migration | Delete app from simulator (`xcrun simctl erase all`), rebuild |
| "No such module 'SwiftData'" | Xcode → File → Packages → Reset Package Caches |

---

## What's NOT in v1.0 (deferred to v1.1)

- AI auto-layering (Core ML)
- Smart rhythm alerts ("It's been 19 days since you talked to Sarah")
- Calendar integration (EventKit)
- iMessage/WhatsApp frequency signals
- Widget + Dynamic Island
- iCloud sync
- Suggested conversation openers

---

> **Total estimated time:** ~10 hours for an experienced iOS dev. ~20-30 hours if you're new to SwiftUI/SwiftData.
> 
> **Target:** MVP on TestFlight within 1-2 weeks.
