import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/data/demo_data.dart';
import 'package:huntai/features/visualizations/models/attack_connection.dart';
import 'package:huntai/features/visualizations/models/attack_entity.dart';
import 'package:huntai/features/visualizations/models/visualization_data.dart';
import 'package:huntai/features/visualizations/screens/visualization_workspace.dart';
import 'package:huntai/features/visualizations/services/visualization_data_service.dart';
import 'package:huntai/features/visualizations/widgets/attack_graph_2d.dart';
import 'package:huntai/features/visualizations/widgets/attack_graph_3d.dart';
import 'package:huntai/features/visualizations/widgets/attack_entity_details.dart';
import 'package:huntai/features/visualizations/widgets/security_heatmap.dart';
import 'package:huntai/features/visualizations/widgets/threat_activity_chart.dart';
import 'package:huntai/features/visualizations/widgets/threat_severity_chart.dart';
import 'package:huntai/features/visualizations/widgets/visualization_legend.dart';
import 'package:huntai/features/visualizations/widgets/vulnerability_analytics_chart.dart';
import 'package:huntai/main.dart';

void main() {
  test('timeline ranges return labeled synthetic aggregates', () {
    const service = VisualizationDataService();

    expect(service.timeline('1h').length, 3);
    expect(service.timeline('24h').length, 6);
    expect(service.timeline('7d').length, 7);
    expect(service.timeline('30d').length, 12);
    expect(service.timeline('invalid'), isNotEmpty);
    expect(service.timeline('24h').first.label, '00');
  });

  test('severity aggregates use existing sample alerts only', () {
    const service = VisualizationDataService();
    final counts = service.severityCounts(demoAlerts);

    expect(counts[Severity.critical], 1);
    expect(counts[Severity.high], 1);
    expect(counts[Severity.medium], 1);
    expect(counts[Severity.low], 0);
  });

  testWidgets('timeline supports range selection and point inspection',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ThreatActivityChart()),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '1h'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('threat-timeline-plot')));
    await tester.pumpAndSettle();

    expect(find.text('Total 0'), findsNothing);
    expect(find.text('Critical'), findsOneWidget);
    expect(find.textContaining('Total '), findsOneWidget);
  });

  testWidgets('timeline handles loading, empty, and series visibility states',
      (tester) async {
    Widget timeline({required Widget chart}) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: chart)),
        );

    await tester.pumpWidget(
      timeline(chart: const ThreatActivityChart(isLoading: true)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      timeline(
          chart: const ThreatActivityChart(
        service: _EmptyTimelineService(),
      )),
    );
    expect(find.text('No timeline data for this range.'), findsOneWidget);

    await tester.pumpWidget(timeline(chart: const ThreatActivityChart()));
    await tester.ensureVisible(find.text('Critical').first);
    final legend = find.byType(VisualizationLegend);
    expect(
      tester.widget<VisualizationLegend>(legend).selected,
      contains(Severity.critical),
    );
    await tester.tap(find.text('Critical').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<VisualizationLegend>(legend).selected,
      isNot(contains(Severity.critical)),
    );
  });

  testWidgets('heatmap cells show aggregate counts when selected',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SecurityHeatmap()),
        ),
      ),
    );

    const cellTooltip = 'Authentication · 12:00 · 18 events';
    await tester.tap(find.byTooltip(cellTooltip));
    await tester.pumpAndSettle();

    expect(find.textContaining('Authentication · 12:00'), findsOneWidget);
    expect(find.text('Total 18'), findsOneWidget);
    expect(find.textContaining('synthetic aggregates'), findsOneWidget);
  });

  testWidgets('severity doughnut selection reports selected alert category',
      (tester) async {
    Severity? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ThreatSeverityChart(
                selectedSeverity: selected,
                onSeveritySelected: (severity) =>
                    setState(() => selected = severity),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Critical').first);
    await tester.pumpAndSettle();

    expect(selected, Severity.critical);
    expect(find.text('1 · 33%'), findsWidgets);
    expect(find.text('Clear severity filter'), findsOneWidget);
  });

  testWidgets('attack graph node and edge selection show details',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    AttackEntity? selectedEntity;
    AttackConnection? selectedConnection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AttackGraph2D(
              onEntitySelectionChanged: (entity) => selectedEntity = entity,
              onConnectionSelectionChanged: (connection) =>
                  selectedConnection = connection,
            ),
          ),
        ),
      ),
    );

    final canvas = find.byKey(const ValueKey('attack-graph-canvas'));
    final topLeft = tester.getTopLeft(canvas);
    await tester.tapAt(topLeft + const Offset(340, 160));
    await tester.pumpAndSettle();
    expect(selectedEntity?.id, 'demo-ip');
    expect(selectedConnection, isNull);
    expect(find.text('Suspicious source'), findsOneWidget);
    expect(find.text('Demo only · not verified'), findsOneWidget);
    expect(find.text('Observed'), findsWidgets);
    expect(find.text('Suspicious'), findsWidgets);
    expect(find.text('Hypothesized'), findsWidgets);

    await tester.tapAt(topLeft + const Offset(263, 160));
    await tester.pumpAndSettle();
    expect(selectedEntity, isNull);
    expect(selectedConnection?.id, 'demo-link-1');
    expect(find.text('Selected relationship'), findsOneWidget);
    expect(
        find.text(
            'Hypothesized relationship · not confirmed as an attack path.'),
        findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('attack graph pans and zooms interactively', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AttackGraph2D()),
        ),
      ),
    );

    final interactiveViewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final before = interactiveViewer.transformationController!.value.clone();
    await tester.drag(
      find.byKey(const ValueKey('attack-graph-canvas')),
      const Offset(-60, -35),
    );
    await tester.pumpAndSettle();
    expect(
      interactiveViewer.transformationController!.value,
      isNot(equals(before)),
    );

    final scaleBeforePinch =
        interactiveViewer.transformationController!.value.getMaxScaleOnAxis();
    final center = tester.getCenter(
      find.byKey(const ValueKey('attack-graph-canvas')),
    );
    final firstFinger = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    final secondFinger = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await firstFinger.moveBy(const Offset(-25, 0));
    await secondFinger.moveBy(const Offset(25, 0));
    await firstFinger.up();
    await secondFinger.up();
    await tester.pumpAndSettle();
    expect(
      interactiveViewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(scaleBeforePinch),
    );

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('3D layout is stable, volumetric, and does not mutate source entities',
      () {
    const entities = VisualizationDataService.entities;
    final before = entities.map((entity) => entity.position).toList();
    final layout = AttackGraph3DLayout.positionsFor(entities);
    final reverseLayout = AttackGraph3DLayout.positionsFor(entities.reversed);

    expect(layout, reverseLayout);
    expect(layout.values.toSet(), hasLength(entities.length));
    expect(layout.values.every((point) => point.isFinite), isTrue);
    expect(
        layout.values.map((point) => point.x).toSet().length, greaterThan(1));
    expect(
        layout.values.map((point) => point.y).toSet().length, greaterThan(1));
    expect(
        layout.values.map((point) => point.z).toSet().length, greaterThan(1));
    final projected = entities
        .map(
          (entity) => AttackGraph3DProjection.project(
            point: layout[entity.id]!,
            viewport: const Size(800, 500),
            camera: AttackGraph3DCamera.initial,
          )!
              .position,
        )
        .toList();
    var closestPair = double.infinity;
    for (var first = 0; first < projected.length; first++) {
      for (var second = first + 1; second < projected.length; second++) {
        closestPair = math.min(
          closestPair,
          (projected[first] - projected[second]).distance,
        );
      }
    }
    expect(closestPair, greaterThan(40));
    expect(entities.map((entity) => entity.position), before);
  });

  test('3D projection handles perspective and clips near and far depth', () {
    const viewport = Size(800, 600);
    const camera = AttackGraph3DCamera.initial;
    final center = AttackGraph3DProjection.project(
      point: const GraphVector3(0, 0, 0),
      viewport: viewport,
      camera: camera,
    )!;
    expect(center.position.dx, closeTo(400, .01));
    expect(center.position.dy, closeTo(300, .01));

    final rotated = AttackGraph3DProjection.project(
      point: const GraphVector3(100, 0, 0),
      viewport: viewport,
      camera: camera.copyWith(yaw: camera.yaw + 1),
    )!;
    final unrotated = AttackGraph3DProjection.project(
      point: const GraphVector3(100, 0, 0),
      viewport: viewport,
      camera: camera,
    )!;
    expect(rotated.position, isNot(unrotated.position));

    final nearPoint = AttackGraph3DProjection.project(
      point: const GraphVector3(0, 0, 100),
      viewport: viewport,
      camera: camera,
    )!;
    final farPoint = AttackGraph3DProjection.project(
      point: const GraphVector3(0, 0, -100),
      viewport: viewport,
      camera: camera,
    )!;
    expect(farPoint.scale, greaterThan(nearPoint.scale));

    expect(
      AttackGraph3DProjection.project(
        point: const GraphVector3(0, 0, -100),
        viewport: viewport,
        camera: const AttackGraph3DCamera(
          yaw: 0,
          pitch: 0,
          distance: 100,
        ),
      ),
      isNull,
    );
    expect(
      AttackGraph3DProjection.project(
        point: const GraphVector3(0, 0, -9500),
        viewport: viewport,
        camera: camera,
      ),
      isNull,
    );
    expect(
      AttackGraph3DProjection.project(
        point: const GraphVector3(double.nan, 0, 0),
        viewport: viewport,
        camera: camera,
      ),
      isNull,
    );
    expect(
      AttackGraph3DProjection.project(
        point: const GraphVector3(1e308, 1e308, 1e308),
        viewport: viewport,
        camera: camera,
      ),
      isNull,
    );
    expect(
      AttackGraph3DProjection.project(
        point: const GraphVector3(0, 0, 0),
        viewport: viewport,
        camera: camera.copyWith(pitch: 2),
      ),
      isNull,
    );
    expect(
      AttackGraph3DProjection.project(
        point: const GraphVector3(0, 0, 0),
        viewport: viewport,
        camera: camera.copyWith(zoom: 1e100),
      ),
      isNull,
    );
  });

  test('3D node picking chooses the nearest node at overlapping screen point',
      () {
    const near = AttackEntity(
      id: 'near',
      name: 'Near node',
      entityType: AttackEntityType.workstation,
      position: Offset.zero,
      z: 0,
      severity: Severity.high,
      riskScore: 70,
      description: 'Near fixture',
      investigationStatus: 'Demo',
    );
    const far = AttackEntity(
      id: 'far',
      name: 'Far node',
      entityType: AttackEntityType.workstation,
      position: Offset.zero,
      z: 0,
      severity: Severity.high,
      riskScore: 70,
      description: 'Far fixture',
      investigationStatus: 'Demo',
    );
    const overlap = Offset(100, 100);
    final picked = AttackGraph3DPicking.nearestNodeAt(
      projectedNodes: {
        near: const ProjectedGraphPoint(
          position: overlap,
          depth: 250,
          scale: 1,
        ),
        far: const ProjectedGraphPoint(
          position: overlap,
          depth: 500,
          scale: 1,
        ),
      },
      tap: overlap,
    );
    expect(picked, near);
  });

  test('3D edge picking selects the edge rendered in front at a crossing', () {
    const front = AttackConnection(
      id: 'front',
      sourceEntityId: 'source-front',
      targetEntityId: 'target-front',
      connectionType: AttackConnectionType.observed,
      severity: Severity.high,
      status: AttackConnectionStatus.illustrative,
      isDirected: true,
      isConfirmed: false,
      description: 'Front edge fixture.',
    );
    const back = AttackConnection(
      id: 'back',
      sourceEntityId: 'source-back',
      targetEntityId: 'target-back',
      connectionType: AttackConnectionType.hypothesized,
      severity: Severity.high,
      status: AttackConnectionStatus.illustrative,
      isDirected: true,
      isConfirmed: false,
      description: 'Back edge fixture.',
    );

    final picked = AttackGraph3DPicking.nearestConnectionAt(
      projectedConnections: {
        back: const ProjectedGraphLine(
          start: Offset(20, 50),
          end: Offset(180, 50),
          startDepth: 500,
          endDepth: 500,
        ),
        front: const ProjectedGraphLine(
          start: Offset(100, 0),
          end: Offset(100, 100),
          startDepth: 250,
          endDepth: 250,
        ),
      },
      tap: const Offset(100, 50),
    );

    expect(picked, front);
  });

  test('3D relationship styles remain distinct by classification', () {
    final colors =
        AttackConnectionType.values.map(AttackGraph3DStyle.colorFor).toSet();
    expect(colors, hasLength(3));
    expect(
      AttackGraph3DStyle.dashPatternFor(AttackConnectionType.observed),
      isEmpty,
    );
    expect(
      AttackGraph3DStyle.dashPatternFor(AttackConnectionType.suspicious),
      isNot(AttackGraph3DStyle.dashPatternFor(
        AttackConnectionType.hypothesized,
      )),
    );
  });

  testWidgets('3D graph supports node and relationship selection',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1100);
    AttackEntity? selectedEntity;
    AttackConnection? selectedConnection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AttackGraph3D(
              onEntitySelectionChanged: (entity) => selectedEntity = entity,
              onConnectionSelectionChanged: (connection) =>
                  selectedConnection = connection,
            ),
          ),
        ),
      ),
    );

    final canvas = find.byKey(const ValueKey('attack-graph-3d-canvas'));
    await tester.ensureVisible(canvas);
    final size = tester.getSize(canvas);
    final topLeft = tester.getTopLeft(canvas);
    const entities = VisualizationDataService.entities;
    final positions = AttackGraph3DLayout.positionsFor(entities);
    final nodePosition = AttackGraph3DProjection.project(
      point: positions[entities.first.id]!,
      viewport: size,
      camera: AttackGraph3DCamera.initial,
    )!;
    await tester.tapAt(topLeft + nodePosition.position);
    await tester.pumpAndSettle();
    expect(selectedEntity?.id, entities.first.id);
    expect(selectedConnection, isNull);
    expect(find.text(entities.first.name), findsWidgets);
    expect(find.textContaining('Risk '), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AttackGraph3D(
              onEntitySelectionChanged: (entity) => selectedEntity = entity,
              onConnectionSelectionChanged: (connection) =>
                  selectedConnection = connection,
            ),
          ),
        ),
      ),
    );
    final freshCanvas = find.byKey(const ValueKey('attack-graph-3d-canvas'));
    await tester.ensureVisible(freshCanvas);
    final freshSize = tester.getSize(freshCanvas);
    final freshTopLeft = tester.getTopLeft(freshCanvas);
    final source = entities.firstWhere(
      (entity) =>
          entity.id == VisualizationDataService.connections[0].sourceEntityId,
    );
    final target = entities.firstWhere(
      (entity) =>
          entity.id == VisualizationDataService.connections[0].targetEntityId,
    );
    final sourcePoint = AttackGraph3DProjection.project(
      point: positions[source.id]!,
      viewport: freshSize,
      camera: AttackGraph3DCamera.initial,
    )!;
    final targetPoint = AttackGraph3DProjection.project(
      point: positions[target.id]!,
      viewport: freshSize,
      camera: AttackGraph3DCamera.initial,
    )!;
    await tester.tapAt(
      freshTopLeft + (sourcePoint.position + targetPoint.position) / 2,
    );
    await tester.pumpAndSettle();
    expect(selectedEntity, isNull);
    expect(selectedConnection?.id, VisualizationDataService.connections[0].id);
    expect(find.text('Selected relationship'), findsOneWidget);
    expect(find.text('Hypothesized path'), findsOneWidget);
    expect(find.text('Confirmation'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('3D graph supports search, highlighting, and empty results',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AttackGraph3D()),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('attack-graph-3d-search')),
      'Suspicious source',
    );
    await tester.pumpAndSettle();
    expect(
        find.textContaining('1 matching entity highlighted'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('attack-graph-3d-search')),
      'no such entity',
    );
    await tester.pumpAndSettle();
    expect(find.text('No graph entities match these filters.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear entity search'));
    await tester.pumpAndSettle();
    expect(find.text('No graph entities match these filters.'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('attack-graph-3d-type-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workstation').last);
    await tester.pumpAndSettle();
    expect(find.text('Workstation'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('attack-graph-3d-severity-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').last);
    await tester.pumpAndSettle();
    expect(find.text('Critical'), findsOneWidget);
  });

  testWidgets('3D filtering clears a previously selected entity',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1000);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AttackGraph3D()),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    final canvas = find.byKey(const ValueKey('attack-graph-3d-canvas'));
    await tester.ensureVisible(canvas);
    final size = tester.getSize(canvas);
    final entity = VisualizationDataService.entities.first;
    final position = AttackGraph3DLayout.positionsFor(
      VisualizationDataService.entities,
    )[entity.id]!;
    final projected = AttackGraph3DProjection.project(
      point: position,
      viewport: size,
      camera: AttackGraph3DCamera.initial,
    )!;
    await tester.tapAt(tester.getTopLeft(canvas) + projected.position);
    await tester.pumpAndSettle();
    expect(find.text(entity.name), findsWidgets);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('attack-graph-3d-selection-state')),
          )
          .label,
      contains(entity.name),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('attack-graph-3d-clear-selection')),
    );
    await tester.tap(
      find.byKey(const ValueKey('attack-graph-3d-clear-selection')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attack-graph-3d-clear-selection')),
        findsNothing);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('attack-graph-3d-selection-state')),
          )
          .label,
      contains('No graph selection'),
    );

    await tester.tapAt(tester.getTopLeft(canvas) + projected.position);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attack-graph-3d-clear-selection')),
        findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('attack-graph-3d-search')),
      'no matching entity',
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
          'Select a node or relationship to inspect illustrative details.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Clear entity search'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attack-graph-3d-clear-selection')),
        findsNothing);
    expect(
      find.text(
          'Select a node or relationship to inspect illustrative details.'),
      findsOneWidget,
    );

    semantics.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('3D camera supports rotation, pan, wheel zoom, and reset',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1000);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AttackGraph3D()),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    String cameraValue() => tester
        .getSemantics(
          find.byKey(const ValueKey('attack-graph-3d-camera-state')),
        )
        .value;

    final initial = cameraValue();
    final canvas = find.byKey(const ValueKey('attack-graph-3d-canvas'));
    await tester.drag(canvas, const Offset(45, 28));
    await tester.pumpAndSettle();
    expect(cameraValue(), isNot(initial));

    await tester
        .tap(find.byKey(const ValueKey('attack-graph-3d-gesture-mode')));
    await tester.pumpAndSettle();
    await tester.drag(canvas, const Offset(32, 24));
    await tester.pumpAndSettle();
    expect(cameraValue(), matches(RegExp(r'pan (?!0, 0).+')));

    final viewport = tester.getRect(
      find.byKey(const ValueKey('attack-graph-3d-viewport')),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: viewport.center,
        scrollDelta: const Offset(0, -100),
      ),
    );
    await tester.pumpAndSettle();
    expect(cameraValue(), contains('zoom 1.11'));

    final canvasRect = tester.getRect(canvas);
    final pinchCenter = canvasRect.center;
    final firstPointer = await tester.startGesture(
      pinchCenter - const Offset(35, 0),
      pointer: 3,
    );
    final secondPointer = await tester.startGesture(
      pinchCenter + const Offset(35, 0),
      pointer: 4,
    );
    await tester.pump();
    await firstPointer.moveBy(const Offset(-45, 0));
    await secondPointer.moveBy(const Offset(45, 0));
    await tester.pump();
    await firstPointer.up();
    await secondPointer.up();
    await tester.pumpAndSettle();
    expect(cameraValue(), isNot(contains('zoom 1.11')));

    await tester
        .ensureVisible(find.byKey(const ValueKey('attack-graph-3d-reset')));
    await tester.tap(find.byKey(const ValueKey('attack-graph-3d-reset')));
    await tester.pumpAndSettle();
    expect(cameraValue(), initial);

    semantics.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('3D camera controls are accessible without drag gestures',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AttackGraph3D()),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    final state = find.byKey(const ValueKey('attack-graph-3d-camera-state'));
    final selection = find.byKey(
      const ValueKey('attack-graph-3d-selection-state'),
    );
    final initialCamera = tester.getSemantics(state).value;
    await tester.ensureVisible(find.byTooltip('Zoom in'));
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(state).value, isNot(initialCamera));

    final zoomedCamera = tester.getSemantics(state).value;
    await tester.ensureVisible(find.byTooltip('Rotate left'));
    await tester.tap(find.byTooltip('Rotate left'));
    await tester.pumpAndSettle();
    final rotatedCamera = tester.getSemantics(state).value;
    expect(rotatedCamera, isNot(zoomedCamera));
    await tester.ensureVisible(find.byTooltip('Tilt down'));
    await tester.tap(find.byTooltip('Tilt down'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(state).value, isNot(rotatedCamera));
    expect(
      tester.getSemantics(selection).label,
      contains('No graph selection'),
    );

    await tester.ensureVisible(find.byTooltip('Reset view'));
    await tester.tap(find.byTooltip('Reset view'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(state).value, initialCamera);

    semantics.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('3D graph lays out at phone, tablet, and desktop widths',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    for (final width in [390.0, 768.0, 1199.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AttackGraph3D()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attack-graph-3d-viewport')),
          findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('connection details separate type from confirmation status',
      (tester) async {
    for (final type in AttackConnectionType.values) {
      final connection = AttackConnection(
        id: 'unconfirmed-${type.name}',
        sourceEntityId: 'demo-account',
        targetEntityId: 'demo-workstation',
        connectionType: type,
        severity: Severity.medium,
        status: AttackConnectionStatus.illustrative,
        isDirected: true,
        isConfirmed: false,
        description: 'Illustrative ${type.label} relationship.',
      );
      final message = switch (type) {
        AttackConnectionType.observed =>
          'Observed classification · not independently confirmed in this demo.',
        AttackConnectionType.suspicious =>
          'Suspicious relationship · not confirmed as an attack.',
        AttackConnectionType.hypothesized =>
          'Hypothesized relationship · not confirmed as an attack path.',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttackEntityDetails(
              entity: null,
              connection: connection,
              entities: VisualizationDataService.entities,
              connections: [connection],
            ),
          ),
        ),
      );

      expect(find.text(type.label), findsOneWidget);
      expect(find.text('Not confirmed'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      if (type != AttackConnectionType.hypothesized) {
        expect(find.textContaining('Hypothesis only'), findsNothing);
      }
    }

    const confirmed = AttackConnection(
      id: 'confirmed-suspicious',
      sourceEntityId: 'demo-account',
      targetEntityId: 'demo-workstation',
      connectionType: AttackConnectionType.suspicious,
      severity: Severity.medium,
      status: AttackConnectionStatus.confirmed,
      isDirected: true,
      isConfirmed: true,
      description: 'Demo marked confirmed.',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttackEntityDetails(
            entity: null,
            connection: confirmed,
            entities: VisualizationDataService.entities,
            connections: [confirmed],
          ),
        ),
      ),
    );
    expect(find.text('Confirmed'), findsOneWidget);
    expect(
      find.text('Marked confirmed in the fixture; this is demo data.'),
      findsOneWidget,
    );
  });

  testWidgets('vulnerability chart states that data is not connected',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VulnerabilityAnalyticsChart()),
      ),
    );

    expect(find.text('Vulnerability data not connected'), findsOneWidget);
    expect(find.textContaining('No vulnerability counts'), findsOneWidget);
    expect(find.textContaining('CVE records'), findsOneWidget);
  });

  testWidgets('workspace avoids overflow at phone, tablet, and desktop sizes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(390, 844),
      const Size(768, 900),
      const Size(1199, 1000),
      const Size(1440, 1000),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VisualizationWorkspace(
              selectedSeverity: null,
              onSeverityChanged: _ignoreSeverity,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Threat analysis workspace'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('workspace preserves 2D graph and offers a 3D alternative',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1100);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VisualizationWorkspace(
            selectedSeverity: null,
            onSeverityChanged: _ignoreSeverity,
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Attack Graph'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attack-graph-view-2d')), findsOneWidget);
    expect(find.byKey(const ValueKey('attack-graph-view-3d')), findsOneWidget);
    expect(find.text('Interactive 2D attack graph'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('attack-graph-view-3d')));
    await tester.pumpAndSettle();
    expect(find.text('Interactive 3D attack graph'), findsOneWidget);
    expect(find.text('Interactive 2D attack graph'), findsNothing);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('graph association requires an explicit analyst action',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1000);
    String? associatedEntityId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualizationWorkspace(
            selectedSeverity: null,
            onSeverityChanged: _ignoreSeverity,
            associationInvestigationId: 'INV-GRAPH-1',
            onAssociateGraphEntity: (investigationId, entityId) async {
              expect(investigationId, 'INV-GRAPH-1');
              associatedEntityId = entityId;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Attack Graph'));
    await tester.pumpAndSettle();
    final canvas = find.byKey(const ValueKey('attack-graph-canvas'));
    await tester.ensureVisible(canvas);
    final topLeft = tester.getTopLeft(canvas);
    await tester.tapAt(topLeft + const Offset(340, 160));
    await tester.pumpAndSettle();

    expect(associatedEntityId, isNull);
    final associateButton = find.text('Associate entity');
    await tester.ensureVisible(associateButton);
    await tester.tap(associateButton);
    await tester.pumpAndSettle();
    expect(associatedEntityId, 'demo-ip');
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('severity selection is shared with the existing alert inbox',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(const HuntAiApp());

    await tester.tap(find.text('Threat analysis').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Severity'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Threat severity distribution'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alerts').first);
    await tester.pumpAndSettle();
    expect(find.text('Repeated SSH login failures'), findsOneWidget);
    expect(find.text('Unusual after-hours sign-in'), findsNothing);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('attack graph models preserve 3D coordinates and unconfirmed paths', () {
    const entity = VisualizationDataService.entities;
    const connections = VisualizationDataService.connections;

    expect(entity.first.x, 90);
    expect(entity.first.y, 160);
    expect(entity.first.z, 0);
    expect(connections.every((connection) => !connection.isConfirmed), isTrue);
    expect(
      connections.every(
        (connection) =>
            connection.status == AttackConnectionStatus.illustrative,
      ),
      isTrue,
    );
    expect(entity.first.entityType, AttackEntityType.attacker);
  });

  test('hypothesized edge contrast satisfies >= 3:1 against dark background',
      () {
    const bgDark = Color(0xFF2C3647);
    const hypothesized = AttackGraph3DStyle.hypothesized;
    final bgLum = bgDark.computeLuminance();
    final edgeLum = hypothesized.computeLuminance();
    final contrastRatio =
        (math.max(bgLum, edgeLum) + 0.05) / (math.min(bgLum, edgeLum) + 0.05);
    expect(contrastRatio, greaterThanOrEqualTo(3.0));
  });

  test(
      'attack graph dash patterns provide visible dashes for hypothesized and suspicious',
      () {
    expect(
      AttackGraph3DStyle.dashPatternFor(AttackConnectionType.hypothesized),
      const [5.0, 4.0],
    );
    expect(
      AttackGraph3DStyle.dashPatternFor(AttackConnectionType.suspicious),
      const [7.0, 5.0],
    );
    expect(
      AttackGraph3DStyle.dashPatternFor(AttackConnectionType.observed),
      isEmpty,
    );
  });

  testWidgets('attack graph 2D and 3D display accurate caption disclosure text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AttackGraph2D(),
                AttackGraph3D(),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Displaying 5 synthetic demonstration nodes and 4 illustrative paths — none are verified.',
      ),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('attack-graph-2d-reset')), findsOneWidget);
    expect(find.byKey(const ValueKey('attack-graph-3d-reset')), findsOneWidget);
  });

  testWidgets(
      'attack graph 2D fits all nodes within narrow mobile viewport (390x844)',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AttackGraph2D()),
        ),
      ),
    );

    final interactiveViewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final controller = interactiveViewer.transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), 1.0);

    await tester.tap(find.byKey(const ValueKey('attack-graph-2d-reset')));
    await tester.pumpAndSettle();

    final resetScale = controller.value.getMaxScaleOnAxis();
    expect(resetScale, lessThan(1.0));
    expect(resetScale, greaterThanOrEqualTo(0.35));

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _EmptyTimelineService extends VisualizationDataService {
  const _EmptyTimelineService();

  @override
  List<TimelinePoint> timeline(String range) => [];
}

void _ignoreSeverity(Severity? severity) {}
