# HuntAI demo — Product requirements

## 1. Product summary

HuntAI is presented as an AI-assisted threat-hunting platform. This project is a small Flutter learning demo of the analyst-facing experience, not a production security product.

## 2. Problem

Security teams can receive more event data and alerts than they can manually review. They need a way to spot unusual behavior, understand why an alert matters, and connect related evidence during an investigation.

## 3. Goal

Provide a simple, understandable UI that explains the main HuntAI concepts using safe, fictional sample data:

- Telemetry events
- Severity and a 0–100 illustrative risk score
- Alert review state
- A sequence of attack-investigation stages

## 4. Users

- **Learner / project reviewer:** understands the proposed product by exploring the UI and reading the code.
- **SOC analyst (illustrative persona):** scans alerts, reviews evidence, and follows a correlated sequence.

## 5. Scope

### Included

- Responsive Flutter dashboard for desktop and mobile layouts.
- Overview cards and recent alert summary.
- Alert list with severity filters.
- Toggleable “reviewed” state for sample alerts.
- Normalized sample telemetry feed.
- Example attack-chain stage timeline.
- Explainable example risk score.
- Light and dark themes.

### Not included

- Ingestion from operating systems, logs, or SSH honeypots.
- Real authentication, user accounts, roles, or authorization.
- Network calls, SQLite persistence, or a backend API.
- Isolation Forest or any other machine-learning model.
- VirusTotal, AbuseIPDB, or other threat-intelligence lookups.
- Generative AI investigation summaries.
- Production incident response, blocking, or containment actions.

## 6. User stories and acceptance criteria

1. **As a learner,** I can see what data is fictional so I do not mistake the UI for a live security monitor.
   - A demo notice and a DEMO badge are visible.
2. **As an analyst persona,** I can review suspicious sample alerts.
   - Alerts show severity, time, source, stage, and risk score.
   - I can filter alerts by severity.
   - I can mark an alert reviewed and reopen it.
3. **As a learner,** I can understand why a score is high.
   - The overview includes a sample score with readable contributing signals.
4. **As a learner,** I can see how individual alerts could form an attack sequence.
   - The chain page lists stages and distinguishes those with sample evidence.
5. **As a user,** I can choose a comfortable theme.
   - Settings and the top-bar button switch between light and dark themes.
6. **As a developer,** I can change the demo without backend knowledge.
   - Sample records and UI widgets live in a single, clearly sectioned Dart file.

## 7. Success criteria

- App starts using standard Flutter commands.
- `flutter analyze` and `flutter test` pass.
- A new reader can locate the sample records and edit a visible alert without tracing a complex architecture.

## 8. Safety and privacy

All data is static and fictional. The app does not collect or transmit user or security data. Any future integration must add explicit source configuration, error handling, privacy controls, and security review before being represented as operational.
