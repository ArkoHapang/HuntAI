import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/demo_data.dart';
import '../models/attack_connection.dart';
import '../models/attack_entity.dart';
import '../services/visualization_data_service.dart';
import 'attack_entity_details.dart';

class GraphVector3 {
  const GraphVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  @override
  bool operator ==(Object other) =>
      other is GraphVector3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

class AttackGraph3DLayout {
  const AttackGraph3DLayout._();

  static const radius = 220.0;

  static Map<String, GraphVector3> positionsFor(
    Iterable<AttackEntity> entities,
  ) {
    final ordered = entities.toList()..sort((a, b) => a.id.compareTo(b.id));
    if (ordered.isEmpty) return const {};
    final goldenAngle = math.pi * (3 - math.sqrt(5));
    return {
      for (var index = 0; index < ordered.length; index++)
        ordered[index].id: _positionFor(
          ordered[index],
          index,
          ordered.length,
          goldenAngle,
        ),
    };
  }

  static GraphVector3 _positionFor(
    AttackEntity entity,
    int index,
    int count,
    double goldenAngle,
  ) {
    final vertical = count == 1 ? 0.0 : 1 - 2 * index / (count - 1);
    final horizontal = math.sqrt(math.max(0, 1 - vertical * vertical));
    final longitude = goldenAngle * index;
    return GraphVector3(
      radius * horizontal * math.cos(longitude),
      radius * vertical,
      radius * horizontal * math.sin(longitude) + entity.z * 8,
    );
  }
}

class AttackGraph3DCamera {
  const AttackGraph3DCamera({
    this.yaw = .42,
    this.pitch = -.2,
    this.distance = 720,
    this.zoom = 1,
    this.pan = Offset.zero,
  });

  static const initial = AttackGraph3DCamera();
  static const minZoom = .45;
  static const maxZoom = 2.6;
  static const minPitch = -1.25;
  static const maxPitch = 1.25;

  final double yaw;
  final double pitch;
  final double distance;
  final double zoom;
  final Offset pan;

  AttackGraph3DCamera copyWith({
    double? yaw,
    double? pitch,
    double? distance,
    double? zoom,
    Offset? pan,
  }) {
    return AttackGraph3DCamera(
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      distance: distance ?? this.distance,
      zoom: zoom ?? this.zoom,
      pan: pan ?? this.pan,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AttackGraph3DCamera &&
      other.yaw == yaw &&
      other.pitch == pitch &&
      other.distance == distance &&
      other.zoom == zoom &&
      other.pan == pan;

  @override
  int get hashCode => Object.hash(yaw, pitch, distance, zoom, pan);
}

class ProjectedGraphPoint {
  const ProjectedGraphPoint({
    required this.position,
    required this.depth,
    required this.scale,
  });

  final Offset position;
  final double depth;
  final double scale;
}

class AttackGraph3DProjection {
  const AttackGraph3DProjection._();

  static const focalLength = 650.0;
  static const nearPlane = 35.0;
  static const farPlane = 10000.0;
  static const maxWorldCoordinate = 1e7;
  static const maxProjectedCoordinate = 1e7;

  static ProjectedGraphPoint? project({
    required GraphVector3 point,
    required Size viewport,
    required AttackGraph3DCamera camera,
  }) {
    if (!point.isFinite ||
        point.x.abs() > maxWorldCoordinate ||
        point.y.abs() > maxWorldCoordinate ||
        point.z.abs() > maxWorldCoordinate ||
        !viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.isEmpty ||
        !camera.yaw.isFinite ||
        !camera.pitch.isFinite ||
        !camera.distance.isFinite ||
        !camera.zoom.isFinite ||
        camera.distance <= 0 ||
        camera.zoom < AttackGraph3DCamera.minZoom ||
        camera.zoom > AttackGraph3DCamera.maxZoom ||
        camera.pitch < AttackGraph3DCamera.minPitch ||
        camera.pitch > AttackGraph3DCamera.maxPitch ||
        camera.yaw.abs() > 1e12 ||
        camera.distance > maxWorldCoordinate ||
        !camera.pan.dx.isFinite ||
        !camera.pan.dy.isFinite ||
        camera.pan.dx.abs() > maxProjectedCoordinate ||
        camera.pan.dy.abs() > maxProjectedCoordinate) {
      return null;
    }

    final cosYaw = math.cos(camera.yaw);
    final sinYaw = math.sin(camera.yaw);
    final yawX = point.x * cosYaw - point.z * sinYaw;
    final yawZ = point.x * sinYaw + point.z * cosYaw;
    final cosPitch = math.cos(camera.pitch);
    final sinPitch = math.sin(camera.pitch);
    final pitchY = point.y * cosPitch - yawZ * sinPitch;
    final pitchZ = point.y * sinPitch + yawZ * cosPitch;
    final depth = camera.distance + pitchZ;
    if (!yawX.isFinite ||
        !pitchY.isFinite ||
        !depth.isFinite ||
        depth <= nearPlane ||
        depth >= farPlane) {
      return null;
    }

    final scale = focalLength / depth * camera.zoom;
    final position = Offset(
      viewport.width / 2 + yawX * scale + camera.pan.dx,
      viewport.height / 2 - pitchY * scale + camera.pan.dy,
    );
    if (!scale.isFinite ||
        !position.dx.isFinite ||
        !position.dy.isFinite ||
        position.dx.abs() > maxProjectedCoordinate ||
        position.dy.abs() > maxProjectedCoordinate) {
      return null;
    }
    return ProjectedGraphPoint(
      position: position,
      depth: depth,
      scale: scale,
    );
  }
}

class ProjectedGraphLine {
  const ProjectedGraphLine({
    required this.start,
    required this.end,
    required this.startDepth,
    required this.endDepth,
  });

  final Offset start;
  final Offset end;
  final double startDepth;
  final double endDepth;

  double get averageDepth => (startDepth + endDepth) / 2;
}

class AttackGraph3DPicking {
  const AttackGraph3DPicking._();

  static const nodeRadius = 24.0;
  static const nodeHitPadding = 8.0;
  static const connectionHitRadius = 10.0;

  static AttackEntity? nearestNodeAt({
    required Map<AttackEntity, ProjectedGraphPoint> projectedNodes,
    required Offset tap,
  }) {
    final hits = projectedNodes.entries.where((entry) {
      final radius = nodeRadius * entry.value.scale.clamp(.55, 1.5);
      return (tap - entry.value.position).distance <= radius + nodeHitPadding;
    }).toList()
      ..sort((a, b) => a.value.depth.compareTo(b.value.depth));
    return hits.firstOrNull?.key;
  }

  static ProjectedGraphLine? lineFor(
    ProjectedGraphPoint start,
    ProjectedGraphPoint end,
  ) {
    final vector = end.position - start.position;
    final length = vector.distance;
    if (!length.isFinite || length <= 0) return null;
    final direction = vector / length;
    final startRadius = nodeRadius * start.scale.clamp(.55, 1.5);
    final endRadius = nodeRadius * end.scale.clamp(.55, 1.5);
    final lineStart = start.position + direction * startRadius;
    final lineEnd = end.position - direction * endRadius;
    if ((lineEnd - lineStart).distance <= 2) return null;
    return ProjectedGraphLine(
      start: lineStart,
      end: lineEnd,
      startDepth: start.depth,
      endDepth: end.depth,
    );
  }

  static double segmentRatio(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.distanceSquared;
    if (lengthSquared == 0) return 0;
    return (((point - start).dx * segment.dx +
                (point - start).dy * segment.dy) /
            lengthSquared)
        .clamp(0.0, 1.0);
  }

  static double distanceToSegment(Offset point, Offset start, Offset end) {
    final ratio = segmentRatio(point, start, end);
    return (point - (start + (end - start) * ratio)).distance;
  }

  static AttackConnection? nearestConnectionAt({
    required Map<AttackConnection, ProjectedGraphLine> projectedConnections,
    required Offset tap,
  }) {
    final hits = <(AttackConnection, double, double)>[];
    for (final entry in projectedConnections.entries) {
      final distance =
          distanceToSegment(tap, entry.value.start, entry.value.end);
      if (distance <= connectionHitRadius) {
        hits.add((entry.key, entry.value.averageDepth, distance));
      }
    }
    hits.sort((a, b) {
      final depthOrder = a.$2.compareTo(b.$2);
      return depthOrder != 0 ? depthOrder : a.$3.compareTo(b.$3);
    });
    return hits.firstOrNull?.$1;
  }
}

class AttackGraph3DStyle {
  const AttackGraph3DStyle._();

  static const observed = Color(0xff4385f5);
  static const suspicious = Color(0xffff9a3d);
  static const hypothesized = Color(0xff9a8aae);

  static Color colorFor(AttackConnectionType type) => switch (type) {
        AttackConnectionType.observed => observed,
        AttackConnectionType.suspicious => suspicious,
        AttackConnectionType.hypothesized => hypothesized,
      };

  static List<double> dashPatternFor(AttackConnectionType type) =>
      switch (type) {
        AttackConnectionType.observed => const [],
        AttackConnectionType.suspicious => const [7, 5],
        AttackConnectionType.hypothesized => const [5, 4],
      };
}

class AttackGraph3D extends StatefulWidget {
  const AttackGraph3D({
    this.entities = VisualizationDataService.entities,
    this.connections = VisualizationDataService.connections,
    this.onEntitySelectionChanged,
    this.onConnectionSelectionChanged,
    super.key,
  });

  final List<AttackEntity> entities;
  final List<AttackConnection> connections;
  final ValueChanged<AttackEntity?>? onEntitySelectionChanged;
  final ValueChanged<AttackConnection?>? onConnectionSelectionChanged;

  @override
  State<AttackGraph3D> createState() => _AttackGraph3DState();
}

class _AttackGraph3DState extends State<AttackGraph3D> {
  final _searchController = TextEditingController();
  final _canvasKey = GlobalKey();
  late Map<String, GraphVector3> _positions;
  late List<AttackEntity> _layoutEntities;
  AttackGraph3DCamera _camera = AttackGraph3DCamera.initial;
  AttackEntity? _selectedEntity;
  AttackConnection? _selectedConnection;
  AttackEntityType? _typeFilter;
  Severity? _severityFilter;
  bool _showLabels = true;
  bool _showConnections = true;
  bool _panMode = false;
  double _lastGestureScale = 1;

  @override
  void initState() {
    super.initState();
    _updateLayout(widget.entities);
  }

  @override
  void didUpdateWidget(covariant AttackGraph3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_layoutEntities, widget.entities)) {
      _updateLayout(widget.entities);
      _clearSelection();
    }
  }

  void _updateLayout(List<AttackEntity> entities) {
    _layoutEntities = List<AttackEntity>.of(entities);
    _positions = AttackGraph3DLayout.positionsFor(_layoutEntities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final entities = widget.entities.where((entity) {
      return (_typeFilter == null || entity.entityType == _typeFilter) &&
          (_severityFilter == null || entity.severity == _severityFilter) &&
          (query.isEmpty ||
              entity.name.toLowerCase().contains(query) ||
              entity.id.toLowerCase().contains(query) ||
              (entity.ipAddress?.toLowerCase().contains(query) ?? false));
    }).toList();
    final visibleIds = entities.map((entity) => entity.id).toSet();
    final connections = widget.connections
        .where((edge) =>
            visibleIds.contains(edge.sourceEntityId) &&
            visibleIds.contains(edge.targetEntityId))
        .toList();
    final selectedEntity = entities
        .where((entity) => entity.id == _selectedEntity?.id)
        .firstOrNull;
    final selectedConnection = connections
        .where((edge) => edge.id == _selectedConnection?.id)
        .firstOrNull;
    final matchingIds = query.isEmpty
        ? const <String>{}
        : entities
            .where((entity) =>
                entity.name.toLowerCase().contains(query) ||
                entity.id.toLowerCase().contains(query) ||
                (entity.ipAddress?.toLowerCase().contains(query) ?? false))
            .map((entity) => entity.id)
            .toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Interactive 3D attack graph',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Tooltip(
                  message: 'Reset view',
                  child: OutlinedButton.icon(
                    key: const ValueKey('attack-graph-3d-reset'),
                    onPressed: _resetCamera,
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    label: const Text('Reset view'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Displaying 5 synthetic demonstration nodes and 4 illustrative paths — none are verified.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            Wrap(
              spacing: 2,
              children: [
                IconButton(
                  key: const ValueKey('attack-graph-3d-zoom-in'),
                  tooltip: 'Zoom in',
                  onPressed: () => _zoomFromCanvas(1.15),
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton(
                  key: const ValueKey('attack-graph-3d-zoom-out'),
                  tooltip: 'Zoom out',
                  onPressed: () => _zoomFromCanvas(1 / 1.15),
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  key: const ValueKey('attack-graph-3d-rotate-left'),
                  tooltip: 'Rotate left',
                  onPressed: () => _rotateBy(-.15, 0),
                  icon: const Icon(Icons.rotate_left),
                ),
                IconButton(
                  key: const ValueKey('attack-graph-3d-rotate-right'),
                  tooltip: 'Rotate right',
                  onPressed: () => _rotateBy(.15, 0),
                  icon: const Icon(Icons.rotate_right),
                ),
                IconButton(
                  key: const ValueKey('attack-graph-3d-tilt-up'),
                  tooltip: 'Tilt up',
                  onPressed: () => _rotateBy(0, -.1),
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  key: const ValueKey('attack-graph-3d-tilt-down'),
                  tooltip: 'Tilt down',
                  onPressed: () => _rotateBy(0, .1),
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '3D positions are illustrative visualization coordinates, not measured physical or network locations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    key: const ValueKey('attack-graph-3d-search'),
                    controller: _searchController,
                    onChanged: (_) => setState(_clearSelection),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search entities',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: IconButton(
                        tooltip: 'Clear entity search',
                        onPressed: () {
                          _searchController.clear();
                          setState(_clearSelection);
                        },
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<AttackEntityType?>(
                    key: const ValueKey('attack-graph-3d-type-filter'),
                    initialValue: _typeFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Entity type',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All entity types'),
                      ),
                      for (final type in AttackEntityType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: (type) => setState(() {
                      _typeFilter = type;
                      _clearSelection();
                    }),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<Severity?>(
                    key: const ValueKey('attack-graph-3d-severity-filter'),
                    initialValue: _severityFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Severity',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All severities'),
                      ),
                      for (final severity in Severity.values)
                        DropdownMenuItem(
                          value: severity,
                          child: Text(severity.label),
                        ),
                    ],
                    onChanged: (severity) => setState(() {
                      _severityFilter = severity;
                      _clearSelection();
                    }),
                  ),
                ),
                FilterChip(
                  label: const Text('Labels'),
                  selected: _showLabels,
                  onSelected: (value) => setState(() => _showLabels = value),
                ),
                FilterChip(
                  label: const Text('Connections'),
                  selected: _showConnections,
                  onSelected: (value) => setState(() {
                    _showConnections = value;
                    if (!value) _clearSelection();
                  }),
                ),
                ChoiceChip(
                  key: const ValueKey('attack-graph-3d-gesture-mode'),
                  label: Text(_panMode ? 'Drag to pan' : 'Drag to rotate'),
                  selected: _panMode,
                  onSelected: (value) => setState(() => _panMode = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _RelationshipLegend(),
            const SizedBox(height: 8),
            if (query.isNotEmpty && matchingIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${matchingIds.length} matching ${matchingIds.length == 1 ? 'entity' : 'entities'} highlighted · relationships remain unverified',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            SizedBox(
              key: const ValueKey('attack-graph-3d-viewport'),
              height: MediaQuery.sizeOf(context).width < 600 ? 320 : 420,
              width: double.infinity,
              child: entities.isEmpty
                  ? Center(
                      child: Text(
                        'No graph entities match these filters.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: .45),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return Listener(
                              onPointerSignal: (event) {
                                if (event is PointerScrollEvent &&
                                    event.scrollDelta.dy != 0) {
                                  final factor =
                                      event.scrollDelta.dy > 0 ? .9 : 1 / .9;
                                  _zoomAround(
                                    factor,
                                    event.localPosition,
                                    size,
                                  );
                                }
                              },
                              child: Semantics(
                                key: const ValueKey(
                                  'attack-graph-3d-camera-state',
                                ),
                                container: true,
                                label: '3D graph camera state',
                                value:
                                    'yaw ${_camera.yaw.toStringAsFixed(2)}, pitch ${_camera.pitch.toStringAsFixed(2)}, zoom ${_camera.zoom.toStringAsFixed(2)}, pan ${_camera.pan.dx.toStringAsFixed(0)}, ${_camera.pan.dy.toStringAsFixed(0)}',
                                child: GestureDetector(
                                  key: const ValueKey('attack-graph-3d-canvas'),
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: (_) => _lastGestureScale = 1,
                                  onScaleEnd: (_) => _lastGestureScale = 1,
                                  onScaleUpdate: (details) {
                                    if (details.pointerCount > 1) {
                                      final factor =
                                          details.scale / _lastGestureScale;
                                      _lastGestureScale = details.scale;
                                      _zoomAround(
                                        factor,
                                        details.localFocalPoint,
                                        size,
                                      );
                                    } else {
                                      _drag(details.focalPointDelta, size);
                                    }
                                  },
                                  onTapUp: (details) => _selectAt(
                                    details.localPosition,
                                    size,
                                    entities,
                                    connections,
                                    _positions,
                                  ),
                                  child: CustomPaint(
                                    key: _canvasKey,
                                    painter: _AttackGraph3DPainter(
                                      entities: entities,
                                      connections: _showConnections
                                          ? connections
                                          : const [],
                                      positions: _positions,
                                      camera: _camera,
                                      selectedEntityId: selectedEntity?.id,
                                      selectedConnectionId:
                                          selectedConnection?.id,
                                      matchingIds: matchingIds,
                                      showLabels: _showLabels,
                                      textColor: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      mutedColor: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      nodeFill:
                                          Theme.of(context).colorScheme.surface,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            if (selectedEntity != null || selectedConnection != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('attack-graph-3d-clear-selection'),
                  onPressed: () => setState(_clearSelection),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear selection'),
                ),
              ),
            Semantics(
              key: const ValueKey('attack-graph-3d-selection-state'),
              container: true,
              liveRegion: true,
              label: _selectionSummary(selectedEntity, selectedConnection),
              child: AttackEntityDetails(
                entity: selectedEntity,
                connection: selectedConnection,
                entities: entities,
                connections: connections,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSelection() {
    _selectedEntity = null;
    _selectedConnection = null;
  }

  String _selectionSummary(
    AttackEntity? entity,
    AttackConnection? connection,
  ) {
    if (entity != null) {
      return 'Selected entity: ${entity.name}, ${entity.entityType.label}, ${entity.severity.label}, risk ${entity.riskScore} out of 100.';
    }
    if (connection != null) {
      return 'Selected ${connection.connectionType.label} relationship. ${connection.isConfirmed ? 'Confirmed in demo fixture.' : 'Not confirmed.'}';
    }
    return 'No graph selection. Select a node or relationship to inspect illustrative details.';
  }

  void _resetCamera() {
    setState(() {
      _camera = AttackGraph3DCamera.initial;
    });
  }

  void _zoomFromCanvas(double factor) {
    final renderObject = _canvasKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final size = renderObject.size;
    _zoomAround(factor, size.center(Offset.zero), size);
  }

  void _rotateBy(double yawDelta, double pitchDelta) {
    setState(() {
      _camera = _camera.copyWith(
        yaw: (_camera.yaw + yawDelta) % (2 * math.pi),
        pitch: (_camera.pitch + pitchDelta).clamp(
          AttackGraph3DCamera.minPitch,
          AttackGraph3DCamera.maxPitch,
        ),
      );
    });
  }

  void _drag(Offset delta, Size size) {
    if (!delta.dx.isFinite || !delta.dy.isFinite || size.isEmpty) return;
    if (_panMode) {
      setState(() {
        _camera = _camera.copyWith(
          pan: _clampPan(_camera.pan + delta, size),
        );
      });
      return;
    }
    setState(() {
      _camera = _camera.copyWith(
        yaw: (_camera.yaw + delta.dx * .008) % (2 * math.pi),
        pitch: (_camera.pitch + delta.dy * .006)
            .clamp(AttackGraph3DCamera.minPitch, AttackGraph3DCamera.maxPitch),
      );
    });
  }

  void _zoomAround(double factor, Offset focalPoint, Size size) {
    if (!factor.isFinite ||
        factor <= 0 ||
        size.isEmpty ||
        !focalPoint.dx.isFinite ||
        !focalPoint.dy.isFinite) {
      return;
    }
    final zoom = (_camera.zoom * factor)
        .clamp(AttackGraph3DCamera.minZoom, AttackGraph3DCamera.maxZoom);
    if (zoom == _camera.zoom) return;
    final actualFactor = zoom / _camera.zoom;
    final center = Offset(size.width / 2, size.height / 2);
    final focalFromCenter = focalPoint - center;
    final pan =
        focalPoint - center - (focalFromCenter - _camera.pan) * actualFactor;
    setState(() {
      _camera = _camera.copyWith(zoom: zoom, pan: _clampPan(pan, size));
    });
  }

  Offset _clampPan(Offset pan, Size size) {
    return Offset(
      pan.dx.clamp(-size.width, size.width),
      pan.dy.clamp(-size.height, size.height),
    );
  }

  void _selectAt(
    Offset tap,
    Size size,
    List<AttackEntity> entities,
    List<AttackConnection> connections,
    Map<String, GraphVector3> positions,
  ) {
    final projected = <AttackEntity, ProjectedGraphPoint>{};
    for (final entity in entities) {
      final point = positions[entity.id];
      if (point == null) continue;
      final projectedPoint = AttackGraph3DProjection.project(
        point: point,
        viewport: size,
        camera: _camera,
      );
      if (projectedPoint != null) projected[entity] = projectedPoint;
    }

    final selectedNode = AttackGraph3DPicking.nearestNodeAt(
      projectedNodes: projected,
      tap: tap,
    );
    if (selectedNode != null) {
      setState(() {
        _selectedEntity = selectedNode;
        _selectedConnection = null;
      });
      widget.onEntitySelectionChanged?.call(selectedNode);
      widget.onConnectionSelectionChanged?.call(null);
      return;
    }

    if (_showConnections) {
      final entityById = {for (final entity in entities) entity.id: entity};
      final projectedEdges = <AttackConnection, ProjectedGraphLine>{};
      for (final edge in connections) {
        final source = entityById[edge.sourceEntityId];
        final target = entityById[edge.targetEntityId];
        final start = source == null ? null : projected[source];
        final end = target == null ? null : projected[target];
        if (start == null || end == null) continue;
        final line = AttackGraph3DPicking.lineFor(start, end);
        if (line == null) continue;
        projectedEdges[edge] = line;
      }
      final selectedEdge = AttackGraph3DPicking.nearestConnectionAt(
        projectedConnections: projectedEdges,
        tap: tap,
      );
      if (selectedEdge != null) {
        setState(() {
          _selectedEntity = null;
          _selectedConnection = selectedEdge;
        });
        widget.onEntitySelectionChanged?.call(null);
        widget.onConnectionSelectionChanged?.call(selectedEdge);
        return;
      }
    }
    setState(() {
      _selectedEntity = null;
      _selectedConnection = null;
    });
    widget.onEntitySelectionChanged?.call(null);
    widget.onConnectionSelectionChanged?.call(null);
  }
}

class _RelationshipLegend extends StatelessWidget {
  const _RelationshipLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendEntry(color: Color(0xff4385f5), label: 'Observed'),
        _LegendEntry(
          color: Color(0xffff9a3d),
          label: 'Suspicious',
          dash: true,
        ),
        _LegendEntry(
          color: Color(0xff9a8aae),
          label: 'Hypothesized',
          dash: true,
          shortDash: true,
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    this.dash = false,
    this.shortDash = false,
  });

  final Color color;
  final String label;
  final bool dash;
  final bool shortDash;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(22, 8),
          painter: _LegendLinePainter(
            color: color,
            dash: dash,
            shortDash: shortDash,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({
    required this.color,
    required this.dash,
    required this.shortDash,
  });

  final Color color;
  final bool dash;
  final bool shortDash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (!dash) {
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width, size.height / 2), paint);
      return;
    }
    final dashLength = shortDash ? 5.0 : 6.0;
    for (var x = 0.0; x < size.width; x += dashLength + 3) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + dashLength, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dash != dash ||
      oldDelegate.shortDash != shortDash;
}

class _ProjectedNode {
  const _ProjectedNode(this.entity, this.projection);

  final AttackEntity entity;
  final ProjectedGraphPoint projection;
}

class _ProjectedEdge {
  const _ProjectedEdge(this.connection, this.start, this.end);

  final AttackConnection connection;
  final ProjectedGraphPoint start;
  final ProjectedGraphPoint end;
}

class _AttackGraph3DPainter extends CustomPainter {
  const _AttackGraph3DPainter({
    required this.entities,
    required this.connections,
    required this.positions,
    required this.camera,
    required this.selectedEntityId,
    required this.selectedConnectionId,
    required this.matchingIds,
    required this.showLabels,
    required this.textColor,
    required this.mutedColor,
    required this.nodeFill,
  });

  final List<AttackEntity> entities;
  final List<AttackConnection> connections;
  final Map<String, GraphVector3> positions;
  final AttackGraph3DCamera camera;
  final String? selectedEntityId;
  final String? selectedConnectionId;
  final Set<String> matchingIds;
  final bool showLabels;
  final Color textColor;
  final Color mutedColor;
  final Color nodeFill;

  @override
  void paint(Canvas canvas, Size size) {
    final projectedById = <String, _ProjectedNode>{};
    for (final entity in entities) {
      final point = positions[entity.id];
      if (point == null) continue;
      final projectedPoint = AttackGraph3DProjection.project(
        point: point,
        viewport: size,
        camera: camera,
      );
      if (projectedPoint != null) {
        projectedById[entity.id] = _ProjectedNode(entity, projectedPoint);
      }
    }
    final nodes = projectedById.values.toList()
      ..sort((a, b) => b.projection.depth.compareTo(a.projection.depth));
    final edges = <_ProjectedEdge>[];
    for (final connection in connections) {
      final source = projectedById[connection.sourceEntityId]?.projection;
      final target = projectedById[connection.targetEntityId]?.projection;
      if (source != null && target != null) {
        edges.add(_ProjectedEdge(connection, source, target));
      }
    }
    edges.sort((a, b) {
      final aDepth = (a.start.depth + a.end.depth) / 2;
      final bDepth = (b.start.depth + b.end.depth) / 2;
      return bDepth.compareTo(aDepth);
    });

    for (final edge in edges) {
      _paintEdge(canvas, edge);
    }
    for (final node in nodes) {
      _paintNode(canvas, node);
    }
  }

  void _paintEdge(Canvas canvas, _ProjectedEdge edge) {
    final line = AttackGraph3DPicking.lineFor(edge.start, edge.end);
    if (line == null) return;
    final direction =
        (line.end - line.start) / (line.end - line.start).distance;

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
    if (edge.connection.isDirected) {
      _drawArrow(canvas, line.end, direction, color, selected ? 1.25 : 1);
    }
  }

  void _paintNode(Canvas canvas, _ProjectedNode node) {
    final entity = node.entity;
    final projection = node.projection;
    final center = projection.position;
    final radius = 24 * projection.scale.clamp(.55, 1.5);
    final selected = entity.id == selectedEntityId;
    final matching = matchingIds.contains(entity.id);
    final severityColor = entity.severity.color;

    canvas.drawCircle(
      center + Offset(-radius * .25, -radius * .3),
      radius * .9,
      Paint()
        ..shader = RadialGradient(
          colors: [
            severityColor.withValues(alpha: .22),
            severityColor.withValues(alpha: .03),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = nodeFill
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = severityColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      radius * .18,
      Paint()..color = severityColor,
    );
    if (selected || matching) {
      canvas.drawCircle(
        center,
        radius + (selected ? 6 : 4),
        Paint()
          ..color = selected ? AppColors.orange : AppColors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 2,
      );
    }
    if (showLabels) {
      _drawLabel(
        canvas,
        entity.name,
        center + Offset(0, radius + 7),
        textColor,
        fontSize: _labelSize(projection.scale),
      );
      _drawLabel(
        canvas,
        '${entity.entityType.label} · ${entity.severity.label}',
        center + Offset(0, radius + 20),
        mutedColor,
        fontSize: _labelSize(projection.scale) - 1,
      );
    }
  }

  double _labelSize(double scale) => (11 * scale).clamp(8.0, 12.0);

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

  void _drawArrow(
    Canvas canvas,
    Offset tip,
    Offset direction,
    Color color,
    double scale,
  ) {
    final perpendicular = Offset(-direction.dy, direction.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - direction.dx * 10 * scale + perpendicular.dx * 5 * scale,
        tip.dy - direction.dy * 10 * scale + perpendicular.dy * 5 * scale,
      )
      ..lineTo(
        tip.dx - direction.dx * 10 * scale - perpendicular.dx * 5 * scale,
        tip.dy - direction.dy * 10 * scale - perpendicular.dy * 5 * scale,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 140);
    painter.paint(canvas, center - Offset(painter.width / 2, 6));
  }

  @override
  bool shouldRepaint(covariant _AttackGraph3DPainter oldDelegate) {
    return !listEquals(oldDelegate.entities, entities) ||
        !listEquals(oldDelegate.connections, connections) ||
        !mapEquals(oldDelegate.positions, positions) ||
        oldDelegate.camera != camera ||
        oldDelegate.selectedEntityId != selectedEntityId ||
        oldDelegate.selectedConnectionId != selectedConnectionId ||
        !setEquals(oldDelegate.matchingIds, matchingIds) ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.textColor != textColor ||
        oldDelegate.mutedColor != mutedColor ||
        oldDelegate.nodeFill != nodeFill;
  }
}
