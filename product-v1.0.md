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

## 7. B2B Opportunity: Sales CRM

During competitive research, a parallel market with stronger revenue potential emerged: individual sales professionals (insurance agents, realtors, financial advisors) who find existing CRMs too heavy.

### Existing B2B Players

| Product | Scale | Price | Key Signal |
|---------|-------|-------|------------|
| **Pipedrive** | 100K+ companies, 850+ staff, acquired for $1.5B (2020) | $14-99/seat | Started lightweight; now enterprise trajectory |
| **Less Annoying CRM** | Self-funded, family-owned since 2009 | **$15/user/mo** | "More than a spreadsheet, less than a CRM." Every feature "designed with the solo user in mind." Survived 17 years without VC — proves the market. |
| **Streak** | YC S11 | $15-129/mo | CRM inside Gmail. Locked in Google ecosystem. |
| **Close.com** | YC W11, ~$28M funded | $59-149/mo | Built-in calling. Mid-market, not solo. |

### B2B Market Size

| Segment | US Professionals | 10% adoption × $15/mo |
|---------|-----------------|----------------------|
| Insurance agents | 2.3M | $4.1B/yr |
| Real estate agents | 1.5M | $2.7B/yr |
| Financial advisors | 3.0M | $5.4B/yr |
| Independent sales reps | 6.0M+ | $10.8B/yr |
| **Total** | **~13M** | **~$23B TAM** |

### The Gap All Competitors Miss

| | Existing Products (Pipedrive, LACRM, Streak) | Echo for Business |
|---|---|---|
| **Platform** | Web-first, desktop mindset | iOS native, mobile-first |
| **Mental model** | Pipeline → "which deal closes next?" | Relationship → "who should I talk to today?" |
| **AI** | Workflow automation | Interaction signal analysis, smart prioritization |
| **Onboarding** | Manual data entry | One-tap contacts import, auto-layering |
| **Pricing** | $15-150/mo | $15/mo, mobile-native premium |
| **Privacy** | Cloud SaaS | On-device processing |

### Strategic Decision: B2C First, B2B Next

| Phase | Product | Goal |
|-------|---------|------|
| **v1.0** (now) | Echo B2C — personal relationship tool, $4/mo | Product-market fit validation + press/word-of-mouth |
| **v2.0** (3-6 months) | Echo Pro — business mode, $15/mo | Revenue engine, 13M US solo professionals |

**Rationale:**
- B2C is the storytelling wedge: "an app that reminds you to call your mom" gets App Store features, Product Hunt upvotes, and journalist coverage. B2B can't do that.
- B2C forces the product DNA to be right (care-driven, not guilt-driven). If B2B comes first, Echo slides into being "another LACRM" — useful but soulless.
- LACRM's 17-year survival at $15/mo is the insurance policy: if B2C growth is slow, B2B is a proven fallback with an existing customer base asking for exactly this.
- ~90% code reuse between modes — difference is onboarding split, pricing tier, and reminder tone.

---

## 8. Technical Architecture

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

## 9. Design Principles

| Principle | What it means |
|-----------|--------------|
| **Zero friction** | One permission → everything imported. No onboarding forms. |
| **Echo Cards, not rows** | Each person is a card with their photo, last conversation context, and a one-tap Reach button. Not a table row. |
| **Dark-first** | #090A0E background, #3B82F6 accent. SF Pro. iOS native feel. |
| **No guilt** | Never use "You haven't..." language. Always "It's been a while since..." — neutral observation, not accusation. |
| **One tap to act** | From card → call/message in one tap. No sub-menus. |
| **Haptics that feel human** | Light tap on Echo card flip. Subtle pulse when rhythm is "in sync." |

---

## 10. MVP Scope (v1.0)

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

## 11. Success Metrics (v1.0 → 3 months)

| Metric | Target | Why |
|--------|--------|-----|
| **Day-1 activation** | >60% grant Contacts permission | If they don't import, they never start |
| **Week-1 retention** | >40% open at least 3 times | Habit formation signal |
| **Reach actions** | >1 per week per active user | Core value: did Echo actually make them contact someone? |
| **Pro conversion** | >5% of active users | Validates $4/mo pricing |
| **30-day churn (Pro)** | <15% | Must beat Monica's pattern of "sign up, forget, cancel" |

---

## 12. Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Contacts permission denied | High | Graceful fallback: manual add flow, demo cards to show value first |
| "Another app I won't use" | Medium | Onboarding must deliver value in <30 seconds — import → see your people → done |
| Privacy backlash ("you're reading my contacts") | Low | All processing on-device. No network calls for contact data. Clear privacy label. |
| Monica/Dex adds mobile AI | Medium | Our moat is on-device + iOS-native feel. They'd need a full rewrite. |
| $4/mo too low for sustainability | Low | Zero server cost. Per-user marginal cost ~$0. Primary cost is App Store 15% cut. |
| B2B competitors (LACRM, Pipedrive) add mobile AI | Medium | Our moat is on-device + relationship model. They're pipeline-first and would need full rewrite for relationship-first AI. |

---

## 13. Version Roadmap

```
v1.0 — B2C MVP (now)
  ├── Phone Contacts import
  ├── Echo Layer + People Library (manual)
  ├── Reach actions (call/message/email)
  ├── Notes + Interaction timeline
  ├── StoreKit 2: Free / Pro ($4/mo)
  └── Dark theme, iOS native
        │
        ▼
v1.1 — AI + Intelligence (1-2 months post-launch)
  ├── AI auto-layering (Core ML)
  ├── Smart rhythm alerts
  ├── Calendar integration (Pro)
  ├── Widget + Dynamic Island
  └── iCloud sync
        │
        ▼
v2.0 — Echo for Business (3-6 months post-launch)
  ├── Business mode onboarding (solo sales, realtor, insurance)
  ├── Priority Contacts (expanded Echo Layer for 200+ clients)
  ├── Business-grade reminders (renewal, follow-up, birthday)
  ├── Pro tier: $15/mo
  ├── CSV export for compliance
  └── Shared team view (2-5 person teams)
```

---

> **Status:** Framework locked. B2C MVP build plan complete (`build-plan.md`). B2B opportunity validated and deferred to v2.0. Interactive prototype live (`prototype.html`). Ready for Mac build.
