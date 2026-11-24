# HuntAI demo — Implementation guide

## Prerequisites

- Flutter SDK supporting Dart 3.3 or later.
- A configured Flutter target (Chrome, desktop, or a connected device).

## Setup and validation

From the project directory:

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

## Where to make changes

The app is organized by concern:

1. `lib/core/theme/` and `lib/core/constants/` — shared colors, light/dark themes, and responsive breakpoints.
2. `lib/data/demo_data.dart` — sample alert/event records and severity presentation.
3. `lib/features/dashboard/` — responsive dashboard, header, and seven overview cards.
4. `lib/features/visualizations/` — threat-analysis workspace, visualization widgets, graph models, and demo data preparation. The 2D and 3D graph alternatives share the same entity/connection fixtures and details inspector.
5. `lib/features/investigations/domain/` — immutable investigation, evidence, hypothesis, ATT&CK reference, analyst decision, and provenance models with validation.
6. `lib/features/investigations/data/` — repository contracts, typed repository exceptions, and the shared in-memory data source with in-memory repository implementations.
7. `lib/features/investigations/application/` — `InvestigationWorkflowService`, workflow validation and exceptions, and repository-derived investigation summaries.
8. `lib/features/investigations/generation/` — provider-independent hypothesis generation contracts, immutable request/results, deterministic mock provider, and orchestration validation.
9. `lib/features/investigations/presentation/` — app-scoped in-memory dependency composition, feature `ChangeNotifier`, investigation list, workspace sections, and analyst forms.
10. `lib/shared/widgets/` — sidebar, top navigation, and demo notice.
11. `lib/main.dart` — app shell, shared severity and alert review state, investigation dependency composition, and page navigation.

Add a sample alert by adding a `SecurityAlert` record to `demoAlerts`. Its `id` must be unique because review state uses the ID. To add a destination, update `SocSidebar`, the mobile navigation destinations, `_pages`, and `_buildPage` together.

## Current behavior boundaries

- Sample data is in memory and resets when the app restarts.
- “Reviewed” is a local UI state, not analyst feedback training.
- Risk score reasons are explanatory sample content, not a computed model.
- The chain is a hand-authored illustration, not automatic correlation.
- The timeline and heatmap show synthetic aggregates, not historical events.
- All attack-graph entities and paths are synthetic demonstration fixtures, not live telemetry. The 2D view ignores z; the 3D view uses fixture Z only in its display layout.
- The 3D graph sorts stable entity IDs into deterministic, evenly distributed display-only coordinates and incorporates fixture Z values; it does not represent measured locations or network topology. Positions are based on the full fixture set so filtering does not reflow nodes.
- Flutter-native projection and `CustomPainter` rendering provide near/far depth clipping and shared rendered-edge geometry for hit testing. Drag rotates, pan mode pans, pinch and mouse wheel zoom, and accessible buttons zoom, rotate, tilt, and reset the camera; 2D remains available.
- Observed, suspicious, and hypothesized relationship styles remain distinct. Confirmation is displayed separately, and unconfirmed/hypothesized fixtures are never presented as verified attack paths.
- Graph tests cover projection bounds, node/edge selection and overlap, camera input and accessible controls, selection clearing after filtering/search, and responsive widths. No performance target or frame rate has been measured.
- Relationship classification (observed, suspicious, hypothesized) and confirmation state are presented independently.
- Vulnerability analytics has no connected data source and must not be interpreted as a zero-vulnerability result.
- The severity visualization uses the existing alert fixtures; its selection is shared with the dashboard and alert inbox.
- No backend or external API configuration is required.
- Phase 5C investigation, evidence, hypothesis, and analyst-decision records are stored only in process memory and are lost when the process ends. Repository reads return immutable snapshots; invalid references, duplicate IDs, unsafe investigation deletion, and invalid updates throw typed repository exceptions.
- Investigation repository writes validate record links against the shared in-memory data source and graph-ID catalog supplied to it. No repository operation cascades deletion. Analyst decisions append to history and cannot be overwritten or deleted. Phase 5D workflow decisions atomically update the hypothesis review status while appending a decision; acceptance is not confirmation.
- `InvestigationWorkflowService` enforces `draft → active`, `active → onHold|closed`, and `onHold → active|closed`; closed investigations are terminal and reject workflow writes. It validates graph associations and evidence references, appends notes without rewriting earlier notes, requires at least eight non-whitespace rationale characters for hypothesis decisions, and derives summaries from repository data. Graph association is not evidence. AI-generated content cannot be represented as evidence.
- The review commit is atomic only within the shared in-memory data source. There is no general cross-repository transaction mechanism, durable storage, or transactional snapshot across the separate reads used for summaries. Concurrent workflow operations are not serialized.
- Phase 5E provides a deterministic mock generation provider, not a real LLM. It uses explicit configuration cues to classify supplied evidence IDs and groups records only by supplied graph references; it does not interpret raw telemetry. No rule match and insufficient evidence are distinct result states.
- Generation scores use a documented uncalibrated heuristic over distinct evidence count, evidence-type diversity, reliability, contradicting evidence, and missing observed time. Contradictions remain visible, duplicate evidence IDs do not inflate counts, and scores are never treated as probability or proof.
- The generation service validates provenance and all evidence/graph references before persistence. Generated hypotheses are `aiGenerated` unreviewed candidates, never evidence or automatically accepted. Stable IDs and generated-content comparison let repeated generation report already-present records instead of duplicating them, including when injected IDs or generation timestamps differ.
- `HypothesisRepository.addAll` validates the batch before a single process-local in-memory commit. It does not provide durable transaction guarantees. No external AI API, telemetry ingestion, threat-intelligence lookup, or persistent storage is present.
- Phase 5F adds immutable `AnalystAssessment` history, stored separately from decisions and hypothesis status. Its outcomes are `supports`, `partiallySupports`, `doesNotSupport`, `inconclusive`, and `needsMoreEvidence`. `InvestigationWorkflowService` exposes assessment append and retrieval while delegating validation to `AnalystAssessmentService`; support and contradiction remain separate, and assessment does not change review status or confirm an incident.
- Hypotheses carry zero or more immutable ATT&CK references, unique by technique ID. Proposed mappings retain analyst and timestamp provenance; only the proposing analyst may remove a proposal or request verification. Mapping associations are not proof that a technique occurred, and generated hypotheses cannot create mappings.
- The provider-independent `MitreReferenceVerifier` distinguishes verified, not-found, mismatched, deprecated, unverified, and unavailable outcomes. Verified metadata must include a matching technique ID/name and official HTTPS `attack.mitre.org` URLs. The default implementation reports unavailable; no official catalog is bundled and no runtime network request is made. The T1059 example is a test-only fixture based on the official page, labeled ATT&CK v20 / technique 2.7; it is not production catalog data and may become stale.
- Assessment append and reference changes validate before single synchronous in-memory commits. There is no durable transaction, concurrent-operation serialization, or consistent multi-repository snapshot. Assessment and mapping data are lost when the process ends.
- Phase 5G adds an investigation list and workspace UI using the existing application workflows; it does not add persistence, backends, authentication, telemetry ingestion, or a state-management package.
- No investigation records are seeded. Graph associations are explicit links to the existing synthetic graph fixtures; they are not evidence. The existing graph geometry, camera controls, filtering, and selection inspector are unchanged. Optional selection callbacks support explicit association actions from investigation context.
- Evidence creation preserves origin, source, reliability and rationale, classification, and optional graph relationships. AI-generated content is not offered as evidence. Hypothesis generation requires caller-supplied evidence polarity and displays its structured outcomes. Accepting a hypothesis remains acceptance for investigation only.
- Analyst notes, assessments, and decisions are displayed as distinct histories. Notes are appended, assessment does not mutate hypothesis decision/status, and hypothesis decisions are appended. Proposed ATT&CK references remain unverified when the default verifier is unavailable.
- A `ChangeNotifier` controller exposes loading and operation errors from the application layer to the UI. It ignores stale workspace loads after selection changes, avoids notifying listeners after disposal, and reports rejected overlapping submissions. The UI does not add transaction infrastructure; underlying repository atomicity remains process-local and limited to the operations already documented. Closed investigations disable ATT&CK verification as well as other workflow writes.
- The final UI polish uses responsive dashboard three-column/two-column/stacked layouts and a 1:2 desktop split for security score versus recent incidents. Threat Analysis pairs overview charts and keeps the existing graph and inspector renderer. Settings presents Data Source and External Services as clickable entries that navigate to dedicated informational pages (`DataSourceDetailsScreen` and `ExternalServicesCatalogueScreen`), disclosing synthetic data provenance, local in-memory storage, and catalogued external service boundaries without fake connection controls.

## Future work boundary

Phase 5E generation and Phase 5F assessment/reference management are bounded prototypes. Phase 5G adds their local UI, but not real inference, persistent storage, telemetry ingestion, runtime threat-intelligence services, or backend integration.
