# Echo — Product v1.0

> 念念不忘，必有回响。
> A whisper across time always finds its way back.

---

## 1. Product Identity

| | |
|---|---|
| **Name** | Echo |
| **App Store** | `Echo: Stay in Touch` |
| **Category** | Action-oriented relationship tool |
| **Market** | US / EU |
| **Platform** | iOS Native (SwiftUI) |
| **Pricing** | Freemium → Pro $4/mo |
| **Privacy** | Local-first (on-device processing). Not a marketing lead, but a technical foundation. |

---

## 2. Core Philosophy

**Old model (Monica/Dex):** "You forgot to call Amy. Here's a reminder. Shame on you." → Guilt-driven → churn.

**Echo model:** "You've been thinking about Amy. Here's the last thing she said. Maybe it's time." → Care-driven → habit.

The product doesn't nag. It surfaces what you already feel. You open Echo because someone crossed your mind — and Echo helps you act on that feeling.

---

## 3. The Dual-Layer Relationship Model

```
FULL ADDRESS BOOK (500+ contacts)
            │
     Echo Engine (AI)
            │
    ┌───────┴───────┐
    ▼               ▼
ECHO LAYER      PEOPLE LIBRARY
~30 people      ~470 people
──────────      ─────────────
• Main UI       • Silent background
• Smart cards   • Searchable
• Interaction   • No reminders
  timeline      • Archived, not lost
• Rhythm alerts
```

**Echo Layer** = People you genuinely care about. The engine identifies them from interaction signals; you can promote/demote manually.

**People Library** = Everyone else. They're not forgotten — just not in your daily orbit. Search finds them instantly.

**The key insight:** Echo doesn't ask you to "manage all 500 contacts." It automatically surfaces the 30 that matter — and leaves the rest quiet.

---

## 4. Four Product Pillars

### 4.1 Import — "It all comes in, instantly."

- One-tap Contacts permission → full address book imported
- Auto-deduplication
- Merges duplicate contacts intelligently
- Pro: Calendar event import, iMessage/WhatsApp frequency signals

### 4.2 Memory — "Oh right, her mom was sick."

- Per-person interaction timeline
- Notes: free-text, voice memo (Pro)
- Key facts: birthday, partner's name, kids, interests
- "Last conversation" context card
- Pro: Unlimited notes + full timeline history

### 4.3 Echo Engine — "Yeah, I should call Mike." (Not "you forgot Mike.")

**Free tier:**
- Manual Echo Layer management (promote/demote)
- 3 reminder cards
- 1 note per contact

**Pro tier ($4/mo):**
- AI interaction frequency analysis (calls, messages, calendar)
- Auto Echo Layer detection based on signal strength
- Smart rhythm alerts: "You and Sarah usually talk every 2 weeks. It's been 19 days."
- Echo Insights: relationship health score, reciprocity ratio
- Unlimited reminder cards + notes

### 4.4 Reach — "One tap, you're connected."

- One-tap call / iMessage / email from contact card
- Quick-log: "✓ Reached out" timestamp recorded
- Pro: Reach streak tracking, suggested conversation openers

---

## 5. Free vs Pro

| Feature | Free | Pro ($4/mo) |
|---------|------|-------------|
| Full contacts import | ✅ | ✅ |
| People Library (search, archive) | ✅ | ✅ |
| Echo Layer (manual) | ✅ | ✅ |
| Reminder cards | 3 | ∞ |
| Notes per contact | 1 | ∞ |
| Interaction timeline | Last 1 | Full history |
| AI auto-layering | — | ✅ |
| AI frequency analysis | — | ✅ |
| Smart rhythm alerts | — | ✅ |
| Echo Insights | — | ✅ |
| Calendar import | — | ✅ |
| Message frequency signals | — | ✅ |
| Reach streak tracking | — | ✅ |
| Suggested openers | — | ✅ |
| Custom theme colors | — | ✅ |
| App icon customization | — | ✅ |

**Logic:** Free builds the habit. Pro makes you never want to go back — losing Echo Engine feels like losing memory.

---

## 6. Competitive Position

| | Import | Memory | Engine | Reach |
|---|---|---|---|---|
| **Monica** | ❌ Manual | ⚠️ Notes | ❌ No AI | ❌ None |
| **Dex** (YC) | ⚠️ LinkedIn only | ⚠️ Timeline | ⚠️ Basic | ❌ None |
| **Echo** | ✅ One-tap | ✅ Timeline + notes | ✅ AI layers + rhythm | ✅ One-tap |

**Positioning:** Not a better Monica. The first tool that closes the loop from *remembering* to *doing*.

**Moats:**
1. **Local AI** — on-device processing of personal relationship data. Cloud competitors can't replicate without breaking trust.
2. **iOS-native DNA** — SF Pro, haptics, widgets, Dynamic Island. Web-wrapper competitors can't match.
3. **Behavioral lock-in** — the longer Echo tracks your interaction rhythms, the harder it is to leave. Your relationship memory lives here.

---

## 7. Technical Architecture

```
┌─────────────────────────────────────┐
│              SwiftUI App             │
├─────────────────────────────────────┤
│  UI Layer: Echo Cards, Timeline,     │
│             Reach Actions            │
├─────────────────────────────────────┤
│  Echo Engine (on-device)             │
│  ├── Contact signal analyzer         │
│  ├── Rhythm detector                 │
│  ├── Layer classifier               │
│  └── Core ML / Create ML models      │
├─────────────────────────────────────┤
│  Data Layer                          │
│  ├── Core Data / SwiftData (local)   │
│  ├── Contacts framework              │
│  ├── EventKit (Calendar, Pro only)   │
│  └── iCloud sync (optional)          │
├─────────────────────────────────────┤
│  StoreKit 2 (IAP)                    │
└─────────────────────────────────────┘
```

**Key decisions:**
- On-device AI: Core ML models for interaction frequency analysis, layer classification
- No server: zero infrastructure cost, zero privacy risk
- Contacts framework: read-only, processed locally, never uploaded
- iCloud sync: optional, encrypted, user opt-in

---

## 8. Design Principles

| Principle | What it means |
|-----------|--------------|
| **Zero friction** | One permission → everything imported. No onboarding forms. |
| **Echo Cards, not rows** | Each person is a card with their photo, last conversation context, and a one-tap Reach button. Not a table row. |
| **Dark-first** | #090A0E background, #3B82F6 accent. SF Pro. iOS native feel. |
| **No guilt** | Never use "You haven't..." language. Always "It's been a while since..." — neutral observation, not accusation. |
| **One tap to act** | From card → call/message in one tap. No sub-menus. |
| **Haptics that feel human** | Light tap on Echo card flip. Subtle pulse when rhythm is "in sync." |

---

## 9. MVP Scope (v1.0)

**Must have:**
- [ ] Contacts permission → full import + dedup
- [ ] Echo Layer UI (card-based, photo + name + last context)
- [ ] People Library (search, alphabetical list)
- [ ] Manual promote/demote between layers
- [ ] One-tap call / iMessage / email
- [ ] Quick-log after Reach action
- [ ] 1 note per contact (Free limit)
- [ ] Basic rhythm display: "Last reached out: 14 days ago"
- [ ] StoreKit 2: Free / Pro ($4/mo)
- [ ] Dark theme, SF Pro, iOS-native components

**Nice to have (v1.1):**
- [ ] AI auto-layering (Pro)
- [ ] Smart rhythm alerts (Pro)
- [ ] Calendar import (Pro)
- [ ] Widget: "Today's Echo" — top 3 people
- [ ] Dynamic Island: quick-reach on active call reminder

**Post-MVP:**
- [ ] iCloud sync
- [ ] Voice memo notes
- [ ] Suggested conversation openers
- [ ] Echo Insights dashboard
- [ ] Apple Watch companion

---

## 10. Success Metrics (v1.0 → 3 months)

| Metric | Target | Why |
|--------|--------|-----|
| **Day-1 activation** | >60% grant Contacts permission | If they don't import, they never start |
| **Week-1 retention** | >40% open at least 3 times | Habit formation signal |
| **Reach actions** | >1 per week per active user | Core value: did Echo actually make them contact someone? |
| **Pro conversion** | >5% of active users | Validates $4/mo pricing |
| **30-day churn (Pro)** | <15% | Must beat Monica's pattern of "sign up, forget, cancel" |

---

## 11. Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Contacts permission denied | High | Graceful fallback: manual add flow, demo cards to show value first |
| "Another app I won't use" | Medium | Onboarding must deliver value in <30 seconds — import → see your people → done |
| Privacy backlash ("you're reading my contacts") | Low | All processing on-device. No network calls for contact data. Clear privacy label. |
| Monica/Dex adds mobile AI | Medium | Our moat is on-device + iOS-native feel. They'd need a full rewrite. |
| $4/mo too low for sustainability | Low | Zero server cost. Per-user marginal cost ~$0. Primary cost is App Store 15% cut. |

---

> **Status:** Framework locked. Ready for fake-door validation (landing page + waitlist) before build.
