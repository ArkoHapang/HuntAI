import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/demo_data.dart';
import '../models/attack_connection.dart';
import '../models/attack_entity.dart';
import '../services/visualization_data_service.dart';
import 'attack_entity_details.dart';

class AttackGraph2D extends StatefulWidget {
  const AttackGraph2D({
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
  State<AttackGraph2D> createState() => _AttackGraph2DState();
}

class _AttackGraph2DState extends State<AttackGraph2D> {
  final _transformController = TransformationController();
  final _searchController = TextEditingController();
  AttackEntity? _selectedEntity;
  AttackConnection? _selectedConnection;
  AttackEntityType? _typeFilter;
  Severity? _severityFilter;
  bool _showLabels = true;
  bool _showConnections = true;
  BoxConstraints? _lastConstraints;

  void _fitToScreen() {
    final viewportWidth = _lastConstraints?.maxWidth ?? 800.0;
    const viewportHeight = 330.0;
    final graphWidth = math.max(800.0, viewportWidth);
    final centerOffsetX = (graphWidth - 800.0) / 2;

    if (widget.entities.isEmpty) {
      _transformController.value = Matrix4.identity();
      return;
    }

    const nodeRadius = 34.0;
    const labelHeight = 70.0;
    const padding = 24.0;

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    for (final entity in widget.entities) {
      if (!entity.x.isFinite || !entity.y.isFinite) continue;
      final x = entity.x + centerOffsetX;
      final y = entity.y;
      minX = math.min(minX, x - nodeRadius - padding);
      maxX = math.max(maxX, x + nodeRadius + padding);
      minY = math.min(minY, y - nodeRadius - padding);
      maxY = math.max(maxY, y + labelHeight + padding);
    }

    if (!minX.isFinite ||
        !maxX.isFinite ||
        minX >= maxX ||
        !minY.isFinite ||
        !maxY.isFinite ||
        minY >= maxY) {
      _transformController.value = Matrix4.identity();
      return;
    }

    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;
    final contentCenterX = (minX + maxX) / 2;
    final contentCenterY = (minY + maxY) / 2;

    final scaleX = viewportWidth / contentWidth;
    final scaleY = viewportHeight / contentHeight;
    final fitScale = math.min(scaleX, scaleY).clamp(0.35, 1.0);

    final tx = viewportWidth / 2 - contentCenterX * fitScale;
    final ty = viewportHeight / 2 - contentCenterY * fitScale;

    setState(() {
      _transformController.value = Matrix4.identity()
        ..translateByDouble(tx, ty, 0.0, 1.0)
        ..scaleByDouble(fitScale, fitScale, fitScale, 1.0);
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
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
    final ids = entities.map((entity) => entity.id).toSet();
    final connections = widget.connections
        .where((connection) =>
            ids.contains(connection.sourceEntityId) &&
            ids.contains(connection.targetEntityId))
        .toList();
    final selectedEntity = entities
        .where((entity) => entity.id == _selectedEntity?.id)
        .firstOrNull;
    final selectedConnection = connections
        .where((edge) => edge.id == _selectedConnection?.id)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Interactive 2D attack graph',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Tooltip(
                  message: 'Reset view',
                  child: OutlinedButton.icon(
                    key: const ValueKey('attack-graph-2d-reset'),
                    onPressed: _fitToScreen,
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    label: const Text('Reset view'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Displaying 5 synthetic demonstration nodes and 4 illustrative paths — none are verified.',
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
                    key: const ValueKey('attack-graph-search'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search entities',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: IconButton(
                        tooltip: 'Clear entity search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<AttackEntityType?>(
                    key: const ValueKey('attack-graph-type-filter'),
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
                    onChanged: (type) => setState(() => _typeFilter = type),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<Severity?>(
                    key: const ValueKey('attack-graph-severity-filter'),
                    initialValue: _severityFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Severity',
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All severities')),
                      for (final severity in Severity.values)
                        DropdownMenuItem(
                          value: severity,
                          child: Text(severity.label),
                        ),
                    ],
                    onChanged: (severity) =>
                        setState(() => _severityFilter = severity),
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
                  onSelected: (value) =>
                      setState(() => _showConnections = value),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _GraphLegend(),
            const SizedBox(height: 10),
            SizedBox(
              height: 330,
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
                            _lastConstraints = constraints;
                            final graphWidth =
                                math.max(800.0, constraints.maxWidth);
                            return InteractiveViewer(
                              transformationController: _transformController,
                              minScale: .35,
                              maxScale: 2.8,
                              boundaryMargin: const EdgeInsets.all(80),
                              constrained: false,
                              child: GestureDetector(
                                key: const ValueKey('attack-graph-canvas'),
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) => _selectAt(
                                  details.localPosition,
                                  entities,
                                  connections,
                                  constraints.maxWidth,
                                ),
                                child: SizedBox(
                                  width: graphWidth,
                                  height: 330,
                                  child: CustomPaint(
                                    painter: _AttackGraphPainter(
                                      entities: entities,
                                      connections: _showConnections
                                          ? connections
                                          : const [],
                                      selectedEntityId: selectedEntity?.id,
                                      selectedConnectionId:
                                          selectedConnection?.id,
                                      showLabels: _showLabels,
                                      textColor: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      mutedColor: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      edgeColor: const Color(0xFF9A8AAE),
                                    ),
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
            AttackEntityDetails(
              entity: selectedEntity,
              connection: selectedConnection,
              entities: entities,
              connections: connections,
            ),
          ],
        ),
      ),
    );
  }

  void _selectAt(
    Offset position,
    List<AttackEntity> entities,
    List<AttackConnection> connections,
    double viewportWidth,
  ) {
    const nodeRadius = 34.0;
    final graphWidth = math.max(800.0, viewportWidth);
    final offsetX = (graphWidth - 800) / 2;
    for (final entity in entities.reversed) {
      final center = Offset(entity.x + offsetX, entity.y);
      if ((position - center).distance <= nodeRadius + 10) {
        setState(() {
          _selectedEntity = entity;
          _selectedConnection = null;
        });
        widget.onEntitySelectionChanged?.call(entity);
        widget.onConnectionSelectionChanged?.call(null);
        return;
      }
    }

    if (_showConnections) {
      for (final connection in connections) {
        final source = entities
            .where((entity) => entity.id == connection.sourceEntityId)
            .firstOrNull;
        final target = entities
            .where((entity) => entity.id == connection.targetEntityId)
            .firstOrNull;
        if (source == null || target == null) continue;
        final start = Offset(source.x + offsetX, source.y);
        final end = Offset(target.x + offsetX, target.y);
        if (_distanceToSegment(position, start, end) <= 12) {
          setState(() {
            _selectedEntity = null;
            _selectedConnection = connection;
          });
          widget.onEntitySelectionChanged?.call(null);
          widget.onConnectionSelectionChanged?.call(connection);
          return;
        }
      }
    }
    setState(() {
      _selectedEntity = null;
      _selectedConnection = null;
    });
    widget.onEntitySelectionChanged?.call(null);
    widget.onConnectionSelectionChanged?.call(null);
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.distanceSquared;
    if (lengthSquared == 0) return (point - start).distance;
    final t =
        (((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
                lengthSquared)
            .clamp(0.0, 1.0);
    return (point - (start + segment * t)).distance;
  }
}

class _GraphLegend extends StatelessWidget {
  const _GraphLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendEntry(color: AppColors.red, label: 'Critical'),
        _LegendEntry(color: AppColors.orange, label: 'High'),
        _LegendEntry(color: AppColors.blue, label: 'Medium'),
        _LegendEntry(color: AppColors.green, label: 'Low'),
        _LegendEntry(color: AppColors.blue, label: 'Observed'),
        _LegendEntry(
          color: AppColors.orange,
          label: 'Suspicious',
          dashed: true,
        ),
        _LegendEntry(
          color: Color(0xFF9A8AAE),
          label: 'Hypothesized',
          dashed: true,
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          child: CustomPaint(
            size: const Size(18, 8),
            painter: _LegendLinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (dashed) {
      canvas.drawLine(
          Offset(0, size.height / 2), Offset(6, size.height / 2), paint);
      canvas.drawLine(
          Offset(10, size.height / 2), Offset(18, size.height / 2), paint);
    } else {
      canvas.drawLine(
          Offset(0, size.height / 2), Offset(18, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

class _AttackGraphPainter extends CustomPainter {
  const _AttackGraphPainter({
    required this.entities,
    required this.connections,
    required this.selectedEntityId,
    required this.selectedConnectionId,
    required this.showLabels,
    required this.textColor,
    required this.mutedColor,
    required this.edgeColor,
  });

  final List<AttackEntity> entities;
  final List<AttackConnection> connections;
  final String? selectedEntityId;
  final String? selectedConnectionId;
  final bool showLabels;
  final Color textColor;
  final Color mutedColor;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerOffset = Offset((size.width - 800) / 2, 0);
    final byId = {for (final entity in entities) entity.id: entity};
    for (final connection in connections) {
      final source = byId[connection.sourceEntityId];
      final target = byId[connection.targetEntityId];
      if (source == null || target == null) continue;
      final start = Offset(source.x, source.y) + centerOffset;
      final end = Offset(target.x, target.y) + centerOffset;
      final direction = (end - start) / (end - start).distance;
      final lineStart = start + direction * 38;
      final lineEnd = end - direction * 42;
      final selected = connection.id == selectedConnectionId;
      final typeStyle = switch (connection.connectionType) {
        AttackConnectionType.observed => (
            color: AppColors.blue,
            dashLength: 0.0,
            gapLength: 0.0,
          ),
        AttackConnectionType.suspicious => (
            color: AppColors.orange,
            dashLength: 7.0,
            gapLength: 4.0,
          ),
        AttackConnectionType.hypothesized => (
            color: edgeColor,
            dashLength: 5.0,
            gapLength: 4.0,
          ),
      };
      final paint = Paint()
        ..color = typeStyle.color
        ..strokeWidth = selected ? 3.5 : 1.8
        ..style = PaintingStyle.stroke;
      final dashPath = Path()
        ..moveTo(lineStart.dx, lineStart.dy)
        ..lineTo(lineEnd.dx, lineEnd.dy);
      if (selected) {
        canvas.drawPath(
          dashPath,
          Paint()
            ..color = typeStyle.color.withValues(alpha: .2)
            ..strokeWidth = 8
            ..style = PaintingStyle.stroke,
        );
      }
      switch (connection.connectionType) {
        case AttackConnectionType.observed:
          canvas.drawPath(dashPath, paint);
          break;
        case AttackConnectionType.suspicious:
          _drawDashed(
            canvas,
            dashPath,
            paint,
            typeStyle.dashLength,
            typeStyle.gapLength,
          );
          break;
        case AttackConnectionType.hypothesized:
          _drawDashed(
            canvas,
            dashPath,
            paint,
            typeStyle.dashLength,
            typeStyle.gapLength,
          );
          break;
      }
      if (connection.isDirected) {
        _drawArrow(canvas, lineEnd, direction, paint.color);
      }
      if (selected) {
        _drawCenteredLabel(
          canvas,
          connection.connectionType.label,
          (lineStart + lineEnd) / 2 + const Offset(0, -13),
          textColor,
          fontSize: 10,
        );
      }
    }

    for (final entity in entities) {
      final center = Offset(entity.x, entity.y) + centerOffset;
      final selected = entity.id == selectedEntityId;
      if (selected) {
        canvas.drawCircle(
          center,
          39,
          Paint()
            ..color = entity.severity.color.withValues(alpha: .18)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        center,
        33,
        Paint()..color = entity.severity.color.withValues(alpha: .17),
      );
      canvas.drawCircle(
        center,
        33,
        Paint()
          ..color = selected ? AppColors.orange : entity.severity.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 2,
      );
      canvas.drawCircle(
        center,
        4,
        Paint()..color = entity.severity.color,
      );
      if (showLabels) {
        _drawCenteredLabel(
          canvas,
          entity.name,
          center + const Offset(0, 48),
          textColor,
          fontSize: 11,
        );
        _drawCenteredLabel(
          canvas,
          entity.entityType.label,
          center + const Offset(0, 63),
          mutedColor,
          fontSize: 9,
        );
      }
    }
  }

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

  void _drawArrow(Canvas canvas, Offset tip, Offset direction, Color color) {
    final perpendicular = Offset(-direction.dy, direction.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - direction.dx * 10 + perpendicular.dx * 5,
        tip.dy - direction.dy * 10 + perpendicular.dy * 5,
      )
      ..lineTo(
        tip.dx - direction.dx * 10 - perpendicular.dx * 5,
        tip.dy - direction.dy * 10 - perpendicular.dy * 5,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawCenteredLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 130);
    painter.paint(canvas, center - Offset(painter.width / 2, 6));
  }

  @override
  bool shouldRepaint(covariant _AttackGraphPainter oldDelegate) =>
      oldDelegate.entities != entities ||
      oldDelegate.connections != connections ||
      oldDelegate.selectedEntityId != selectedEntityId ||
      oldDelegate.selectedConnectionId != selectedConnectionId ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.textColor != textColor ||
      oldDelegate.mutedColor != mutedColor ||
      oldDelegate.edgeColor != edgeColor;
}
