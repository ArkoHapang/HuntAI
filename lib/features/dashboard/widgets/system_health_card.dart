import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'dashboard_panel.dart';

class SystemHealthCard extends StatelessWidget {
  const SystemHealthCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardPanel(
      title: 'System health',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        children: [
          _ServiceStatus(label: 'Detection engine', status: 'Not connected'),
          SizedBox(height: 12),
          _ServiceStatus(label: 'Telemetry pipeline', status: 'Sample data'),
          SizedBox(height: 12),
          _ServiceStatus(label: 'ML model', status: 'Not connected'),
        ],
      ),
    );
  }
}

class _ServiceStatus extends StatelessWidget {
  const _ServiceStatus({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 8, color: AppColors.orange),
        const SizedBox(width: 9),
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Flexible(
          child: Text(
            status,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
