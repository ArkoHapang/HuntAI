import 'package:flutter/material.dart';

import '../../../core/constants/soc_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/demo_data.dart';
import '../../visualizations/services/visualization_data_service.dart';

/// Informational details page for HuntAI's data sources.
///
/// Discloses synthetic data provenance, local in-memory storage,
/// and that HuntAI is not connected to live systems or telemetry feeds.
class DataSourceDetailsScreen extends StatelessWidget {
  const DataSourceDetailsScreen({
    this.onBack,
    super.key,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < SocConstants.compactHeaderBreakpoint;
        final padding = compact ? 16.0 : 24.0;

        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            _buildHeader(context, compact),
            const SizedBox(height: 16),
            const _MonitoringDisclaimerBanner(),
            const SizedBox(height: 16),
            _buildStatusOverviewCard(context, isDark),
            const SizedBox(height: 20),
            Text(
              'Available data categories',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All categories currently populated in the HuntAI SOC demo use deterministic local fixtures.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildAlertsCategoryCard(context),
            const SizedBox(height: 10),
            _buildEventsCategoryCard(context),
            const SizedBox(height: 10),
            _buildEntitiesCategoryCard(context),
            const SizedBox(height: 10),
            _buildRelationshipsCategoryCard(context),
            const SizedBox(height: 20),
            _buildDataProvenanceCard(context),
            const SizedBox(height: 10),
            _buildPersistenceCard(context),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool compact) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Back to settings',
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data source details',
                style: (compact
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Synthetic demo fixtures, provenance disclosure, and telemetry boundaries.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusOverviewCard(BuildContext context, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_outlined,
                    color: AppColors.blue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Environment & pipeline status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const _StatusBadge(
                  label: 'Demo mode',
                  color: AppColors.blue,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const _OverviewRow(
              icon: Icons.source_outlined,
              label: 'Current source',
              value: 'Local synthetic demo fixtures',
              badgeText: 'Synthetic',
              badgeColor: AppColors.blue,
            ),
            const SizedBox(height: 10),
            const _OverviewRow(
              icon: Icons.sensors_off_outlined,
              label: 'Live telemetry',
              value: 'Not connected (no active agent or stream)',
              badgeText: 'Disconnected',
              badgeColor: AppColors.orange,
            ),
            const SizedBox(height: 10),
            const _OverviewRow(
              icon: Icons.memory_outlined,
              label: 'Persistence',
              value: 'In-memory / volatile demo data',
              badgeText: 'Process-local',
              badgeColor: AppColors.purple,
            ),
            const SizedBox(height: 10),
            const _OverviewRow(
              icon: Icons.visibility_off_outlined,
              label: 'Live monitoring',
              value: 'Not monitoring real systems',
              badgeText: 'No live feeds',
              badgeColor: AppColors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCategoryCard(BuildContext context) {
    final alertCount = demoAlerts.length;
    final stages = demoAlerts.map((a) => a.stage).toSet().join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Alerts',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '$alertCount sample alerts',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sample detection alerts representing simulated security incidents across stages: $stages.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final alert in demoAlerts)
                  _InlineFixtureChip(
                    label: '${alert.id} (${alert.severity.label})',
                    tooltip: '${alert.title} · Score: ${alert.score}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsCategoryCard(BuildContext context) {
    final eventCount = demoEvents.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_outlined,
                    color: AppColors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Security events',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '$eventCount sample records',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Simulated raw events including SSH authentication attempts, process command sequences, and sign-ins.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final event in demoEvents)
                  _InlineFixtureChip(
                    label: '${event.$2} [${event.$5}]',
                    tooltip: 'Source: ${event.$3} · Type: ${event.$4}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntitiesCategoryCard(BuildContext context) {
    final entityCount = VisualizationDataService.entities.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category_outlined,
                    color: AppColors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Graph entities',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '$entityCount illustrative nodes',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nodes used in the 2D/3D attack graph representing illustrative entities (external attacker, suspicious IP, user account, workstation, and internal server).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final entity in VisualizationDataService.entities)
                  _InlineFixtureChip(
                    label: '${entity.name} (${entity.id})',
                    tooltip: entity.description,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipsCategoryCard(BuildContext context) {
    final connectionCount = VisualizationDataService.connections.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined,
                    color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Graph relationships',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '$connectionCount illustrative edges',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Directed links connecting the sample attack chain. These illustrate hypothesized or suspicious pivot paths without asserting physical network topology.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final connection in VisualizationDataService.connections)
                  _InlineFixtureChip(
                    label:
                        '${connection.sourceEntityId} → ${connection.targetEntityId}',
                    tooltip: connection.description,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataProvenanceCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: AppColors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Data provenance & synthetic-data disclosure',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'All alerts, telemetry events, graph nodes, and connections displayed across HuntAI are synthetic demonstration fixtures created specifically for UI validation and SOC workflow demonstration.\n\n'
              '• No real corporate network data or endpoint telemetry was collected, analyzed, or stored.\n'
              '• IP addresses (e.g. 203.0.113.42 and 10.0.0.24) and usernames (e.g. analyst-demo) are RFC 5737 documentation-only references or fictional identifiers.\n'
              '• Timeline activity and heatmap metrics are deterministic procedural aggregates designed to validate visualization components.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistenceCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_disabled_outlined,
                    color: AppColors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Persistence boundary',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'HuntAI stores operational state in process memory only. '
              'Reviewed alert markers, created investigation cases, associated graph entities, '
              'analyst notes, and generated hypotheses exist only for the lifespan of this running app process. '
              'Refreshing the browser or closing the application will reset all state back to initial fixture defaults. '
              'No backend, database, local storage, or persistent cache is utilized.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitoringDisclaimerBanner extends StatelessWidget {
  const _MonitoringDisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryCard : const Color(0xFFFFF3E0),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFFFB74D),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demonstration environment only',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.primaryText
                        : const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'HuntAI is currently running as a SOC demonstration platform and is not monitoring real systems. '
                  'No live security telemetry, endpoint monitoring agents, network taps, or sensor collectors are active.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.secondaryText
                        : const Color(0xFF5D4037),
                    height: 1.4,
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

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.badgeText,
    required this.badgeColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String badgeText;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _StatusBadge(label: badgeText, color: badgeColor),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(label: badgeText, color: badgeColor),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineFixtureChip extends StatelessWidget {
  const _InlineFixtureChip({
    required this.label,
    required this.tooltip,
  });

  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
        ),
      ),
    );
  }
}
