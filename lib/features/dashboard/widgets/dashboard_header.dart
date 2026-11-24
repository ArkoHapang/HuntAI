import 'package:flutter/material.dart';

import '../../../core/constants/soc_constants.dart';
import '../../../data/demo_data.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.selectedRange,
    required this.selectedSeverity,
    required this.onRangeChanged,
    required this.onSeverityChanged,
    required this.onRefresh,
    required this.onExport,
    super.key,
  });

  final String selectedRange;
  final Severity? selectedSeverity;
  final ValueChanged<String> onRangeChanged;
  final ValueChanged<Severity?> onSeverityChanged;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  static const _ranges = ['1h', '24h', '7d', '30d'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headingWidth =
        MediaQuery.sizeOf(context).width < SocConstants.compactHeaderBreakpoint
            ? double.infinity
            : 430.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 14,
          spacing: 16,
          children: [
            SizedBox(
              width: headingWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Security Operations Center',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 5),
                  Text(
                    'Threat monitoring and security intelligence overview.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export report'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 17),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _MonitoringStatus(),
            const SizedBox(width: 4),
            for (final range in _ranges)
              ChoiceChip(
                label: Text(range),
                selected: selectedRange == range,
                onSelected: (_) => onRangeChanged(range),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Severity', style: theme.textTheme.labelMedium),
            ChoiceChip(
              label: const Text('All'),
              selected: selectedSeverity == null,
              onSelected: (_) => onSeverityChanged(null),
              visualDensity: VisualDensity.compact,
            ),
            for (final severity in Severity.values)
              ChoiceChip(
                label: Text(severity.label),
                selected: selectedSeverity == severity,
                onSelected: (_) => onSeverityChanged(severity),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Demo data only · the range filters sample alerts; telemetry counts stay static.',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _MonitoringStatus extends StatelessWidget {
  const _MonitoringStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x1AFF851B),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'DEMO',
              style: TextStyle(
                color: Color(0xFFFF851B),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.circle, size: 8, color: Color(0xFFFF851B)),
          const SizedBox(width: 7),
          Text('Sample environment',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
