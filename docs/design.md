# HuntAI demo — Design notes

## Experience goals

- Make a security dashboard understandable at a glance.
- Explain why an alert is noteworthy instead of showing an unexplained score.
- Keep actions low-risk: the demo only changes local review state.
- Make the visual demo’s limitations impossible to confuse with live monitoring.

## Information structure

The main navigation has seven destinations:

1. **Dashboard** — metrics, sample alerts, and a score explanation.
2. **Threat analysis** — synthetic activity charts and interactive graph.
3. **Alerts** — severity filter and reviewed/reopen control.
4. **Telemetry** — normalized example events.
5. **Attack chain** — a staged sample investigation.
6. **Investigations** — analyst-managed, process-local case workspaces.
7. **Settings** — theme and source disclaimer.

## Layout

- At widths of 760 logical pixels and above, use a side navigation rail.
- At smaller widths, use a bottom navigation bar.
- Use scrollable page content so cards remain usable on short or narrow screens.
- Keep summary cards in a wrapping layout that adapts to available width.
- Investigation lists and case sections reflow on narrow screens; workspace sections remain independently navigable.

## Visual language

- Light theme is the default for readability, with a dark theme available.
- Blue denotes navigation and informational signals.
- Red, amber, blue, and green distinguish critical, high, medium, and low severity.
- Severity labels include text as well as color for accessibility.
- Use Material 3 components to keep the project easy to extend.
- Keep panels low-contrast, headings clear, and page content centered on wide screens.

## Interaction

- Severity chips filter alerts in place.
- “Mark reviewed” changes only the local demo state; “Reopen” reverses it.
- The theme can be changed from Settings or the top bar.
- There are no destructive or external side-effecting controls.
- Investigation records are not preloaded and disappear when the process ends.
- Graph association is explicit and separate from evidence creation; the graph fixtures remain synthetic.
- Hypotheses, assessments, decisions, ATT&CK proposals, and their provenance remain visibly distinct. Acceptance is not confirmation.

## Content rules

- The top bar and notice clearly label the data as demo data.
- Risk score details are illustrative, not a validated detection model.
- Sample IP addresses use documentation-only address space.
- No charts use image assets; the page remains self-contained and runnable.
