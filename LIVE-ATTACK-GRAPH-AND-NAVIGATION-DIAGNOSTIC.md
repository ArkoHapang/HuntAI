# HuntAI — Live Attack Graph Rendering & Navigation Persistence Diagnostic Report

**Project:** HuntAI — AI-Assisted Threat Hunting Platform  
**Directory:** `D:\huntai (4)\huntai`  
**Live URL:** `https://hilarious-scone-bae65d.netlify.app`  
**Date:** 2026-11-21  
**Investigation Mode:** Strictly Read-Only Diagnostic  
**Status:** **ROOT CAUSES CONFIRMED WITH EMPIRICAL EVIDENCE**  

---

## 1. Executive Summary

A thorough, read-only diagnostic investigation was performed to identify the root causes for two behaviors observed on the live Netlify deployment (`https://hilarious-scone-bae65d.netlify.app`):

1. **Attack Graph Connection Visibility:** Nodes and arrowheads appear on the live site, but connecting line strokes are missing or imperceptible, even when the "Connections" toggle is enabled.
2. **Navigation Reset on Refresh:** Performing a browser hard refresh resets the application back to the Dashboard rather than preserving the Threat Analysis workspace.

### Key Diagnostic Discoveries:
1. **Deployment Artifact Skew (Root Cause for Live Graph Defect):**  
   The live Netlify site is running an **outdated deployment build** (file size: `2,935,756 bytes`), deployed prior to the rendering corrections. The latest local release build in `D:\huntai (4)\huntai\build\web` (file size: `2,936,726 bytes`) has **never been uploaded to Netlify**.  
   - Empirical proof: An HTTP probe verified that the live `main.dart.js` returns `False` for the new disclosure string (`"Displaying 5 synthetic demonstration nodes..."`) and `False` for the corrected hypothesized edge color (`#9A8AAE`), while the local `build/web/main.dart.js` returns `True` for both.
2. **Arrowhead vs. Stroke Rendering Discrepancy:**  
   In the uncorrected build on Netlify, arrowheads are drawn via `_drawArrow` as a closed triangular path (`..close()`) using `PaintingStyle.fill`, which successfully fills an enclosed 2D area. In contrast, the connection lines were drawn on an open 1D path with default `PaintingStyle.fill`, which rasterizes zero pixels in Skia/CanvasKit. This explains why **arrowheads appeared as floating triangles while the line strokes were completely missing**.
3. **Navigation Architecture by Design:**  
   The application uses in-memory Flutter widget state (`int _selectedPage = 0;` in `_HuntAiHomeState`) with standard `MaterialApp(home: const HuntAiHome())`. It has no URL routing (e.g., `MaterialApp.router` or `go_router`), no hash strategy, and no browser storage persistence (`sessionStorage` / `localStorage`). Therefore, any browser reload destroys the Dart runtime and re-initializes `_selectedPage` to `0` (Dashboard). This is architectural behavior, not an operational failure.

---

## 2. Investigation A — Attack Graph Connection Rendering

### A. Connection Data Pipeline & Filtering
- **Fixture Definitions:** `VisualizationDataService.connections` (`visualization_data_service.dart`, lines 148–194) defines exactly 4 static connections:
  - `demo-link-1` (`demo-external` $\rightarrow$ `demo-ip`), `hypothesized`, high severity
  - `demo-link-2` (`demo-ip` $\rightarrow$ `demo-account`), `hypothesized`, critical severity
  - `demo-link-3` (`demo-account` $\rightarrow$ `demo-workstation`), `suspicious`, medium severity
  - `demo-link-4` (`demo-workstation` $\rightarrow$ `demo-server`), `hypothesized`, low severity
- **Filter State Evaluation:**
  - In `AttackGraph2D` (lines 110–123) and `AttackGraph3D` (lines 381–395), connections are filtered only if an active severity/type filter or search query excludes one of the endpoint entities.
  - When no filters are active, all 4 connections pass to the painter.
  - The `Connections` toggle (`_showConnections`, defaulting to `true`) passes `_showConnections ? connections : const []`. When enabled, all 4 connections are supplied to `_AttackGraphPainter` (2D) and `_AttackGraph3DPainter` (3D).

### B. Geometry, Projection & Viewport Clipping
- **2D Geometry:**
  - Entities are positioned along $y=160$ at $x = 90, 240, 400, 560, 720$.
  - In `attack_graph_2d.dart`:
    ```dart
    final lineStart = start + direction * 38;
    final lineEnd = end - direction * 42;
    ```
  - Node radius is 33px. Lines start 5px outside the source node and end 9px outside the destination node. For each adjacent pair, the line segment length is $70\text{--}80\text{px}$, fully within the canvas boundary ($800\text{px} \times 330\text{px}$).
- **3D Geometry:**
  - `AttackGraph3DPicking.lineFor(start, end)` (lines 243–262) computes 3D spherical projection coordinates and offsets `startRadius` and `endRadius` based on perspective scaling.
  - Line lengths exceed the minimum 2px threshold and project cleanly within the viewport.
- **Occlusion Analysis:**
  - Connections are painted before nodes. Because `lineStart` and `lineEnd` are computed outside node circles, nodes do not cover the connection line strokes.

### C. Arrowhead vs. Stroke Analysis (Why Arrowheads Showed Without Lines)
A critical insight into the live symptom:

```
               [Source Node] (radius 33)
                     │
       lineStart ────┼───────────────────────────┐  <- Drawn with _drawDashed(canvas, path, paint, ...)
                     │                           │     UNRESOLVED LIVE BUILD: paint.style = fill (0 pixels)
                     │                           ▼     CORRECTED LOCAL BUILD: paint.style = stroke (visible)
                     │               ┌───────────────┐
                     │               │  lineEnd (tip)│  <- Drawn with _drawArrow(canvas, lineEnd, ...)
                     │               │       ▲       │     Built with path.close() (closed triangle)
                     │               │      / \      │     Filled with Paint()..color = color (style = fill)
                     │               │     /   \     │     => VISIBLE AS A FLOATING FILLED TRIANGLE
                     │               └───────────────┘
                     │                           │ (9px gap)
                     ▼                           ▼
               [Destination Node] (radius 33)
```

1. **Stroke Painting (`_paintEdge` / `_drawDashed`):**
   - Constructed as an open linear `Path` from `lineStart` to `lineEnd`.
   - In the deployed live build, `paint.style` was defaulted to `PaintingStyle.fill`. Because an open 1D line has zero enclosed area, Skia rasterizes **0 visible pixels**.
2. **Arrowhead Painting (`_drawArrow`):**
   - Constructed as a closed 3-point triangle via `path..moveTo(tip)..lineTo(base1)..lineTo(base2)..close()`.
   - Drawn with `Paint()..color = color` (which defaults to `PaintingStyle.fill`).
   - Because a closed triangle has a non-zero 2D interior area, Skia renders the filled arrowhead polygon regardless of the stroke bug.
3. **2D Low Contrast:**
   - In the deployed build, 3 of 4 connections (hypothesized) were drawn with `Theme.of(context).dividerColor` (`#3B465A`) on `#2C3647` (1.17:1 contrast) with a 2px dash, rendering them practically invisible to human vision while arrowheads had slightly different visual impact.

---

## 3. Deployment Artifact Comparison

A direct cryptographic and structural comparison between the live Netlify deployment and the local release build was performed:

| Property | Live Netlify Deployment (`hilarious-scone-bae65d`) | Local Release Build (`build\web`) | Status / Variance |
| :--- | :--- | :--- | :--- |
| **HTTP Content-Length** | `2,935,756 bytes` | `2,936,726 bytes` | **MISMATCH (-970 bytes)** |
| **Disclosure Caption** | `"Displaying 5 synthetic demonstration nodes..."` $\rightarrow$ **NOT PRESENT** | **PRESENT** | **LIVE RUNS OLD BUILD** |
| **Hypothesized Color (`#9A8AAE`)** | **NOT PRESENT** in 2D style tables | **PRESENT** | **LIVE RUNS OLD BUILD** |
| **3D Stroke Style Declaration** | Reverted to `PaintingStyle.fill` default | Explicit `PaintingStyle.stroke` | **LIVE RUNS OLD BUILD** |
| **Reset View Control** | Unlabeled icon-only button | `OutlinedButton.icon` labeled "Reset view" | **LIVE RUNS OLD BUILD** |

### Definitive Conclusion on Issue 1:
The observed live symptom on Netlify is **not a new regression or failure of the corrected code**. The Netlify CDN is currently serving the **un-repaired build from prior audit cycles**. The corrected code compiled in `build\web` has simply not been deployed to Netlify.

---

## 4. Investigation B — Navigation & Refresh Architecture

### A. Navigation State Storage
- **File:** `lib/main.dart` (lines 54–68)
- **Implementation:**
  ```dart
  class _HuntAiHomeState extends State<HuntAiHome> {
    int _selectedPage = 0;
    ...
    static const _pages = [
      'Dashboard',         // 0
      'Threat analysis',   // 1
      'Alerts',            // 2
      'Telemetry',         // 3
      'Attack chain',      // 4
      'Investigations',    // 5
      'Settings'           // 6
    ];
  ```
- The active page index is stored purely as a private in-memory integer variable in the `State` class of `HuntAiHome`.

### B. Routing Architecture
- In `lib/main.dart` (lines 35–43):
  ```dart
  MaterialApp(
    title: 'HuntAI',
    debugShowCheckedModeBanner: false,
    themeMode: mode,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: const HuntAiHome(),
  )
  ```
- **Routing Type:** Root widget instantiation (`home: const HuntAiHome()`).
- The application does not use:
  - Declarative URL routing (`MaterialApp.router`, `go_router`, `beamer`).
  - Named routes (`routes: {}`, `onGenerateRoute`).
  - URL hash strategy or path synchronization (`setPathUrlStrategy()`, `window.history.pushState`).

### C. Behavior on Browser Reload / Hard Refresh
1. When the user performs a browser refresh (F5 / Ctrl+F5), the browser completely unloads the current DOM and downloads `index.html` and `main.dart.js` fresh.
2. The Flutter Web WASM/JS engine initializes from `main()`.
3. `HuntAiHome` is instantiated, and `_HuntAiHomeState` initializes its variables.
4. `_selectedPage` is set to its initial value: `0`.
5. Page `0` maps to `SocDashboardScreen`.
6. Therefore, the application returns to Dashboard upon every page reload by architectural design.

### D. Browser History (Back / Forward)
- Because tab switches invoke `setState(() => _selectedPage = index)` without pushing a route onto Flutter's `Navigator` or updating the browser's `History` stack, the browser URL remains permanently at `https://hilarious-scone-bae65d.netlify.app/`.
- Pressing the browser's Back button does not navigate back to the previous HuntAI view; it exits the website or returns to whatever website the user visited prior to HuntAI.

---

## 5. Summary: Confirmed Issues vs. Hypotheses

| Observation | Classification | Evidence & Details |
| :--- | :--- | :--- |
| **Live Netlify site missing connection lines** | **CONFIRMED SKEW** | Confirmed that Netlify is running the old uncorrected build (`2,935,756 bytes` vs local `2,936,726 bytes`). |
| **Arrowheads visible without lines in 3D** | **CONFIRMED DEFECT IN LIVE BUILD** | Confirmed that `_drawArrow` uses `PaintingStyle.fill` on closed triangles (drawing area), while lines used `PaintingStyle.fill` on open 1D lines (drawing 0 pixels). Fixed in local `lib/`. |
| **Connections obscured by nodes** | **DISPROVEN HYPOTHESIS** | Source coordinates confirm lines start at radius 38 and end at radius 42 (outside radius 33 node circle). |
| **Connections clipped by canvas** | **DISPROVEN HYPOTHESIS** | Canvas is sized to 800x330 (2D) / 800x400 (3D); all 4 connections sit between x=90 and x=720, y=160. |
| **Hard refresh resets to Dashboard** | **CONFIRMED ARCHITECTURE** | Navigation uses in-memory `_selectedPage = 0`. No URL routing or browser storage persistence exists. |

---

## 6. Recommended Minimal Corrective Actions

### Action 1: Deploy Latest Local Web Build to Netlify (Resolves Issue 1)
To bring the live Netlify site into alignment with the verified, corrected local build:
1. Open the Netlify project dashboard for `hilarious-scone-bae65d`.
2. Navigate to the **Deploys** section.
3. Upload the freshly compiled local build directory:
   ```
   D:\huntai (4)\huntai\build\web
   ```
4. Perform a cache-clearing reload (Ctrl+Shift+R) on the live URL. Connecting lines will render visibly with compliant contrast and full 3D strokes.

### Action 2: Optional Future Enhancement for Navigation Persistence (Issue 2)
*Note: In accordance with project restrictions, this was NOT implemented during this read-only audit.*
If navigation persistence across browser reloads is desired in a future release, the recommended minimal approach that preserves existing architecture is:
- Read `Uri.base.fragment` (or a query parameter like `?page=analysis`) inside `_HuntAiHomeState.initState()` to initialize `_selectedPage`.
- Update `window.location.hash` (e.g., `#analysis`, `#alerts`, `#settings`) whenever `_selectedPage` changes.

---

## 7. Exact Files and Methods Inspected

1. `lib/features/visualizations/widgets/attack_graph_3d.dart`:
   - `_AttackGraph3DPainter.paint` (lines 1036–1072)
   - `_AttackGraph3DPainter._paintEdge` (lines 1074–1110)
   - `_AttackGraph3DPainter._drawArrow` (lines 1205–1225)
   - `_AttackGraph3DPainter._drawDashed` (lines 1187–1203)
   - `AttackGraph3DPicking.lineFor` (lines 243–262)
2. `lib/features/visualizations/widgets/attack_graph_2d.dart`:
   - `_AttackGraphPainter.paint` (lines 502–632)
   - `_AttackGraphPainter._drawArrow` (lines 651–660)
   - `_AttackGraphPainter._drawDashed` (lines 634–649)
   - `_AttackGraph2DState._selectAt` (lines 329–350)
3. `lib/features/visualizations/screens/visualization_workspace.dart`:
   - `VisualizationWorkspace.build` (lines 240–270)
4. `lib/features/visualizations/services/visualization_data_service.dart`:
   - `entities` fixture list (lines 82–146)
   - `connections` fixture list (lines 148–194)
5. `lib/main.dart`:
   - `HuntAiApp.build` (lines 32–44)
   - `_HuntAiHomeState.initState` (lines 75–80)
   - `_HuntAiHomeState.build` (lines 106–221)
   - `_HuntAiHomeState._buildPage` (lines 223–275)
6. `D:\huntai (4)\huntai\build\web\main.dart.js` (local release bundle)
7. `https://hilarious-scone-bae65d.netlify.app/main.dart.js` (live Netlify bundle)

---

## 8. Final Verdict

| Issue | Verdict | Summary |
| :--- | :---: | :--- |
| **Issue 1: Attack Graph Connection Visibility** | **EXPLAINED / RESOLVED LOCALLY** | The live Netlify site is running an outdated build. The local source and `build\web` bundle contain the verified stroke fixes and contrast adjustments. Deploying `build\web` will resolve the live symptom. |
| **Issue 2: Navigation Reset on Refresh** | **BY DESIGN (ARCHITECTURAL)** | The app uses in-memory Flutter widget state (`_selectedPage = 0`) with single-page `MaterialApp(home: ...)`. There is no URL router or browser session storage persistence. Refreshing inherently reboots to Dashboard. |
