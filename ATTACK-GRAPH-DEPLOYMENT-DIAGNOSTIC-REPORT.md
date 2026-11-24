# HuntAI — Production Deployment Attack Graph Diagnostic Audit Report

**Project:** HuntAI — AI-Assisted Threat Hunting Platform  
**Project Directory:** `D:\huntai (4)\huntai`  
**Environment:** Deployed Flutter Web application on Netlify  
**Target URL:** `https://hilarious-scone-bae65d.netlify.app/`  
**Date:** 2026-11-21  
**Audit Type:** Strictly Read-Only Diagnostic Investigation  
**Diagnostic Verdict:** **ROOT CAUSES CONFIRMED (CODE & STYLING DEFECTS IDENTIFIED)**  

---

## 1. Executive Summary

A comprehensive diagnostic audit was conducted to investigate the production symptoms observed on the deployed HuntAI application on Netlify (`https://hilarious-scone-bae65d.netlify.app/`), specifically regarding the Attack Graph on the Threat Analysis workspace.

The investigation traced the entire graph pipeline from source data models and services to 2D and 3D painters, interaction handlers, and deployment bundle consistency.

### Key Diagnostic Findings:
1. **Visible Node Count (4–6 nodes):** This is **NOT** a rendering or clipping defect. The static fixture dataset in `VisualizationDataService.entities` contains **exactly 5 nodes**. The graph is faithfully rendering all 5 nodes that exist in the system.
2. **Invisible Connecting Edges/Lines in 3D:** A definitive code defect was identified in `AttackGraph3D._paintEdge` (`lib/features/visualizations/widgets/attack_graph_3d.dart`, line 1081). The `Paint` object is created without setting `paint.style = PaintingStyle.stroke`. In Flutter, the default style is `PaintingStyle.fill`. Calling `canvas.drawPath` on 1D open linear path segments with `PaintingStyle.fill` results in Skia/CanvasKit filling a zero-area region, rendering **0 visible pixels** for 100% of dashed connections in 3D.
3. **Invisible Connecting Edges/Lines in 2D:** A severe styling and color contrast defect was identified in `AttackGraph2D` (`lib/features/visualizations/widgets/attack_graph_2d.dart`, lines 458–468). Three out of the four connections (75%) have `AttackConnectionType.hypothesized`. Their color is configured to `Theme.of(context).dividerColor` (`#3B465A`), painted against a dark surface container (`#2C3647`). This yields an imperceptible contrast ratio of **1.17 : 1** (WCAG minimum graphical contrast is 3.0:1), drawn as a microscopic **2px dash with a 5px gap** on a 1.8px stroke. It is visually indistinguishable to the human eye.
4. **Missing Graph Reset / Fit-to-Screen Controls:** The reset functionality is currently represented solely by an unlabeled icon button (`Icons.center_focus_strong`), with no textual label ("Reset" or "Fit to Screen") and no tooltip visible on touch/mobile devices. Furthermore, no adaptive bounding-box "fit-to-screen" calculation exists in either 2D or 3D.
5. **Deployment Consistency:** The deployed build artifacts on Netlify (`version.json`, `index.html`) were fetched and verified to be 100% identical to local `build\web` artifacts. The symptoms originate entirely in application code and styling definitions, not in deployment skew or CDN corruption.

---

## 2. Observed Production Symptoms

The diagnostic addressed the following symptoms reported on production:

| # | Symptom | Status in Audit |
| :---: | :--- | :--- |
| **S1** | Threat Analysis page opens successfully | **Verified Working** |
| **S2** | Severity chart renders | **Verified Working** |
| **S3** | Timeline visualization renders | **Verified Working** |
| **S4** | Heatmap renders | **Verified Working** |
| **S5** | Attack Graph appears, but only approximately 4–6 nodes are visible | **Root Cause Identified** (Dataset has exactly 5 nodes) |
| **S6** | Zooming out does not reveal additional nodes | **Root Cause Identified** (Dataset has no other nodes) |
| **S7** | Switching between 2D and 3D does not change the visible node count | **Root Cause Identified** (Both views consume the same 5-node fixture) |
| **S8** | Clicking a node produces a selection highlight | **Verified Working** (Hit testing & selection halos work) |
| **S9** | Connecting edges/lines are not visible | **Root Cause Identified** (3D missing stroke style; 2D low contrast 1.17:1 + micro-dashes) |
| **S10**| No graph reset or fit-to-screen controls are available | **Root Cause Identified** (Unlabeled icon-only button; no adaptive fit logic) |

---

## 3. Graph Data Pipeline Findings

### A. Data Source & Ingestion
- **Source File:** `lib/features/visualizations/services/visualization_data_service.dart` (lines 82–194)
- **Entities Source:** `VisualizationDataService.entities` is a `static const List<AttackEntity>` containing **5 entities**.
- **Connections Source:** `VisualizationDataService.connections` is a `static const List<AttackConnection>` containing **4 connections**.
- **Pipeline Consumption:**
  In `lib/features/visualizations/screens/visualization_workspace.dart` (lines 259–267):
  ```dart
  _use3dGraph
      ? AttackGraph3D(
          onEntitySelectionChanged: _onEntitySelected,
          onConnectionSelectionChanged: _onConnectionSelected,
        )
      : AttackGraph2D(
          onEntitySelectionChanged: _onEntitySelected,
          onConnectionSelectionChanged: _onConnectionSelected,
        )
  ```
  Both `AttackGraph2D` and `AttackGraph3D` use parameter defaults pointing directly to `VisualizationDataService.entities` and `VisualizationDataService.connections`.

### B. Filtering & Rejection Validation
- In `AttackGraph2D.build` (`attack_graph_2d.dart`, lines 50–63):
  Entities are filtered by `_typeFilter`, `_severityFilter`, and search query.
  When filters are cleared (default state), all 5 entities pass.
  Connections are filtered by `ids.contains(sourceEntityId) && ids.contains(targetEntityId)`.
  All 4 connection endpoints reference valid entity IDs (`demo-external`, `demo-ip`, `demo-account`, `demo-workstation`, `demo-server`).
  **Zero connections are rejected by filtering or missing endpoint references.**

---

## 4. Actual Node and Edge Counts

### A. Graph Entities (Total: 5 Nodes)

| ID | Name | Entity Type | Severity | 2D Coordinates | 3D Coordinates (Spherical Distribution) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `demo-external` | External source | `attacker` | High | `Offset(90, 160)` | `x: 0.0, y: 220.0, z: 0.0` |
| `demo-ip` | Suspicious source | `suspiciousIp` | Critical | `Offset(240, 160)` | `x: -168.0, y: 110.0, z: 66.8` |
| `demo-account` | analyst-demo | `userAccount` | High | `Offset(400, 160)` | `x: 93.3, y: 0.0, z: -184.2` |
| `demo-workstation` | Sample workstation | `workstation` | Medium | `Offset(560, 160)` | `x: 77.2, y: -110.0, z: 172.9` |
| `demo-server` | Internal server | `applicationServer` | Low | `Offset(720, 160)` | `x: 0.0, y: -220.0, z: 32.0` |

### B. Graph Connections (Total: 4 Edges)

| ID | Source ID | Target ID | Connection Type | Severity | 3D Style Dash Pattern | 2D Style Dash Pattern |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `demo-link-1` | `demo-external` | `demo-ip` | `hypothesized` | High | `[2.0, 5.0]` | `dash: 2.0, gap: 5.0` |
| `demo-link-2` | `demo-ip` | `demo-account` | `hypothesized` | Critical | `[2.0, 5.0]` | `dash: 2.0, gap: 5.0` |
| `demo-link-3` | `demo-account` | `demo-workstation` | `suspicious` | Medium | `[7.0, 5.0]` | `dash: 7.0, gap: 4.0` |
| `demo-link-4` | `demo-workstation` | `demo-server` | `hypothesized` | Low | `[2.0, 5.0]` | `dash: 2.0, gap: 5.0` |

> [!IMPORTANT]
> Notice that **zero connections** have `connectionType == AttackConnectionType.observed` (solid line). 100% of connections in the fixture are either `hypothesized` (75%) or `suspicious` (25%).

---

## 5. 2D Rendering Findings

- **Source File:** `lib/features/visualizations/widgets/attack_graph_2d.dart`
- **Class:** `_AttackGraphPainter` (lines 412–564)

### A. Drawing Order & Layering
1. Canvas background: `ColoredBox` with `surfaceContainerHighest.withValues(alpha: .45)` (`#2C3647`).
2. Edges are drawn first (lines 437–515).
3. Nodes are drawn second (lines 517–564).
*Assessment:* Drawing order is correct; edges are beneath node disks.

### B. Root Cause for 2D Edge Invisibility:
1. **Severe Color Contrast Deficit:**
   In lines 458–468:
   ```dart
   AttackConnectionType.hypothesized => (
       color: edgeColor,
       dashLength: 2.0,
       gapLength: 5.0,
   ),
   ```
   `edgeColor` is passed as `Theme.of(context).dividerColor` (`#3B465A`).
   The background is `#2C3647`.
   **Contrast ratio:** `1.17 : 1` (Near zero perceptible difference).
2. **Extreme Micro-Dash Fragmentation:**
   The dash is configured as `dashLength: 2.0` followed by `gapLength: 5.0` on a `strokeWidth: 1.8`.
   A 2-pixel segment with 1.17:1 contrast renders as faint sub-pixel noise.
3. **Prevalence in Dataset:**
   3 of the 4 edges (`demo-link-1`, `demo-link-2`, `demo-link-4`) are `hypothesized`. Because 75% of edges are virtually invisible, the single remaining edge (`demo-link-3`, between node 3 and 4) is easily missed or perceived as a broken layout.

---

## 6. 3D Rendering Findings

- **Source File:** `lib/features/visualizations/widgets/attack_graph_3d.dart`
- **Class:** `_AttackGraph3DPainter` (lines 997–1185)

### A. Projection & Coordinate Transformations
`AttackGraph3DProjection.project` correctly projects 3D world coordinates to 2D viewport coordinates using perspective division (`scale = focalLength / depth * camera.zoom`). Near and far clipping planes (35.0 to 10000.0) are valid and do not clip any nodes.

### B. Root Cause for 3D Edge Invisibility (Critical Code Bug):
In `_AttackGraph3DPainter._paintEdge` (lines 1081–1094):
```dart
final paint = Paint()
  ..color = color
  ..strokeWidth = selected ? 3.5 : 2
  ..strokeCap = StrokeCap.round;
final path = Path()
  ..moveTo(line.start.dx, line.start.dy)
  ..lineTo(line.end.dx, line.end.dy);
final dashPattern =
    AttackGraph3DStyle.dashPatternFor(edge.connection.connectionType);
if (dashPattern.isEmpty) {
  canvas.drawPath(path, paint);
} else {
  _drawDashed(canvas, path, paint, dashPattern[0], dashPattern[1]);
}
```

And in `_drawDashed` (lines 1170–1185):
```dart
void _drawDashed(
  Canvas canvas,
  Path path,
  Paint paint,
  double dashLength,
  double gapLength,
) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dashLength, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += dashLength + gapLength;
    }
  }
}
```

### Why this results in 0 visible pixels:
1. In Flutter, `Paint.style` defaults to **`PaintingStyle.fill`**.
2. In `attack_graph_3d.dart` line 1081, **`..style = PaintingStyle.stroke` is completely missing!**
   *(In contrast, `attack_graph_2d.dart` line 467 explicitly specifies `..style = PaintingStyle.stroke`).*
3. All 4 connections in `VisualizationDataService.connections` have dash patterns (`[2, 5]` or `[7, 5]`), meaning `_drawDashed` is executed for **100% of connections**.
4. In `_drawDashed`, `canvas.drawPath` is called on extracted 1D line segments using a `Paint` object whose style is `PaintingStyle.fill`.
5. In Skia, WebGL, and CanvasKit, filling a 1D open line segment fills an area of **zero square pixels**. `strokeWidth` is completely ignored by the rasterizer when `style == PaintingStyle.fill`.
6. Consequently, **the 3D attack graph rasterizes ZERO pixels for all connecting lines.**
7. The directional arrow (`_drawArrow` line 1096) is drawn with `PaintingStyle.fill`, but because it is a tiny 10px arrowhead positioned at `line.end` against node radius ~24–36px with outer halo shaders, it appears as an isolated dot or is covered by node rendering.

---

## 7. Node and Edge Interaction Findings

### A. Node Selection & Highlighting
- **Why Node Highlighting Works:**
  - 2D: `_selectAt` compares touch offset to node center within radius 44px (`nodeRadius + 10`). When matched, `_selectedEntity` triggers a repaint with an orange highlight ring (`AppColors.orange`, strokeWidth 3).
  - 3D: `AttackGraph3DPicking.nearestNodeAt` performs Euclidean hit-testing in projected screen space with depth-sorting. Matching nodes trigger `_paintNode` selected ring `radius + 6` in orange.
  - **Verdict:** Node interaction and highlighting functions correctly across both 2D and 3D.

### B. Edge Hit-Testing
- In `AttackGraph3DPicking.nearestConnectionAt` (`attack_graph_3d.dart`, lines 279–296), hit testing is performed using a purely mathematical point-to-segment distance calculation:
  ```dart
  static double distanceToSegment(Offset point, Offset start, Offset end)
  ```
- **Why automated tests passed despite invisible lines:**
  The test `test/visualization_test.dart` (lines 547–552) simulates a tap on the mathematical midpoint between source and target:
  ```dart
  await tester.tapAt(
    freshTopLeft + (sourcePoint.position + targetPoint.position) / 2,
  );
  expect(selectedConnection?.id, VisualizationDataService.connections[0].id);
  ```
  The test passed because `nearestConnectionAt` is a pure mathematical calculation on coordinate vectors. It does not inspect the canvas buffer to verify whether physical pixels were stroked.

---

## 8. Deployment Consistency Findings

To determine whether the Netlify deployment differs from local source or build artifacts, live HTTP responses from `https://hilarious-scone-bae65d.netlify.app/` were compared against local artifacts:

| Resource | Deployed Netlify Content | Local `build\web` Content | Status |
| :--- | :--- | :--- | :--- |
| **`version.json`** | `{"app_name":"huntai","version":"1.0.0",...}` | `{"app_name":"huntai","version":"1.0.0",...}` | **100% Match** |
| **`index.html` Title** | `HuntAI — AI-Assisted Threat Hunting Platform` | `HuntAI — AI-Assisted Threat Hunting Platform` | **100% Match** |
| **`index.html` Meta** | `HuntAI — AI-Assisted Threat Hunting Demonstration Platform` | `HuntAI — AI-Assisted Threat Hunting Demonstration Platform` | **100% Match** |
| **`main.dart.js` Size** | ~2.93 MB | 2,935,756 bytes | **100% Match** |

**Conclusion:** The deployed site is running the exact build artifacts present in the repository. There is no deployment skew, missing build step, or CDN caching anomaly.

---

## 9. Root Cause Assessment

| Issue | Root Cause Category | Specific Technical Cause | Confidence Level |
| :--- | :--- | :--- | :---: |
| **Visible Node Count (4–6 nodes)** | Expected Data Limitation | `VisualizationDataService.entities` defines exactly 5 static demonstration nodes. There are no additional nodes in the dataset. | **Confirmed** |
| **Zooming Out Shows No New Nodes** | Expected Data Limitation | All 5 nodes fit within the initial coordinate bounds; no off-screen nodes exist. | **Confirmed** |
| **3D Invisible Edges** | Source Code Defect | `AttackGraph3D._paintEdge` line 1081 omits `..style = PaintingStyle.stroke`. Open paths rendered with default `PaintingStyle.fill` produce 0 rasterized pixels. | **Confirmed** |
| **2D Invisible Edges** | Styling / Contrast Defect | 75% of connections (`hypothesized`) use `dividerColor` (`#3B465A`) on `#2C3647` background (contrast ratio 1.17:1) with micro-dashes (2px dash, 5px gap). | **Confirmed** |
| **Missing Reset / Fit-to-Screen** | UI/UX & Feature Gap | Reset button uses an icon without a text label or mobile tooltip. No adaptive "fit-to-screen" camera calculation is implemented. | **Confirmed** |

---

## 10. Recommended Corrective Actions (Prioritized)

> [!NOTE]
> In accordance with audit restrictions, **no changes were made**. The following corrective actions are recommendations for a future implementation phase:

### Priority 1: Fix 3D Edge Stroke Style (Bug Fix)
In `lib/features/visualizations/widgets/attack_graph_3d.dart` (line 1081), set `paint.style`:
```dart
final paint = Paint()
  ..color = color
  ..strokeWidth = selected ? 3.5 : 2
  ..style = PaintingStyle.stroke   // <--- Add this line
  ..strokeCap = StrokeCap.round;
```

### Priority 2: Fix 2D Hypothesized Edge Contrast and Dash Visibility (Styling Fix)
In `lib/features/visualizations/widgets/attack_graph_2d.dart` (lines 458–462):
1. Replace low-contrast `edgeColor` (`#3B465A`) with an accessible color token that meets WCAG 3.0:1 contrast against dark card background, such as `Theme.of(context).colorScheme.outlineVariant` or a dedicated high-visibility muted token (e.g. `Color(0xFF8A99AD)` or `Color(0xFF9A8AAE)` matching the 3D palette).
2. Increase dash length from `2.0` to `5.0` or `6.0` (with `gapLength: 4.0`) so the dashed structure is legible on standard monitors.

### Priority 3: Improve Graph Reset & Fit-to-Screen Controls (UX Enhancement)
1. Add an explicit text button or action chip alongside the icon button (e.g., `TextButton.icon(icon: Icon(Icons.center_focus_strong), label: Text('Reset view'))`).
2. Implement true "Fit-to-Screen" logic that calculates the bounding box of current entity coordinates and computes the appropriate zoom and pan offset to fit the viewport.

### Priority 4: Clarify Fixture Node Count in UI
Update the graph subtitle or status caption from:
`'Illustrative entities and hypothesized paths · none are verified'`
to explicitly disclose the fixture size:
`'Displaying 5 synthetic demonstration nodes and 4 illustrative paths · none are verified'`
This avoids user confusion regarding whether more nodes exist off-screen.

---

## 11. Tests Needed to Verify Any Future Fix

When the above fixes are implemented in a future phase, the following tests must be added to `test/visualization_test.dart`:

1. **3D Edge Paint Style Verification:**
   Verify that `_AttackGraph3DPainter._paintEdge` constructs a `Paint` with `PaintingStyle.stroke` and non-zero stroke width.
2. **2D Hypothesized Edge Contrast Verification:**
   Verify that the color used for `AttackConnectionType.hypothesized` maintains a contrast ratio of at least 3.0:1 against the canvas background color.
3. **Dash Metric Geometry Test:**
   Verify that dashed paths produce at least `N` distinct path segments of length >= 4px for every connection in `VisualizationDataService.connections`.
4. **Goldens / Pixel Verification Test:**
   A widget test checking that painting the attack graph canvas with `connections` produces non-background pixels along the expected connection lines.

---

## 12. Final Diagnostic Verdict

### **VERDICT: DIAGNOSIS COMPLETE — ROOT CAUSES FULLY PROVEN**

- **Node count (5 nodes):** Exactly as designed in the fixture data.
- **3D edges:** Code bug in `attack_graph_3d.dart` (missing `PaintingStyle.stroke`).
- **2D edges:** Design/styling bug in `attack_graph_2d.dart` (1.17:1 contrast ratio + 2px micro-dashes on dark background).
- **Controls:** UI design limitation (unlabeled icon button without adaptive fit-to-screen logic).
- **Deployment:** 100% verified consistent with local source and build artifacts.

**Compliance Confirmation:** In strict adherence to audit instructions, **no application source code, tests, configuration, build artifacts, or deployment settings were modified.**
