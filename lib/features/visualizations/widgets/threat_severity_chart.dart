import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/demo_data.dart';
import '../services/visualization_data_service.dart';
import 'visualization_legend.dart';

class ThreatSeverityChart extends StatelessWidget {
  const ThreatSeverityChart({
    required this.selectedSeverity,
    required this.onSeveritySelected,
    this.service = const VisualizationDataService(),
    super.key,
  });

  final Severity? selectedSeverity;
  final ValueChanged<Severity?> onSeveritySelected;
  final VisualizationDataService service;

  @override
  Widget build(BuildContext context) {
    final counts = service.severityCounts(demoAlerts);
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    final selectedCount =
        selectedSeverity == null ? total : counts[selectedSeverity] ?? 0;
    final percentage = total == 0 ? 0 : (selectedCount * 100 / total).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Threat severity distribution',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Based on the existing sample alerts',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            if (total == 0)
              const SizedBox(
                height: 180,
                child: Center(child: Text('No alerts to display.')),
              )
            else
              Center(
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: GestureDetector(
                    key: const ValueKey('severity-doughnut'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final point = details.localPosition;
                      const center = Offset(95, 95);
                      final delta = point - center;
                      final radius = delta.distance;
                      if (radius < 43 || radius > 94) {
                        onSeveritySelected(null);
                        return;
                      }
                      final angle =
                          (math.atan2(delta.dy, delta.dx) + math.pi / 2) %
                              (2 * math.pi);
                      var current = 0.0;
                      for (final severity in Severity.values.reversed) {
                        final sweep =
                            (counts[severity] ?? 0) / total * 2 * math.pi;
                        if (angle >= current && angle < current + sweep) {
                          onSeveritySelected(
                            selectedSeverity == severity ? null : severity,
                          );
                          return;
                        }
                        current += sweep;
                      }
                    },
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 220),
                      tween: Tween<double>(
                        begin: 0,
                        end: selectedSeverity == null ? 0 : 1,
                      ),
                      builder: (context, selectionProgress, _) => CustomPaint(
                        painter: _DoughnutPainter(
                          counts: counts,
                          selectedSeverity: selectedSeverity,
                          selectionProgress: selectionProgress,
                          centerText: selectedSeverity?.label ?? 'Total',
                          centerValue: selectedSeverity == null
                              ? '$total'
                              : '$selectedCount · $percentage%',
                          background: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          textColor: Theme.of(context).colorScheme.onSurface,
                          secondaryTextColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            VisualizationLegend(
              severities: Severity.values,
              selected: selectedSeverity == null ? null : {selectedSeverity!},
              onSelected: (severity) => onSeveritySelected(
                selectedSeverity == severity ? null : severity,
              ),
            ),
            const SizedBox(height: 12),
            for (final severity in Severity.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(severity.label,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Text(
                      '${counts[severity] ?? 0} · ${total == 0 ? 0 : ((counts[severity] ?? 0) * 100 / total).round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: severity.color),
                    ),
                  ],
                ),
              ),
            if (selectedSeverity != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => onSeveritySelected(null),
                child: const Text('Clear severity filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoughnutPainter extends CustomPainter {
  const _DoughnutPainter({
    required this.counts,
    required this.selectedSeverity,
    required this.selectionProgress,
    required this.centerText,
    required this.centerValue,
    required this.background,
    required this.textColor,
    required this.secondaryTextColor,
  });

  final Map<Severity, int> counts;
  final Severity? selectedSeverity;
  final double selectionProgress;
  final String centerText;
  final String centerValue;
  final Color background;
  final Color textColor;
  final Color secondaryTextColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 22.0;
    final rect = Rect.fromCircle(center: center, radius: 72);
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (total > 0) {
      var start = -math.pi / 2;
      for (final severity in Severity.values.reversed) {
        final count = counts[severity] ?? 0;
        if (count == 0) continue;
        final sweep = count / total * math.pi * 2;
        final isSelected = selectedSeverity == severity;
        final inset = isSelected ? 3.0 * selectionProgress : 0.0;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: 72 - inset),
          start,
          sweep - .025,
          false,
          Paint()
            ..color = severity.color.withValues(
              alpha: selectedSeverity == null || isSelected ? 1 : .3,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt,
        );
        start += sweep;
      }
    }

    final valuePainter = TextPainter(
      text: TextSpan(
        text: centerValue,
        style: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 105);
    valuePainter.paint(
      canvas,
      Offset(center.dx - valuePainter.width / 2, center.dy - 12),
    );
    final labelPainter = TextPainter(
      text: TextSpan(
        text: centerText,
        style: TextStyle(
          color: secondaryTextColor,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 100);
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, center.dy + 13),
    );
  }

  @override
  bool shouldRepaint(covariant _DoughnutPainter oldDelegate) =>
      oldDelegate.counts != counts ||
      oldDelegate.selectedSeverity != selectedSeverity ||
      oldDelegate.selectionProgress != selectionProgress ||
      oldDelegate.centerText != centerText ||
      oldDelegate.centerValue != centerValue ||
      oldDelegate.background != background ||
      oldDelegate.textColor != textColor ||
      oldDelegate.secondaryTextColor != secondaryTextColor;
}
