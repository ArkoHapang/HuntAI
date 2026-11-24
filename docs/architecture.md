# HuntAI demo — Architecture

## Overview

This is intentionally a small Flutter application. Design tokens, sample data, the SOC shell, and dashboard panels are split into focused files; the existing secondary screens remain together in `lib/main.dart` to keep the demo easy to follow.

```text
main()
  └── HuntAiApp
      └── HuntAiHome
          ├── SocDashboardScreen
          │   ├── DashboardHeader
          │   ├── ThreatDetectionCard
          │   ├── SecurityEventsCard
          │   ├── SystemHealthCard
          │   ├── RecentIncidentsPanel
          │   ├── SecurityScoreCard
          │   ├── SecurityToolsPanel
          │   └── VulnerabilityCard
          ├── VisualizationWorkspace
          │   ├── ThreatActivityChart
          │   ├── SecurityHeatmap
          │   ├── ThreatSeverityChart
          │   ├── AttackGraph2D / AttackGraph3D
          │   └── VulnerabilityAnalyticsChart
          ├── AlertsPage
          ├── TelemetryPage
          ├── AttackChainPage
          ├── InvestigationManagementScreen
          │   └── InvestigationWorkflowService
          │       └── shared in-memory investigation repositories
          └── SettingsPage
              ├── DataSourceDetailsScreen
              └── ExternalServicesCatalogueScreen
```

## Data flow

1. `lib/data/demo_data.dart` defines immutable, fictional alerts and telemetry fixtures.
2. `VisualizationDataService` prepares explicitly synthetic timeline and heatmap aggregates, illustrative graph fixtures, and severity totals computed from the existing alerts.
3. `HuntAiHome` owns the current page, shared severity filter, and set of locally reviewed alert IDs.
4. The dashboard and alert inbox filter sample alerts by severity, relative age, and local text query; the visualization workspace shares the severity filter with both.
5. Existing SOC pages receive the state they need and callbacks for local actions; they use no database or network client. The investigation feature is an additive service-backed UI over the in-memory data layer.
6. `SocConstants` centralizes shell and responsive breakpoints.
7. `AppTheme` and `AppColors` provide the shared light/dark design system; dark is the default.
8. `_themeMode` is a `ValueNotifier` observed by `HuntAiApp`, so theme changes rebuild the app theme.
9. Phase 5C repositories expose investigation-domain records through one shared in-memory data source; Phase 5D coordinates investigation workflows, and Phase 5E generates evidence-grounded mock hypotheses through explicit analyst-supplied cues.
10. `InvestigationFeatureDependencies` composes one process-local repository set, workflow service, deterministic mock generator, and feature-scoped `ChangeNotifier`. The investigation screens call those application services; they do not own domain rules or persistent storage.

## Main types

- `SecurityAlert`: fields used to render one alert.
- `Severity`: severity categories and their display labels/colors.
- `HuntAiHome`: responsive app-shell state, page navigation, and review state.
- `SocSidebar` and `SocTopNav`: desktop/tablet navigation and responsive top controls.
- `SocDashboardScreen`: responsive dashboard composition and demo-only filters.
- `VisualizationWorkspace`: responsive overview and section navigation for the Phase 3 visualizations.
- `VisualizationDataService`: separates alert-backed severity totals from synthetic aggregate and illustrative graph fixtures.
- `AttackGraph2D` and `AttackGraph3D`: alternative interactive views over the same graph models and fixtures.
- `InvestigationManagementScreen` and `InvestigationWorkspaceScreen`: responsive list and case workspace for the existing investigation workflows.
- `InvestigationUiController`: feature-scoped loading, action, and error state; it forwards operations to application services and exposes repository-derived results.
- `AttackGraph3DLayout`: stable ID-derived display coordinates; it does not mutate the entity model or assert real topology.
- `AttackGraph3DProjection` and `AttackGraph3DCamera`: perspective projection and camera state for the Flutter `CustomPainter` 3D view.
- Phase 5C investigation repositories: contracts for investigations, evidence, hypotheses, and analyst decisions, with in-memory implementations that reuse the immutable Phase 5B domain models.
- Phase 5D `InvestigationWorkflowService`: application-level lifecycle, graph-association, evidence, note, hypothesis-review, and summary operations over the Phase 5C repositories.
- Phase 5E `HypothesisGenerator` and `HypothesisGenerationService`: provider-independent generation request/result contracts, a deterministic cue-driven mock provider, and validated persistence through the workflow boundary.
- Dashboard cards: focused displays derived from the existing sample fixtures; unavailable services are marked not connected or demo.
- `AlertCard` and `_ChainStage`: existing alert and attack-chain display widgets.

The dashboard range selector filters sample alerts by their displayed relative ages; telemetry fixtures remain unchanged. The visualization timeline and heatmap are generated synthetic aggregates rather than reconstructed events because the fixtures do not contain historical timestamps or sufficient records. Graph paths are illustrative and unconfirmed. The 3D graph sorts stable entity IDs and distributes display-only X/Y/Z positions over a sphere, incorporating each fixture Z value; these coordinates are not measurements, and filtering does not reflow nodes. Both graph views preserve relationship classification, while the details panel reports confirmation independently. Vulnerability analytics reports that data is not connected rather than fabricating counts. Search is a local alert fixture search, and the refresh/export controls explicitly explain that those services are not implemented.

The 3D graph fixtures are synthetic demonstration data, not live telemetry. The renderer uses the existing `AttackEntity` and `AttackConnection` models without adding a second graph model. Its deterministic layout is cached until the entity list changes, and fixture Z contributes only to display coordinates.

The 3D painter applies yaw and pitch rotation followed by perspective projection. Projection rejects non-finite/out-of-range world coordinates, invalid camera values, and points outside the near and far depth planes. Nodes and edges are depth-sorted and edges are drawn before nodes. The same clipped projected edge geometry is used for painting and edge hit testing; overlapping nodes resolve to the nearest camera-space depth, and overlapping edges follow the painter's depth order. Filter/search changes clear selection so hidden entities do not return as stale inspector content.

Pointer drag rotates the camera, the gesture-mode chip switches drag to pan, pinch zooms around the focal point, and desktop wheel zoom is centered at the pointer. Accessible zoom, rotate, tilt, and reset buttons provide non-gesture camera operation. Camera state and selected-item summaries are exposed through semantics. Widget tests cover projection clipping, overlapping picks, search/filter selection, controls, relationships, and 390/768/1199/1440-pixel graph widths; they do not establish frame-rate or large-graph performance.

## Intended production evolution

The following is future architecture, not implemented in this demo:

```text
Telemetry sources → ingestion/API → normalization → storage
                                     ├→ feature extraction → anomaly model
                                     ├→ risk scoring → alert service
                                     ├→ correlation → attack chains
                                     └→ threat-intel enrichment
Analyst application ← API ← investigation evidence and feedback
```

For a real system, separate UI from repositories/services, validate and authorize every API, protect secrets, make external-service failures visible, and avoid sending sensitive telemetry to an AI service without an approved privacy design.

## Investigation repository boundary (Phase 5C)

```text
InvestigationRepository ─┐
EvidenceRepository ──────┤
HypothesisRepository ────┼──> InMemoryInvestigationDataSource
AnalystDecisionRepository┘       ├── investigations
                                 ├── evidence
                                 ├── hypotheses
                                 └── decisions (append order)
```

Each repository contract can be replaced without changing the domain models. The four in-memory implementations share one data source instance so a record and its investigation link can be validated first and committed together. The data source accepts an injected catalog of graph entity and connection IDs; it stores only identifiers and does not change `AttackEntity` or `AttackConnection`.

Repository writes reuse `InvestigationReferenceValidator` for same-investigation and graph/evidence references. Writes validate the prospective snapshot before changing storage. Investigation updates preserve existing links and notes; evidence, hypothesis, and decision additions update the owning investigation link atomically. The standalone hypothesis status update follows a shared transition policy but does not create an analyst decision. The workflow service uses a separate atomic review operation to update a hypothesis and append its decision together. General decision appends remain history-only; workflow review decisions preserve append order and never replace earlier decisions.

Investigation deletion is rejected while evidence, hypotheses, or decisions remain; no cascade deletion is performed. Duplicate IDs, missing records, invalid references, unsafe deletes, and invalid updates have typed repository exceptions. Returned lists and data-source map snapshots are unmodifiable.

| Exception | Thrown when |
|---|---|
| `DuplicateRecordException` | A create/add/append operation reuses an ID in that record type. |
| `RecordNotFoundException` | An ID-based read, update, delete, or history query targets a missing record. |
| `InvalidRelationshipException` | A new record points to a missing or cross-investigation record, or an unknown graph ID. |
| `UnsafeDeletionException` | Investigation deletion is attempted while related records remain. |
| `InvalidUpdateException` | An update removes protected references/notes, regresses timestamps, or requests a disallowed hypothesis transition. |
| `InconsistentRepositoryStateException` | An existing stored snapshot fails integrity checks before a write. |

This implementation is in-memory only. All records disappear when the application process ends. It does not provide persistence, cross-process consistency, authentication, authorization, tamper evidence, or an audit-grade durable decision log.

## Investigation application workflows (Phase 5D)

`InvestigationWorkflowService` coordinates the existing repository contracts and does not own UI state or persistence. It creates, retrieves, lists, and updates investigations; associates graph IDs; adds evidence and append-only analyst notes; starts hypothesis review; records analyst decisions; and derives read-only summaries from repository results.

Investigation lifecycle transitions are deliberately limited to `draft → active`, `active → onHold|closed`, and `onHold → active|closed`. `closed` is terminal and workflow writes are rejected for closed investigations. Graph associations are validated against the same graph-ID catalog used by the in-memory data source; association alone is not evidence or a claim of malicious activity. Evidence retains its provenance, reliability, and rationale, must refer to graph IDs associated with that investigation, and cannot represent AI-generated hypotheses. Domain validation also prevents AI-generated content from being constructed as evidence.

Analyst notes are appended with their ID, author, timestamp, and content; ordinary metadata updates do not rewrite them. Hypothesis decisions require at least eight non-whitespace rationale characters and matching investigation/hypothesis references. Accept means accepted for continued investigation, not proven; reject, defer, and inconclusive decisions also preserve prior evidence and decision history. No review operation confirms an incident or triggers a defensive response. Summary counts, status, associations, and latest decision derive from current repository records.

The in-memory decision repository validates the proposed review and performs the hypothesis-status update, investigation timestamp update, and decision append in one synchronous commit. This is a narrow process-local atomic operation, not a general transaction facility or durable/audit-grade log. Other workflow writes use their repository's validated single-record commit. Summary fields are read through separate repository calls and are not a transactional snapshot; concurrent operations are not serialized.

Application exceptions distinguish invalid input (including short decision rationale), closed investigations, invalid lifecycle or hypothesis transitions, duplicate graph associations, and unknown graph references. Invalid input is rejected before the relevant repository write; closed-record errors apply to all workflow mutations; transition errors apply to lifecycle and review operations. Repository exceptions continue to describe storage and relationship failures.

## Hypothesis generation prototype (Phase 5E)

`HypothesisGenerator` accepts an immutable generation request containing one investigation's evidence, existing hypotheses, associated graph IDs, and generation configuration. It returns a sealed result distinguishing generated hypotheses, insufficient evidence, no applicable rules, invalid context or references, invalid generated output, and generation failure. The latter outcomes are not represented as an indistinguishable empty list.

`DeterministicMockHypothesisGenerator` is a local rule-based prototype, not an LLM or production inference provider. Its rules use explicit configuration cues that designate supplied evidence IDs as supporting or contradicting; it does not infer polarity from raw telemetry text. It groups those records by graph entity/connection references present in the request, requires the configured number of distinct supporting records for an anchor, processes anchors in stable sorted order, and emits no hypothesis when no rule applies. A generated statement is explicitly an investigative lead, not proof. Alternative explanations and evidence gaps remain visible.

The confidence score is an uncalibrated bounded heuristic:

```text
0.40
+ 0.10 × min(distinct supporting evidence count, 3)
+ 0.05 × min(max(distinct supporting evidence types - 1, 0), 2)
+ 0.05 × mean supporting reliability rank / 3
- 0.10 × min(distinct contradicting evidence count, 3)
- 0.05 if no supporting record has observedAt
```

Reliability ranks are unassessed=0, low=1, medium=2, and high=3. Duplicate IDs are counted once. Under the implemented thresholds the score remains in `[0.15, 0.85]`; it is not clamped, calibrated, or interpreted as a probability. The explanation includes support/contradiction counts and calls out the heuristic limitation.

Generated records use `DataOrigin.aiGenerated`, generator name/version in provenance, the injected generation time, and `GenerationMetadata`. Their source evidence IDs and graph references are validated against the request; they start as unreviewed candidates. Synthetic evidence keeps its original synthetic provenance. The generator never creates evidence or ATT&CK/CVE references.

`HypothesisGenerationService` assembles context from the workflow service, validates the complete provider output, handles deterministic ID collisions, and persists only new candidates through the workflow service. Repeated generation reports equivalent generated content as already present even if an injected ID strategy or generation clock differs; a conflicting record with the same ID is rejected. `HypothesisRepository.addAll` validates the full batch before one synchronous in-memory commit, preventing partial writes for invalid batches. Repository write errors remain visible to the caller, and prior analyst decisions are not modified.

This prototype requires callers to supply explicit evidence-polarity cues and is intentionally limited to generic association-based leads. It does not interpret event semantics, discover attack chains, query threat intelligence, make probabilistic predictions, or call an external AI service. The generator itself has no UI or persistence; the Phase 5G screens invoke it through the workflow service and all records remain process-local. Future providers must implement the same contract and preserve the same validation/provenance boundaries.

## Hypothesis assessment and ATT&CK reference management (Phase 5F)

`AnalystAssessment` is an immutable analyst-authored record with an outcome distinct from `HypothesisStatus` and `AnalystDecisionType`. Its outcome values are `supports`, `partiallySupports`, `doesNotSupport`, `inconclusive`, and `needsMoreEvidence`. It records the investigation and hypothesis IDs, analyst, UTC assessment time, rationale, reviewed evidence IDs, separate supporting and contradicting evidence IDs, alternatives, and gaps. Supporting and contradicting records must be disjoint and included in the reviewed set. `AnalystAssessmentService` validates the investigation, hypothesis, and every evidence reference before appending; records from another investigation or missing records are rejected. Assessment history is stored separately and ordered by assessment time, then ID. Assessment creation does not change hypothesis status or decision history, and does not confirm an incident.

`InvestigationWorkflowService` exposes assessment append and history retrieval, and delegates validation to the assessment workflow helper. It also exposes ATT&CK proposal, retrieval, removal, and verification operations through the same workflow boundary. The assessment repository is required when constructing the workflow service; the verifier defaults to an explicit unavailable implementation.

`Hypothesis` carries an immutable collection of `MitreAttackReference` values, unique by technique ID. Reference URLs must be HTTPS; the mapping workflow also checks the ATT&CK technique-ID syntax. A proposed mapping stores the proposing analyst and UTC proposal time without verification metadata. Only the proposing analyst may remove it or request verification. A verified reference retains its proposal metadata and adds `MitreVerificationMetadata`; verification additionally requires the provider's technique ID and name to match, an HTTPS URL on `attack.mitre.org`, and consistent catalog-version metadata. Only a proposed, unverified mapping can be removed or verified. The association describes an analyst mapping, not proof that the technique occurred. Generated hypotheses are prohibited from adding ATT&CK mappings.

`MitreReferenceVerifier` is provider-independent and returns distinct verified, not-found, mismatched, deprecated, unverified, or unavailable outcomes. The default `UnavailableMitreReferenceVerifier` is explicit: this build has no bundled authoritative catalog and makes no runtime network requests. There is no production path that marks an unverified proposal as verified unless an injected verifier supplies matching metadata and official source URLs. An invalid or incomplete positive result is downgraded to an unverified result and is not persisted. Verification-provider failures propagate rather than being represented as a successful check.

The workflow tests use the official [MITRE ATT&CK T1059 page](https://attack.mitre.org/techniques/T1059/) as a test-only verifier fixture, including its displayed ATT&CK v20 and technique 2.7 version labels. This is not a bundled runtime catalog and does not establish that the fixture remains current. Production verification remains unavailable until an authoritative provider with an explicit catalog/version lifecycle is supplied.

Assessment append and each mapping update are validated before a single synchronous in-memory commit. Invalid input or relationships do not partially mutate stored assessments or references. These commits are process-local only; there is no durable storage, general transaction facility, concurrency serialization, or transactional snapshot across the service's validation reads. Records disappear when the process ends. No UI, backend, persistence, runtime ATT&CK fetch, automatic hypothesis decision, or incident confirmation is part of Phase 5F.

## Investigation user interface (Phase 5G)

The investigation destination provides a searchable/filterable list and a responsive workspace with overview, evidence, hypotheses, assessments, ATT&CK, and activity sections. Sections are kept mounted while switching within a case. Creation, metadata/status/priority changes, evidence entry, notes, hypothesis review, assessments, decisions, and proposed references all go through `InvestigationUiController` into the existing application services. Closed investigations are read-only in the UI; lifecycle and relationship validation remain enforced by the workflow layer.

There are no preloaded investigation cases. The app-scoped dependency factory supplies the graph catalog from existing synthetic visualization fixtures but seeds no investigations or evidence. The graph selection integration adds optional callbacks to the 2D/3D graphs; analysts explicitly choose to associate a selected item. Associations remain graph references and never become evidence automatically. The 2D/3D geometry, filters, camera behavior, and existing selection inspector are otherwise unchanged.

Evidence forms collect origin, source, classification, reliability, reliability rationale, and optional already-associated graph IDs. AI-generated content is excluded from evidence creation. The hypothesis screen requires explicit analyst-supplied support/contradiction cues before the deterministic mock generator runs and presents insufficient-evidence/no-rule/failure outcomes distinctly. Hypothesis acceptance is labeled as continued investigation, not proof. Assessments, decisions, and notes are separate historical records; assessment does not change decision/status and decisions append without overwriting prior entries. ATT&CK proposals are visibly unverified, and verification remains unavailable by default.

The UI uses Flutter SDK `ChangeNotifier` and widgets only; no dependency was added. Stale workspace-load results are ignored when the selected investigation changes, and in-flight controller work does not notify listeners after disposal. Duplicate submissions are rejected with a visible operation-in-progress error. All screens operate on process-local in-memory repositories. There is no UI-to-storage transaction or concurrency coordination beyond the atomic repository operations documented above. If a sequence requires separate service reads/writes, the application layer does not claim general transaction support. Closed investigations disable reference verification as well as other workflow writes. The UI does not add authentication, authorization, external AI/ATT&CK services, telemetry ingestion, incident confirmation, or defensive response.

## Dependencies

The runtime uses only Flutter SDK widgets and Material icons. This keeps first run offline-friendly and reduces setup for learners.
