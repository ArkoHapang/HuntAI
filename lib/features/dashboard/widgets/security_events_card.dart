import 'package:flutter/material.dart';

import '../../../data/demo_data.dart';
import 'dashboard_panel.dart';

class SecurityEventsCard extends StatelessWidget {
  const SecurityEventsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final authenticationCount =
        demoEvents.where((event) => event.$4 == 'Authentication').length;
    final systemCount =
        demoEvents.where((event) => event.$4 == 'System').length;

    return DashboardPanel(
      title: 'Security events',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${demoEvents.length}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text('sample telemetry records',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          _EventCategory(
            label: 'Authentication',
            count: authenticationCount,
            total: demoEvents.length,
          ),
          const SizedBox(height: 11),
          _EventCategory(
              label: 'System', count: systemCount, total: demoEvents.length),
          const SizedBox(height: 13),
          Text(
            'Static fixtures · no live ingestion',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _EventCategory extends StatelessWidget {
  const _EventCategory({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodySmall)),
            Text('$count', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: count / total,
            minHeight: 5,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}
