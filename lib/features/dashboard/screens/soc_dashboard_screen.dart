import 'package:flutter/material.dart';

import '../../../core/constants/soc_constants.dart';
import '../../../data/demo_data.dart';
import '../../../shared/widgets/demo_banner.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/recent_incidents_panel.dart';
import '../widgets/security_events_card.dart';
import '../widgets/security_score_card.dart';
import '../widgets/security_tools_panel.dart';
import '../widgets/system_health_card.dart';
import '../widgets/threat_detection_card.dart';
import '../widgets/vulnerability_card.dart';

class SocDashboardScreen extends StatefulWidget {
  const SocDashboardScreen({
    required this.reviewedAlerts,
    required this.selectedSeverity,
    required this.onSeverityChanged,
    required this.onReview,
    required this.onOpenAlerts,
    required this.searchQuery,
    super.key,
  });

  final Set<String> reviewedAlerts;
  final Severity? selectedSeverity;
  final ValueChanged<Severity?> onSeverityChanged;
  final ValueChanged<SecurityAlert> onReview;
  final VoidCallback onOpenAlerts;
  final String searchQuery;

  @override
  State<SocDashboardScreen> createState() => _SocDashboardScreenState();
}

class _SocDashboardScreenState extends State<SocDashboardScreen> {
  String _selectedRange = '24h';

  @override
  Widget build(BuildContext context) {
    final alerts = demoAlerts.where(_matchesFilters).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final horizontalPadding =
            maxWidth < SocConstants.narrowPageBreakpoint ? 16.0 : 24.0;
        final contentWidth = maxWidth - horizontalPadding * 2;
        final columns = contentWidth >= SocConstants.threeColumnBreakpoint
            ? 3
            : contentWidth >= SocConstants.twoColumnBreakpoint
                ? 2
                : 1;
        const gap = 14.0;
        final cardWidth = (contentWidth - gap * (columns - 1)) / columns;

        return ListView(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 22, horizontalPadding, 28),
          children: [
            DashboardHeader(
              selectedRange: _selectedRange,
              selectedSeverity: widget.selectedSeverity,
              onRangeChanged: (range) => setState(() => _selectedRange = range),
              onSeverityChanged: widget.onSeverityChanged,
              onRefresh: () => _showMessage(
                'Sample data is static; there is nothing to refresh.',
              ),
              onExport: () => _showMessage(
                'Report export is unavailable in this demo.',
              ),
            ),
            const SizedBox(height: 16),
            const DemoNotice(),
            const SizedBox(height: 18),
            _responsiveRow(
              contentWidth: contentWidth,
              gap: gap,
              cards: [
                ThreatDetectionCard(alerts: alerts),
                const SecurityEventsCard(),
                const SystemHealthCard(),
              ],
              flexes: const [1, 1, 1],
              cardWidth: cardWidth,
            ),
            const SizedBox(height: 14),
            _responsiveRow(
              contentWidth: contentWidth,
              gap: gap,
              cards: [
                const SecurityScoreCard(),
                RecentIncidentsPanel(
                  alerts: alerts,
                  reviewedAlerts: widget.reviewedAlerts,
                  onReview: widget.onReview,
                  onOpenAlerts: widget.onOpenAlerts,
                ),
              ],
              flexes: const [1, 2],
              cardWidth: cardWidth,
            ),
            const SizedBox(height: 14),
            _responsiveRow(
              contentWidth: contentWidth,
              gap: gap,
              cards: const [
                SecurityToolsPanel(),
                VulnerabilityCard(),
              ],
              flexes: const [1, 1],
              cardWidth: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _responsiveRow({
    required double contentWidth,
    required double gap,
    required List<Widget> cards,
    required List<int> flexes,
    required double cardWidth,
  }) {
    if (contentWidth >= SocConstants.threeColumnBreakpoint &&
        cards.length == flexes.length) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(flex: flexes[index], child: cards[index]),
              if (index != cards.length - 1) SizedBox(width: gap),
            ],
          ],
        ),
      );
    }

    final availableColumns =
        contentWidth >= SocConstants.twoColumnBreakpoint ? 2 : 1;
    final responsiveCardWidth =
        (contentWidth - gap * (availableColumns - 1)) / availableColumns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final card in cards)
          SizedBox(width: responsiveCardWidth, child: card),
      ],
    );
  }

  bool _matchesFilters(SecurityAlert alert) {
    if (widget.selectedSeverity != null &&
        alert.severity != widget.selectedSeverity) {
      return false;
    }
    if (_alertAgeMinutes(alert) > _rangeInMinutes(_selectedRange)) {
      return false;
    }
    final query = widget.searchQuery.trim().toLowerCase();
    return query.isEmpty ||
        alert.title.toLowerCase().contains(query) ||
        alert.id.toLowerCase().contains(query) ||
        alert.source.toLowerCase().contains(query) ||
        alert.stage.toLowerCase().contains(query);
  }

  int _alertAgeMinutes(SecurityAlert alert) {
    final match = RegExp(r'^(\d+)\s+(minute|hour|day)').firstMatch(alert.time);
    if (match == null) return 1 << 30;
    final amount = int.parse(match.group(1)!);
    switch (match.group(2)) {
      case 'minute':
        return amount;
      case 'hour':
        return amount * 60;
      case 'day':
        return amount * 1440;
      default:
        return 1 << 30;
    }
  }

  int _rangeInMinutes(String range) {
    switch (range) {
      case '1h':
        return 60;
      case '24h':
        return 1440;
      case '7d':
        return 7 * 1440;
      case '30d':
        return 30 * 1440;
      default:
        return 1440;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
