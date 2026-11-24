import 'package:flutter/material.dart';

import 'dashboard_panel.dart';

class SecurityToolsPanel extends StatelessWidget {
  const SecurityToolsPanel({super.key});

  static const _tools = [
    ('SIEM monitoring', 'Not connected'),
    ('Behavioral detection', 'Planned'),
    ('Anomaly detection', 'Not connected'),
    ('Threat intelligence', 'Not connected'),
    ('Attack chain analysis', 'Demo'),
    ('Investigation tools', 'Demo'),
  ];

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      title: 'Security tools',
      icon: Icons.build_outlined,
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          for (final tool in _tools)
            Container(
              constraints: const BoxConstraints(minWidth: 140),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.$1, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    tool.$2,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
