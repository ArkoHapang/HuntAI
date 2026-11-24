import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/demo_data.dart';
import 'dashboard_panel.dart';

class ThreatDetectionCard extends StatelessWidget {
  const ThreatDetectionCard({
    required this.alerts,
    super.key,
  });

  final List<SecurityAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final critical =
        alerts.where((alert) => alert.severity == Severity.critical).length;
    final high =
        alerts.where((alert) => alert.severity == Severity.high).length;
    final medium =
        alerts.where((alert) => alert.severity == Severity.medium).length;
    final low = alerts.where((alert) => alert.severity == Severity.low).length;

    return DashboardPanel(
      title: 'Threat detection',
      icon: Icons.shield_outlined,
      trailing: const _DemoTag(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${alerts.length}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            'matching sample alerts',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _SeverityCount(
                  label: 'Critical', count: critical, color: AppColors.red),
              _SeverityCount(
                  label: 'High', count: high, color: AppColors.orange),
              _SeverityCount(
                  label: 'Medium', count: medium, color: AppColors.blue),
              _SeverityCount(label: 'Low', count: low, color: AppColors.green),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoTag extends StatelessWidget {
  const _DemoTag();

  @override
  Widget build(BuildContext context) {
    return Text(
      'DEMO',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
    );
  }
}

class _SeverityCount extends StatelessWidget {
  const _SeverityCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label $count', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
