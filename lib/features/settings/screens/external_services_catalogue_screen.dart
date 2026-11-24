import 'package:flutter/material.dart';

import '../../../core/constants/soc_constants.dart';
import '../../../core/theme/app_colors.dart';

/// Informational catalogue for HuntAI's external integrations and services.
///
/// Clearly distinguishes implemented reference functionality (MITRE ATT&CK)
/// from unconfigured future integrations (VirusTotal, External AI, Live SIEM).
class ExternalServicesCatalogueScreen extends StatelessWidget {
  const ExternalServicesCatalogueScreen({
    this.onBack,
    super.key,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            const _ArchitectureDisclosureBanner(),
            const SizedBox(height: 16),
            Text(
              'Integrated & catalogued services',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Overview of third-party reference models, threat intelligence, AI engines, and SIEM connectors.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            const _ServiceCatalogueCard(
              title: 'MITRE ATT&CK',
              purpose: 'ATT&CK technique references.',
              status: 'Reference support exists',
              isImplemented: true,
              statusColor: AppColors.blue,
              icon: Icons.security_outlined,
              limitation: 'Default verification is unavailable.',
              details:
                  'Domain models support associating analyst-proposed MITRE ATT&CK technique IDs (e.g., T1078, T1059) with investigation hypotheses and evidence. '
                  'However, runtime verification uses UnavailableMitreReferenceVerifier because no authoritative offline catalog is bundled and network access is disabled.',
            ),
            const SizedBox(height: 12),
            const _ServiceCatalogueCard(
              title: 'VirusTotal',
              purpose: 'Threat-intelligence enrichment.',
              status: 'Not configured',
              isImplemented: false,
              statusColor: AppColors.orange,
              icon: Icons.travel_explore_outlined,
              limitation: 'No API integration or live lookups.',
              details:
                  'Observable reputation lookups (file hashes, suspicious IP addresses, domains) are not connected. '
                  'No API keys are requested or stored, and no external queries are dispatched.',
            ),
            const SizedBox(height: 12),
            const _ServiceCatalogueCard(
              title: 'External AI provider',
              purpose: 'External AI-powered hypothesis generation.',
              status: 'Not configured',
              isImplemented: false,
              statusColor: AppColors.orange,
              icon: Icons.auto_awesome_outlined,
              limitation:
                  'Current hypothesis generation is deterministic and local.',
              details:
                  'Investigation hypotheses are generated locally via DeterministicMockHypothesisGenerator based on analyst evidence cues and graph references. '
                  'No external cloud LLM, OpenAI, Anthropic, or Gemini inference API is connected.',
            ),
            const SizedBox(height: 12),
            const _ServiceCatalogueCard(
              title: 'Live SIEM integration',
              purpose: 'Import real security events.',
              status: 'Not configured',
              isImplemented: false,
              statusColor: AppColors.orange,
              icon: Icons.hub_outlined,
              limitation: 'No live SIEM connection.',
              details:
                  'Connectors for live SIEM / data lake solutions (Splunk, Elastic, Microsoft Sentinel) are not configured. '
                  'The SOC dashboard and telemetry view operate strictly from synthetic local demo fixtures.',
            ),
            const SizedBox(height: 20),
            _buildSecurityPolicyCard(context),
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
                'External services catalogue',
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
                'Review integrated reference models, status indicators, and service limitations.',
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

  Widget _buildSecurityPolicyCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Integration security & credential boundary',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'HuntAI strictly adheres to an air-gapped demo architecture:\n\n'
              '• No external network traffic is generated or accepted by the platform.\n'
              '• No third-party API credentials, secrets, or tokens are collected, requested, or persisted.\n'
              '• All operations remain process-local to ensure zero telemetry leakage and complete isolation.',
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

class _ArchitectureDisclosureBanner extends StatelessWidget {
  const _ArchitectureDisclosureBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryCard : const Color(0xFFF0F4F8),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFCFD8DC),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.blue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active external connections',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.primaryText
                        : const Color(0xFF263238),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Third-party cloud APIs and streaming ingest pipelines are intentionally unconfigured. '
                  'The catalogue below documents existing data models alongside planned future integration points.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.secondaryText
                        : const Color(0xFF455A64),
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

class _ServiceCatalogueCard extends StatelessWidget {
  const _ServiceCatalogueCard({
    required this.title,
    required this.purpose,
    required this.status,
    required this.isImplemented,
    required this.statusColor,
    required this.icon,
    required this.limitation,
    required this.details,
  });

  final String title;
  final String purpose;
  final String status;
  final bool isImplemented;
  final Color statusColor;
  final IconData icon;
  final String limitation;
  final String details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 440;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ServiceStatusChip(
                    label: status,
                    color: statusColor,
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _ServiceStatusChip(
                        label: status,
                        color: statusColor,
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                _LabeledField(label: 'Purpose', value: purpose),
                const SizedBox(height: 8),
                _LabeledField(label: 'Status', value: status),
                const SizedBox(height: 8),
                _LabeledField(
                  label: 'Limitation',
                  value: limitation,
                  highlight: true,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                  color: highlight
                      ? (theme.brightness == Brightness.dark
                          ? const Color(0xFFFFB74D)
                          : const Color(0xFFD84315))
                      : null,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                '$label:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                  color: highlight
                      ? (theme.brightness == Brightness.dark
                          ? const Color(0xFFFFB74D)
                          : const Color(0xFFD84315))
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ServiceStatusChip extends StatelessWidget {
  const _ServiceStatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
