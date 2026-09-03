# Echo Agentic Pipeline

## Purpose

Echo's Pipeline is a relationship-centered host for supervised agents. It tracks people, organizations, work items, communication, reasoning, evidence, next actions, and moments that deserve human judgment. DeepSeek can analyze and draft, an organization's public website can be read as evidence, and Gmail can send only after an explicit human confirmation.

## Architecture

```text
Pipeline
  └─ Deal (migration-compatible Pipeline Item)
       ├─ Organization ── EchoContact(s)
       ├─ primary EchoContact + related EchoContact(s)
       ├─ AgentIntelligence ── Evidence
       ├─ AgentAction(s) ── Evidence
       └─ Interaction(s)
```

`Deal` remains the persisted type so existing installations do not lose their stored deals. Its role is broadened to a general Pipeline Item: monetary value is optional, stages are agentic, and it can connect one organization with several people. The legacy `contact` property is the primary contact.

The SwiftUI layer reads models while integrations write through service boundaries (`AgentService`, `ResearchProvider`, `CommunicationProvider`, and `EmailDeliveryProvider`) and `PipelineService`. This keeps external providers out of views and makes providers replaceable.

## Data models

- `Pipeline`: reusable process, objective, ordered stage identifiers, archive state, optional agent enablement, authority level, and optional monetary metrics.
- `Organization`: identity, website/domain, industry, location, notes, contacts, and work items.
- `Deal`: compatible work item with optional value/currency, status, priority, next action, organization, primary/relevant contacts, human notes, Human Attention, intelligence, and action log.
- `AgentIntelligence`: optional score/confidence/intent, summary, why it matters, next recommendation, uncertainty, evaluation time, and evidence. It never replaces human notes.
- `AgentAction`: timestamped audit event for research, analysis, recommendations, outreach preparation, follow-up, received messages, stage/score changes, escalation, or other work. Status and source are explicit.
- `Evidence`: title, optional URL, source type, capture time, and excerpt/summary. A source record is not represented as verified merely because it exists.
- `Interaction`: relationship communication or event. Actor (`human`, `agent`, `external`) and direction (`inbound`, `outbound`, `internal`) are stored separately from legacy Gmail metadata.

## Stages and Human Attention

New pipelines default to:

`Discovered → Qualified → Contacted → Engaged → Interested → Opportunity → Human Attention → Won / Lost`

The ordered stage identifiers live on each `Pipeline`. Users can add, rename, reorder, and remove unused stages. Won and Lost are protected terminal stages; a stage containing items cannot be deleted, and renaming safely migrates those items. Legacy `Lead`, `Quoted`, `Negotiating`, `Closed Won`, and `Closed Lost` raw values remain readable and appear when existing items use them.

Human Attention is both a visible stage and an independent flag. This allows an item to remain in its meaningful workflow stage while still being escalated. Attention appears at the top of Pipeline and on the Echo home screen. Toggling it and moving stages create auditable Agent Actions.

## Interaction versus Agent Action

- `Interaction` records communication or a relationship event: a call, message, email, meeting, or outreach.
- `AgentAction` records what an agent reasoned, proposed, changed, or attempted.

One event should not be duplicated. For example, a genuinely sent email is an Interaction; the reasoning that suggested it is an Agent Action. A prepared draft is not marked as sent.

## Authority levels

- `manual`: no agent actions.
- `assist`: analyze and recommend.
- `supervised`: prepare actions, with consequential external actions requiring approval.
- `autonomous`: may act only inside a separately configured policy.

Version 0.1 persists and enforces this boundary. Analysis, research, and drafting are available; external email always remains supervised. The `autonomous` value is a policy foundation, not permission to bypass confirmation.

## Filtering and summaries

Filtering supports pipeline, stage, Human Attention, priority, organization, and next-action state. Sorting supports newest, next action, priority, and AI score. Summary metrics show Active, Attention, and Overdue; Pipeline Value only appears when the pipeline or at least one item meaningfully tracks money.

## Migration behavior

Startup runs an idempotent lightweight migration:

1. It creates one default Pipeline only when no active pipeline exists.
2. Existing Deals without a pipeline are attached to it.
3. New optional/defaulted fields are backfilled without rewriting titles, values, stages, dates, or contacts.
4. Existing contact `companyName` values create or reuse an Organization, linked case-insensitively.
5. The existing primary contact is also placed in the relevant-people collection.

SwiftData performs the schema's inferred lightweight migration. Existing Deal stage raw values and zero/nonzero values remain interpretable. The migration never deletes user data.

## Extension points and safety

DeepSeek analysis receives privacy-reduced context and writes structured intelligence separately from human notes. Website research reads only a configured HTTP(S) organization page and records its real URL, title, timestamp, and excerpt as evidence. Gmail drafts remain proposed Agent Actions until the user reviews and confirms them; an outbound Interaction is created only after Gmail returns a provider message ID. Failed/proposed work never appears as completed or sent. Existing Google connections must reconnect once to grant the new `gmail.send` scope.

## Verification scenario

Debug launch argument `--echo-agentic-demo` inserts an idempotent local scenario with one agentic pipeline, two organizations, two people per organization, items in multiple stages, a Potential Partnership, AI score/summary/evidence, stage/action history, inbound and human interactions, a next action, and Human Attention. It exists only for development and UI verification; production startup still creates no demo contacts.

## Deliberate boundaries

- Website research reads the organization's configured public page; it is not a general web crawler or lead scraper.
- Gmail delivery supports reviewed plain-text email. Attachments, reply threading, bulk sends, and silent background sending are intentionally excluded.
- Social platforms are not sent through private or unsupported automation APIs; existing user-initiated deep links remain available.
- SwiftData's inferred migration is used because all changes to existing entities are optional or defaulted. A future breaking schema change should introduce `VersionedSchema` and an explicit migration plan.

## Implementation summary

The upgrade adds five first-class persisted entities, expands Deal and Interaction compatibly, adds migration/query/audit services, editable stages, real DeepSeek analysis and drafting, source-backed website research, confirmed Gmail delivery, responsive iPhone/iPad Pipeline UI, item/organization/intelligence detail, Human Attention on home, and unit/UI coverage for the acceptance workflow.
