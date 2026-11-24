import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/demo_data.dart';
import '../models/visualization_data.dart';
import '../services/visualization_data_service.dart';
import 'visualization_legend.dart';

class ThreatActivityChart extends StatefulWidget {
  const ThreatActivityChart({
    this.service = const VisualizationDataService(),
    this.isLoading = false,
    super.key,
  });

  final VisualizationDataService service;
  final bool isLoading;

  @override
  State<ThreatActivityChart> createState() => _ThreatActivityChartState();
}

class _ThreatActivityChartState extends State<ThreatActivityChart> {
  static const _ranges = ['1h', '24h', '7d', '30d'];
  String _range = '24h';
  final Set<Severity> _visibleSeries = Severity.values.toSet();
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final points = widget.service.timeline(_range);
    final notableShiftIndex = _notableShiftIndex(points);
    final notableShift = notableShiftIndex == null
        ? null
        : points[notableShiftIndex].total - points[notableShiftIndex - 1].total;
    final selected = _selectedIndex != null && _selectedIndex! < points.length
        ? points[_selectedIndex!]
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Threat activity timeline',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const Tooltip(
                  message:
                      'Synthetic historical aggregates; not live telemetry.',
                  child: Icon(Icons.info_outline, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Illustrative historical activity · synthetic demo data',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              children: [
                for (final range in _ranges)
                  ChoiceChip(
                    label: Text(range),
                    selected: _range == range,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      _range = range;
                      _selectedIndex = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            VisualizationLegend(
              severities: Severity.values,
              selected: _visibleSeries,
              onSelected: (severity) => setState(() {
                if (!_visibleSeries.add(severity)) {
                  _visibleSeries.remove(severity);
                }
              }),
            ),
            if (notableShiftIndex != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Largest change in demo series: ${points[notableShiftIndex].label} · ${notableShift! >= 0 ? '+' : ''}$notableShift events',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.orange,
                      ),
                ),
              ),
            const SizedBox(height: 12),
            if (widget.isLoading)
              const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (points.isEmpty)
              const _ChartMessage(
                icon: Icons.timeline_outlined,
                message: 'No timeline data for this range.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartHeight =
                      constraints.maxWidth < 420 ? 185.0 : 220.0;
                  return GestureDetector(
                    key: const ValueKey('threat-timeline-plot'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final plotWidth = constraints.maxWidth - 44;
                      final localX = details.localPosition.dx - 40;
                      final ratio = (localX / plotWidth).clamp(0.0, 1.0);
                      setState(() {
                        _selectedIndex = (ratio * (points.length - 1)).round();
                      });
                    },
                    child: SizedBox(
                      height: chartHeight,
                      width: constraints.maxWidth,
                      child: CustomPaint(
                        painter: _TimelinePainter(
                          points: points,
                          visible: _visibleSeries.toSet(),
                          selectedIndex: _selectedIndex,
                          notableShiftIndex: notableShiftIndex,
                          textColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          gridColor: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 9),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: selected == null
                  ? Text(
                      'Select a point to inspect counts.',
                      key: const ValueKey('timeline-empty-selection'),
                      style: Theme.of(context).textTheme.labelSmall,
                    )
                  : Wrap(
                      key: ValueKey('timeline-selection-${selected.label}'),
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          selected.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        for (final severity in Severity.values)
                          Text(
                            '${severity.label} ${selected.counts[severity] ?? 0}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: severity.color),
                          ),
                        Text(
                          'Total ${selected.total}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int? _notableShiftIndex(List<TimelinePoint> points) {
    if (points.length < 2) return null;
    var largestIndex = 1;
    var largestChange = -1;
    for (var index = 1; index < points.length; index++) {
      final change = (points[index].total - points[index - 1].total).abs();
      if (change > largestChange) {
        largestChange = change;
        largestIndex = index;
      }
    }
    return largestIndex;
  }
}

class _ChartMessage extends StatelessWidget {
  const _ChartMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).disabledColor),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.points,
    required this.visible,
    required this.selectedIndex,
    required this.notableShiftIndex,
    required this.textColor,
    required this.gridColor,
  });

  final List<TimelinePoint> points;
  final Set<Severity> visible;
  final int? selectedIndex;
  final int? notableShiftIndex;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const right = 8.0;
    const top = 10.0;
    const bottom = 25.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxValue = points
        .map((point) => point.counts.values.fold<int>(
              0,
              (largest, value) => largest > value ? largest : value,
            ))
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 100000);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .55)
      ..strokeWidth = 1;
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    for (var row = 0; row <= 4; row++) {
      final y = plot.top + plot.height * row / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final label = ((maxValue * (4 - row)) / 4).round().toString();
      labelPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: textColor, fontSize: 10),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(0, y - labelPainter.height / 2));
    }

    final stepX = points.length == 1 ? 0.0 : plot.width / (points.length - 1);
    if (notableShiftIndex != null && notableShiftIndex! < points.length) {
      final x = plot.left + stepX * notableShiftIndex!;
      final markerPaint = Paint()
        ..color = AppColors.orange.withValues(alpha: .75)
        ..strokeWidth = 1.4;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), markerPaint);
      canvas.drawCircle(
        Offset(x, plot.top),
        3,
        Paint()..color = AppColors.orange,
      );
    }

    for (final severity in Severity.values) {
      if (!visible.contains(severity)) continue;
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final value = points[index].counts[severity] ?? 0;
        final x = plot.left + stepX * index;
        final y = plot.bottom - plot.height * value / maxValue;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = severity.color
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var index = 0; index < points.length; index++) {
        final value = points[index].counts[severity] ?? 0;
        final point = Offset(
          plot.left + stepX * index,
          plot.bottom - plot.height * value / maxValue,
        );
        canvas.drawCircle(point, 3.2, Paint()..color = severity.color);
      }
    }

    if (selectedIndex != null && selectedIndex! < points.length) {
      final x = plot.left + stepX * selectedIndex!;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = AppColors.primaryText.withValues(alpha: .55)
          ..strokeWidth = 1,
      );
      for (final severity in Severity.values) {
        if (!visible.contains(severity)) continue;
        final value = points[selectedIndex!].counts[severity] ?? 0;
        final y = plot.bottom - plot.height * value / maxValue;
        canvas.drawCircle(
          Offset(x, y),
          5,
          Paint()
            ..color = severity.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    final labelIndices = <int>{0, points.length ~/ 2, points.length - 1};
    for (final index in labelIndices) {
      final label = points[index].label;
      labelPainter.text = TextSpan(
          text: label, style: TextStyle(color: textColor, fontSize: 9));
      labelPainter.layout();
      final x = (plot.left + stepX * index - labelPainter.width / 2)
          .clamp(plot.left, plot.right - labelPainter.width);
      labelPainter.paint(canvas, Offset(x, plot.bottom + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.visible != visible ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.notableShiftIndex != notableShiftIndex ||
      oldDelegate.textColor != textColor ||
      oldDelegate.gridColor != gridColor;
}
