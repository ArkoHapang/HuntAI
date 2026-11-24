import 'package:flutter/material.dart';

import '../../../data/demo_data.dart';
import 'dashboard_panel.dart';

class RecentIncidentsPanel extends StatelessWidget {
  const RecentIncidentsPanel({
    required this.alerts,
    required this.reviewedAlerts,
    required this.onReview,
    required this.onOpenAlerts,
    super.key,
  });

  final List<SecurityAlert> alerts;
  final Set<String> reviewedAlerts;
  final ValueChanged<SecurityAlert> onReview;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Recent security incidents',
      icon: Icons.warning_amber_rounded,
      trailing: TextButton(
        onPressed: onOpenAlerts,
        child: const Text('All alerts'),
      ),
      child: alerts.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No sample alerts match the current filters.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < alerts.length; index++) ...[
                  _IncidentRow(
                    alert: alerts[index],
                    reviewed: reviewedAlerts.contains(alerts[index].id),
                    onReview: () => onReview(alerts[index]),
                    onSelect: onOpenAlerts,
                  ),
                  if (index != alerts.length - 1) const Divider(height: 20),
                ],
              ],
            ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({
    required this.alert,
    required this.reviewed,
    required this.onReview,
    required this.onSelect,
  });

  final SecurityAlert alert;
  final bool reviewed;
  final VoidCallback onReview;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final severityColor = alert.severity.color;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 6),
              decoration:
                  BoxDecoration(color: severityColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${alert.source} · ${alert.time}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        alert.severity.label.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: severityColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                            ),
                      ),
                      Text(
                        reviewed ? 'Reviewed' : 'Needs review',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: reviewed ? 'Reopen alert' : 'Mark alert reviewed',
              onPressed: onReview,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                reviewed ? Icons.undo : Icons.check_circle_outline,
                size: 20,
                color: reviewed ? null : severityColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
