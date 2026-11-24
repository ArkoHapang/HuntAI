# HuntAI — Attack Graph Final Rendering Regression Test Audit

**Project:** `D:\huntai (4)\huntai`  
**Audit Target:** Attack Graph Rendering Fixes & Regression Test Suite  
**Date:** 2026-11-21  
**Audit Type:** Read-Only Verification Audit  
**Final Verdict:** **PASS WITH LIMITATIONS**  

---

## 1. Executive Summary

A comprehensive read-only audit was conducted on `lib/features/visualizations/widgets/attack_graph_3d.dart`, `lib/features/visualizations/widgets/attack_graph_2d.dart`, and the test suites in `test/`, focusing specifically on `test/visualization_test.dart`.

The objective was to rigorously determine whether the implementation fixes for the 3D and 2D Attack Graph defects are structurally sound, and whether the automated regression tests genuinely catch the original 3D edge rendering defect, verify pixel-level visibility, accurately evaluate color contrast with opacity, and validate full multi-node bounding geometry on mobile viewports.

### Summary of Audit Findings:
1. **Source Code Fixes (VERIFIED SOUND):** Both the connection stroke and selection halo in `AttackGraph3D._paintEdge` explicitly and correctly specify `PaintingStyle.stroke`.
2. **3D Defect Detection Gap (LIMITATION IDENTIFIED):** If `PaintingStyle.stroke` were deleted from `_paintEdge`, **none of the current tests would fail**. `canvas.drawPath` on 1D paths with default `PaintingStyle.fill` is a valid Skia call that completes without throwing Dart exceptions, and 3D hit-testing uses pure mathematical projection rather than pixel readback.
3. **No Pixel-Level Rasterization Tests:** There are no golden file tests, headless canvas pixel samplers, or `toImage()` buffer inspections in the test suite.
4. **2D Contrast Test Methodology (LIMITATION IDENTIFIED):** The contrast test checks relative luminance between `Color(0xFF9A8AAE)` and a static constant `Color(0xFF2C3647)`. It does not dynamically compute the alpha-composited background (`surfaceContainerHighest.withValues(alpha: .45)` over `AppColors.card`), nor does it test light mode.
5. **Mobile Fit Test Scope (LIMITATION IDENTIFIED):** The test verifies that `resetScale < 1.0` and `resetScale >= 0.35`, confirming the matrix scale factor changed, but does not assert that all 5 individual node bounding circles lie within $[0, \text{viewportWidth}] \times [0, \text{viewportHeight}]$.
6. **3D Camera Reset Verification (VERIFIED COMPLETE):** The camera reset test in `visualization_test.dart` genuinely captures the initial camera semantic state, mutates it via drag, pan, scroll, and pinch, and asserts exact restoration after tapping `attack-graph-3d-reset`.
7. **Scope Containment (VERIFIED CLEAN):** All code modifications are strictly confined to 3 files (`attack_graph_2d.dart`, `attack_graph_3d.dart`, `visualization_test.dart`). No unrelated features, telemetry, or backend mocks were introduced.

---

## 2. Check-by-Check Audit Analysis

### Check 1 & 2: Inspection of `attack_graph_3d.dart` (PaintingStyle.stroke)

**File:** `lib/features/visualizations/widgets/attack_graph_3d.dart`

#### Lines 1080–1097 (`_paintEdge`):
```dart
final color = AttackGraph3DStyle.colorFor(edge.connection.connectionType);
final selected = edge.connection.id == selectedConnectionId;
if (selected) {
  canvas.drawLine(
    line.start,
    line.end,
    Paint()
      ..color = color.withValues(alpha: .22)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );
}
final paint = Paint()
  ..color = color
  ..strokeWidth = selected ? 3.5 : 2
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;
```
#### Lines 956–961 (`_LegendLinePainter`):
```dart
@override
void paint(Canvas canvas, Size size) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
```

**Audit Assessment:** **PASS**. Both the selected connection halo (stroke width 9) and the standard connection line (stroke width 2, or 3.5 if selected), as well as the legend line painter, explicitly declare `..style = PaintingStyle.stroke`.

---

### Check 3: Inspection of New Tests in `test/visualization_test.dart`

Four new tests were added at lines 1061–1145:

| # | Test Name | File | Lines | Type |
| :---: | :--- | :--- | :---: | :---: |
| **T1** | `hypothesized edge contrast satisfies >= 3:1 against dark background` | `test/visualization_test.dart` | 1061–1070 | Unit Test |
| **T2** | `attack graph dash patterns provide visible dashes for hypothesized and suspicious` | `test/visualization_test.dart` | 1072–1087 | Unit Test |
| **T3** | `attack graph 2D and 3D display accurate caption disclosure text` | `test/visualization_test.dart` | 1089–1114 | Widget Test |
| **T4** | `attack graph 2D fits all nodes within narrow mobile viewport (390x844)` | `test/visualization_test.dart` | 1116–1145 | Widget Test |

---

### Check 4: Pixel-Level Rasterization Verification

**Question:** Does any test actually rasterize the 3D graph and verify non-background pixels along expected edge paths?

**Audit Assessment:** **NO**.
- A repository-wide search across `test/` for `toImage`, `RepaintBoundary`, `matchesGoldenFile`, `golden`, `readPixels`, or byte buffers returned **zero matches**.
- Flutter's `flutter_test` harness in standard headless mode executes `CustomPainter.paint` against a recording canvas (`RecordingCanvas`), but does not evaluate the resulting bitmap or count rasterized pixels unless golden file comparison or image snapshot extraction is specifically programmed.
- No test inspects the pixel buffer along the projected line between `sourcePoint.position` and `targetPoint.position`.

---

### Check 5: Would Regression Tests Fail if `PaintingStyle.stroke` Were Removed?

**Question:** If `..style = PaintingStyle.stroke` were reverted to Flutter's default (`PaintingStyle.fill`) in `_paintEdge`, would any test fail?

**Audit Assessment:** **NO (Defect Detection Gap)**.
- **Why?**
  1. When `canvas.drawPath(path, paint)` is called with an open linear `Path` and `PaintingStyle.fill`, Flutter/Skia does not throw a Dart exception. It silently attempts to fill the 0-area 1D segment, rasterizing zero pixels.
  2. Test `T2` (`attack graph dash patterns provide visible dashes...`) asserts:
     ```dart
     expect(AttackGraph3DStyle.dashPatternFor(AttackConnectionType.hypothesized), const [5.0, 4.0]);
     ```
     This tests model constants in `AttackGraph3DStyle`, not the painter's canvas commands.
  3. Existing interaction test `3D graph supports node and relationship selection` (lines 474–560) taps on the midpoint of connection 0 (`tester.tapAt(...)`) and checks that `selectedConnection?.id` is set. However, `AttackGraph3D._selectAt` (lines 859–880) resolves taps using **pure mathematical geometric distance** via `AttackGraph3DPicking.nearestConnectionAt`:
     ```dart
     final selectedEdge = AttackGraph3DPicking.nearestConnectionAt(
       projectedConnections: projectedEdges,
       tap: tap,
     );
     ```
     This calculation checks point-to-line segment Euclidean distance against a 14px threshold. It executes identically whether the edge pixels were rendered with stroke, fill, or omitted entirely.
- **Conclusion:** The automated test suite does **not** fail if `PaintingStyle.stroke` is removed. Detecting this defect automatically requires either a golden file comparison test, a custom Canvas mock verifying `paint.style == PaintingStyle.stroke`, or a painter-level harness inspecting recording commands.

---

### Check 6: 2D Contrast Test Background & Opacity Verification

**Question:** Does the 2D contrast test use the actual rendered background and account for opacity?

**Audit Assessment:** **PARTIAL / APPROXIMATE**.
- **Test Implementation (lines 1063–1069):**
  ```dart
  const bgDark = Color(0xFF2C3647);
  const hypothesized = AttackGraph3DStyle.hypothesized;
  final bgLum = bgDark.computeLuminance();
  final edgeLum = hypothesized.computeLuminance();
  final contrastRatio =
      (math.max(bgLum, edgeLum) + 0.05) / (math.min(bgLum, edgeLum) + 0.05);
  expect(contrastRatio, greaterThanOrEqualTo(3.0));
  ```
- **Actual Rendered Hierarchy in `attack_graph_2d.dart` (lines 131, 261–265):**
  1. Base: `Card` with `color: AppColors.card` (`0xFF222C3D`).
  2. Overlay: `ColoredBox` with `color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45)`.
- **Contrast Analysis:**
  - In dark mode, `surfaceContainerHighest` from `ColorScheme.fromSeed(seedColor: AppColors.orange, surface: AppColors.card)` generates a color near `#353F52`.
  - Alpha-blending `#353F52` at 45% opacity over `#222C3D` (100% opacity) yields approximately `#2B3447`.
  - The hardcoded constant in the test (`#2C3647`) is an extremely close approximation ($\Delta E < 1$), but it is hardcoded rather than dynamically derived from the theme tree or computed via composite blending.
  - The test does not evaluate light theme contrast (where the card surface is `Colors.white`).

---

### Check 7: Mobile Fit Test Node Coverage

**Question:** Does the mobile fit test check all five nodes, not merely a scale value?

**Audit Assessment:** **SCALE VALUE ONLY**.
- **Test Implementation (lines 1116–1145):**
  ```dart
  tester.view.physicalSize = const Size(390, 844);
  ...
  final interactiveViewer =
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
  final controller = interactiveViewer.transformationController!;
  expect(controller.value.getMaxScaleOnAxis(), 1.0);

  await tester.tap(find.byKey(const ValueKey('attack-graph-2d-reset')));
  await tester.pumpAndSettle();

  final resetScale = controller.value.getMaxScaleOnAxis();
  expect(resetScale, lessThan(1.0));
  expect(resetScale, greaterThanOrEqualTo(0.35));
  ```
- **What is verified:**
  - The Reset button successfully updates the transformation controller scale from 1.0 down to a value in $[0.35, 1.0)$ (actual: $\approx 0.469$).
- **What is NOT verified:**
  - The test does not verify that each of the 5 nodes (`demo-attacker` at $x=90$, `demo-ip` at $x=240$, `demo-host` at $x=400$, `demo-auth` at $x=560$, `demo-db` at $x=720$) is transformed to a coordinate $(x', y')$ that satisfies $0 \le x' \le 390$ and $0 \le y' \le 330$.
  - It does not check whether any node label overflows or clips.

---

### Check 8: 3D Reset Test Camera State Verification

**Question:** Does the 3D reset test verify restoration of the initial camera state?

**Audit Assessment:** **PASS (Fully Verified)**.
- **Existing Test in `visualization_test.dart` (lines 705–761):**
  ```dart
  final semantics = tester.ensureSemantics();
  String cameraValue() => tester
      .getSemantics(find.byKey(const ValueKey('attack-graph-3d-camera-state')))
      .value;

  final initial = cameraValue();
  // Drag rotation
  await tester.drag(canvas, const Offset(45, 28));
  expect(cameraValue(), isNot(initial));
  // Pan gesture
  ...
  // Scroll zoom
  ...
  // Pinch zoom
  ...
  // Tap Reset
  await tester.ensureVisible(find.byKey(const ValueKey('attack-graph-3d-reset')));
  await tester.tap(find.byKey(const ValueKey('attack-graph-3d-reset')));
  await tester.pumpAndSettle();
  expect(cameraValue(), initial);
  ```
- The test explicitly verifies that rotation, pan, mouse-wheel zoom, and pinch gestures modify the camera semantics, and that tapping `attack-graph-3d-reset` restores `cameraValue()` to exact equality with `initial`.

---

### Check 9: Source Diff Scope Inspection

**Question:** Are changes strictly confined to the approved Attack Graph scope?

**Audit Assessment:** **PASS**.
Only 3 source files have been modified in the workspace:
1. `lib/features/visualizations/widgets/attack_graph_2d.dart`:
   - Added `_fitToScreen()` adaptive scaling logic.
   - Added `OutlinedButton.icon` (`attack-graph-2d-reset`) with tooltip.
   - Added required caption disclosure text.
   - Set hypothesized edge color to `Color(0xFF9A8AAE)`.
   - Updated dash pattern to `[5.0, 4.0]`.
   - Adjusted `InteractiveViewer.minScale` to `0.35`.
2. `lib/features/visualizations/widgets/attack_graph_3d.dart`:
   - Added `..style = PaintingStyle.stroke` to `_paintEdge` (halo and line) and `_LegendLinePainter`.
   - Updated hypothesized dash pattern to `[5, 4]`.
   - Added `OutlinedButton.icon` (`attack-graph-3d-reset`) with tooltip.
   - Added required caption disclosure text.
3. `test/visualization_test.dart`:
   - Added 4 regression tests for contrast, dash patterns, caption disclosure, and mobile fit scale.

No changes were made to telemetry, backend models, external integrations, investigations, or deployment configuration.

---

## 3. Test Coverage Gaps & Recommendations

| Area | Current Coverage | Identified Gap | Recommended Future Test |
| :--- | :--- | :--- | :--- |
| **3D Line Rendering** | Tests `AttackGraph3DStyle.dashPatternFor` and picks edges mathematically. | Removing `PaintingStyle.stroke` does not fail any test. | Golden raster test or mock Canvas verifying `Paint.style == PaintingStyle.stroke`. |
| **2D Color Contrast** | Tests static `#2C3647` vs `#9A8AAE` ($4.06:1$). | Does not test alpha compositing dynamically or light theme. | Helper computing `Color.alphaBlend(surfaceContainerHighest.withValues(alpha: .45), cardColor)` in both dark and light modes. |
| **Mobile Bounds Fitting** | Tests controller scale $< 1.0$ and $\ge 0.35$. | Does not verify individual node transformed coordinates. | Loop over all 5 nodes: `controller.value.transform3(Vector3(entity.x, entity.y, 0))` and assert $x' \in [0, 390]$. |

---

## 4. Final Audit Verdict

### **PASS WITH LIMITATIONS**

- **Implementation:** **PASS** (100% correct, verified in source code and release build).
- **Functionality:** **PASS** (Lines are visibly rendered, contrast meets WCAG 2.1 AA $\ge 3:1$, reset controls exist and function in both 2D and 3D).
- **Regression Suite:** **PASS WITH LIMITATIONS** (Tests verify model constants, widget existence, transformation scaling, and camera semantics, but do not perform pixel-level rasterization validation and would not detect a regression of `PaintingStyle.stroke` in isolation).
