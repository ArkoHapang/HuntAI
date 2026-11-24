# HuntAI learning demo

A small Flutter Security Operations Center dashboard that demonstrates the basic ideas in the HuntAI proposal: sample security events, readable risk explanations, alerts, and a simple attack-chain view.

> **Demo only:** the app uses fictional data stored in Dart constants. It does not monitor devices, connect to a backend, run machine learning, authenticate users, or call external threat-intelligence or AI services.

## Run it

From this directory:

```bash
flutter pub get
flutter run
```

To run the checks:

```bash
flutter analyze
flutter test
```

## Explore the app

- **Dashboard:** review seven SOC overview panels, filter sample alerts by severity and time range, and search the local alert fixtures.
- **Threat analysis:** explore the synthetic activity timeline and heatmap, filter the alert-backed severity chart, and switch between interactive 2D and 3D attack graphs.
- **Alerts:** filter by severity and mark sample alerts reviewed or reopen them.
- **Telemetry:** inspect a short, normalized event list.
- **Attack chain:** see how sample evidence can be grouped by investigation stage.
- **Investigations:** create and manage in-memory cases, record provenance-aware evidence, review hypotheses, append analyst assessments/decisions/notes, and propose ATT&CK references.
- **Settings:** toggle light and dark themes, review data source telemetry status, and inspect the external services catalogue.

### Settings details

- **Data Source:** displays local synthetic SOC demo fixtures.
  - Available categories: alerts, security events, graph entities, and graph relationships.
  - Live telemetry is not connected.
  - Data is stored in memory and resets after reload.
- **External Services:** catalogues integration boundaries and statuses:
  - **MITRE ATT&CK:** reference support exists, but default verification is unavailable.
  - **VirusTotal:** not configured (no API integration or live lookups).
  - **External AI provider:** not configured (current hypothesis generation is deterministic and local).
  - **Live SIEM integration:** not configured (no live SIEM connection).

HuntAI is strictly an evaluation and demonstration platform, not a production security monitoring system.

The timeline and heatmap are labeled synthetic aggregate demonstrations, not historical telemetry. All graph entities and relationships are synthetic demonstration fixtures. The 3D graph uses deterministic display-only coordinates and Flutter-native perspective projection and `CustomPainter` rendering; positions are not measured physical or network locations. Drag rotates the camera, pan mode enables drag-to-pan, pinch and mouse wheel zoom, and accessible buttons provide zoom, rotation, tilt, and reset controls. Relationships retain observed (solid blue), suspicious (dashed orange), and hypothesized (short-dashed muted) classifications, with confirmation shown separately. Current graph paths are illustrative and unconfirmed. Vulnerability analytics stays unavailable until a data source is connected. The severity chart uses the existing alert fixtures, and selecting a severity also filters the dashboard and alert inbox.

The visualization test suite covers projection bounds, depth-aware picking, camera gestures and controls, filtering and search, relationship classifications, selection details, and responsive graph layouts. These widget tests are not a performance benchmark or live telemetry verification.

The app remains a small Flutter demo, organized into focused files for design tokens, sample data, the responsive shell, dashboard panels, and visualizations. Existing alert, telemetry, attack-chain, and settings screens remain available through [lib/main.dart](lib/main.dart).

## Investigation domain foundation

The investigation feature presents responsive list and workspace screens over the existing application workflows. It starts empty: no investigation records are preloaded. Records, analyst notes, assessments, decisions, and proposed ATT&CK references remain in memory and disappear when the application process ends. Assessment outcomes record an analyst's evaluation; they do not accept or reject a hypothesis. Decisions remain a separate append-only in-memory history.

Hypotheses can have proposed MITRE ATT&CK references. Proposed mappings are not verified findings, and the default verifier reports unavailable because no authoritative catalog is bundled and runtime network verification is disabled. Neither a mapping nor a hypothesis confirms malicious activity. The deterministic mock generator only uses explicit analyst-supplied evidence polarity cues; it does not interpret telemetry or call an AI service. Graph associations point to synthetic fixtures, are separate from evidence, and do not establish malicious activity. No persistence, backend, authentication, or defensive response action is implemented.

## Project documents

- [Product requirements](docs/prd.md)
- [Design notes](docs/design.md)
- [Architecture](docs/architecture.md)
- [Implementation guide](docs/implementation.md)

## Suggested learning path

1. Change the sample alerts in [lib/data/demo_data.dart](lib/data/demo_data.dart).
2. Read `SecurityAlert` and `Severity` to understand the data shape.
3. Follow `HuntAiHome` to see page navigation and review state.
4. Update an individual dashboard panel under `lib/features/dashboard/widgets/`.
5. Run `flutter test` after changing behavior.

The sample IP addresses use documentation-only ranges. Do not treat any demo result as a real security finding.
