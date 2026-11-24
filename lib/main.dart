import 'package:flutter/material.dart';

import 'core/constants/soc_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/demo_data.dart';
import 'features/dashboard/screens/soc_dashboard_screen.dart';
import 'features/investigations/presentation/investigation_feature_dependencies.dart';
import 'features/investigations/presentation/screens/investigation_management_screen.dart';
import 'features/settings/screens/data_source_details_screen.dart';
import 'features/settings/screens/external_services_catalogue_screen.dart';
import 'features/visualizations/screens/visualization_workspace.dart';
import 'shared/widgets/demo_banner.dart';
import 'shared/widgets/soc_sidebar.dart';
import 'shared/widgets/soc_top_nav.dart';

export 'features/settings/screens/data_source_details_screen.dart';
export 'features/settings/screens/external_services_catalogue_screen.dart';

void main() => runApp(const HuntAiApp());

const _blue = AppColors.blue;
const _green = AppColors.green;

final ValueNotifier<ThemeMode> _themeMode =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

class HuntAiApp extends StatelessWidget {
  const HuntAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'HuntAI',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HuntAiHome(),
      ),
    );
  }
}

class HuntAiHome extends StatefulWidget {
  const HuntAiHome({super.key});

  @override
  State<HuntAiHome> createState() => _HuntAiHomeState();
}

class _HuntAiHomeState extends State<HuntAiHome> {
  int _selectedPage = 0;
  Severity? _selectedSeverity;
  String _searchQuery = '';
  final Set<String> _reviewedAlerts = {};

  static const _pages = [
    'Dashboard',
    'Threat analysis',
    'Alerts',
    'Telemetry',
    'Attack chain',
    'Investigations',
    'Settings'
  ];

  late final InvestigationFeatureDependencies _investigationDependencies;
  String? _selectedInvestigationId;
  String? _graphAssociationInvestigationId;

  @override
  void initState() {
    super.initState();
    _investigationDependencies =
        InvestigationFeatureDependencies.inMemoryDemo();
  }

  @override
  void dispose() {
    _investigationDependencies.dispose();
    super.dispose();
  }

  void _markReviewed(SecurityAlert alert) {
    setState(() {
      if (!_reviewedAlerts.add(alert.id)) {
        _reviewedAlerts.remove(alert.id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _reviewedAlerts.contains(alert.id)
              ? '${alert.id} marked reviewed'
              : '${alert.id} reopened',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < SocConstants.mobileBreakpoint;
    final hasSidebar = !isMobile;
    final activeAlerts =
        demoAlerts.where((alert) => !_reviewedAlerts.contains(alert.id)).length;
    final page = _buildPage();

    return Scaffold(
      drawer: isMobile
          ? Drawer(
              width: 280,
              child: SocSidebar(
                selectedIndex: _selectedPage,
                expanded: true,
                onDestinationSelected: (index) {
                  setState(() => _selectedPage = index);
                  Navigator.of(context).pop();
                },
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (hasSidebar)
              SocSidebar(
                selectedIndex: _selectedPage,
                expanded: width >= SocConstants.desktopBreakpoint,
                onDestinationSelected: (index) =>
                    setState(() => _selectedPage = index),
              ),
            Expanded(
              child: Column(
                children: [
                  Builder(
                    builder: (scaffoldContext) => SocTopNav(
                      title: _pages[_selectedPage],
                      isDark: Theme.of(context).brightness == Brightness.dark,
                      unreadCount: activeAlerts,
                      showMenuButton: isMobile,
                      onMenuTap: () =>
                          Scaffold.of(scaffoldContext).openDrawer(),
                      onThemeTap: () => setState(() {
                        _themeMode.value =
                            Theme.of(context).brightness == Brightness.dark
                                ? ThemeMode.light
                                : ThemeMode.dark;
                      }),
                      onAlertsTap: () => setState(() => _selectedPage = 2),
                      onSettingsTap: () => setState(() => _selectedPage = 6),
                      onThreatAnalysisTap: () =>
                          setState(() => _selectedPage = 1),
                      onSearch: (query) => setState(() {
                        _searchQuery = query;
                        _selectedPage = 0;
                      }),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: SocConstants.maxContentWidth,
                        ),
                        child: page,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isMobile
          ? null
          : NavigationBar(
              selectedIndex: _selectedPage,
              onDestinationSelected: (index) => setState(
                () => _selectedPage = index,
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.query_stats_outlined),
                  label: 'Analysis',
                ),
                NavigationDestination(
                  icon: Icon(Icons.warning_amber_rounded),
                  label: 'Alerts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Telemetry',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  label: 'Chain',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_open_outlined),
                  label: 'Investigations',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  Widget _buildPage() {
    switch (_selectedPage) {
      case 0:
        return SocDashboardScreen(
          reviewedAlerts: _reviewedAlerts,
          selectedSeverity: _selectedSeverity,
          onSeverityChanged: (severity) =>
              setState(() => _selectedSeverity = severity),
          onOpenAlerts: () => setState(() => _selectedPage = 2),
          onReview: _markReviewed,
          searchQuery: _searchQuery,
        );
      case 1:
        return VisualizationWorkspace(
          selectedSeverity: _selectedSeverity,
          onSeverityChanged: (severity) =>
              setState(() => _selectedSeverity = severity),
          associationInvestigationId: _graphAssociationInvestigationId,
          onAssociateGraphEntity: _associateGraphEntity,
          onAssociateGraphConnection: _associateGraphConnection,
          onExitAssociationMode: _exitGraphAssociationMode,
        );
      case 2:
        return AlertsPage(
          reviewedAlerts: _reviewedAlerts,
          onReview: _markReviewed,
          selectedSeverity: _selectedSeverity,
          onSeverityChanged: (severity) =>
              setState(() => _selectedSeverity = severity),
        );
      case 3:
        return const TelemetryPage();
      case 4:
        return const AttackChainPage();
      case 5:
        return InvestigationManagementScreen(
          controller: _investigationDependencies.controller,
          selectedInvestigationId: _selectedInvestigationId,
          onSelectedInvestigationChanged: (id) =>
              setState(() => _selectedInvestigationId = id),
          onOpenGraphSelection: (id) => setState(() {
            _graphAssociationInvestigationId = id;
            _selectedPage = 1;
          }),
        );
      default:
        return SettingsPage(
          isDark: Theme.of(context).brightness == Brightness.dark,
          onThemeChanged: (dark) => setState(
            () => _themeMode.value = dark ? ThemeMode.dark : ThemeMode.light,
          ),
        );
    }
  }

  Future<bool> _associateGraphEntity(
    String investigationId,
    String entityId,
  ) async {
    final result =
        await _investigationDependencies.controller.associateGraphEntity(
      investigationId: investigationId,
      entityId: entityId,
    );
    if (result == null) {
      _showAssociationMessage(
        _investigationDependencies.controller.errorMessage ??
            'Graph entity association failed.',
      );
      return false;
    }
    _showAssociationMessage(
      'Associated synthetic graph entity $entityId. It is not evidence.',
    );
    return true;
  }

  Future<bool> _associateGraphConnection(
    String investigationId,
    String connectionId,
  ) async {
    final result =
        await _investigationDependencies.controller.associateGraphConnection(
      investigationId: investigationId,
      connectionId: connectionId,
    );
    if (result == null) {
      _showAssociationMessage(
        _investigationDependencies.controller.errorMessage ??
            'Graph connection association failed.',
      );
      return false;
    }
    _showAssociationMessage(
      'Associated synthetic graph connection $connectionId. It is not evidence.',
    );
    return true;
  }

  void _showAssociationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _exitGraphAssociationMode() {
    setState(() {
      _graphAssociationInvestigationId = null;
      _selectedPage = 5;
    });
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({
    required this.reviewedAlerts,
    required this.onReview,
    required this.selectedSeverity,
    required this.onSeverityChanged,
    super.key,
  });

  final Set<String> reviewedAlerts;
  final ValueChanged<SecurityAlert> onReview;
  final Severity? selectedSeverity;
  final ValueChanged<Severity?> onSeverityChanged;

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  @override
  Widget build(BuildContext context) {
    final alerts = demoAlerts.where((alert) {
      return widget.selectedSeverity == null ||
          alert.severity == widget.selectedSeverity;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeading(
          title: 'Alert inbox',
          subtitle: 'Review suspicious activity and keep track of decisions.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: widget.selectedSeverity == null,
              onSelected: (_) => widget.onSeverityChanged(null),
            ),
            for (final severity in Severity.values)
              FilterChip(
                label: Text(severity.label),
                selected: widget.selectedSeverity == severity,
                onSelected: (_) => widget.onSeverityChanged(severity),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final alert in alerts)
          AlertCard(
            alert: alert,
            reviewed: widget.reviewedAlerts.contains(alert.id),
            onReview: () => widget.onReview(alert),
          ),
        if (alerts.isEmpty) const Text('No alerts match this filter.'),
      ],
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({
    required this.alert,
    required this.reviewed,
    required this.onReview,
    super.key,
  });

  final SecurityAlert alert;
  final bool reviewed;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final color = alert.severity.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Tag(text: alert.severity.label, color: color),
                Text(alert.id, style: Theme.of(context).textTheme.labelMedium),
                Text('· ${alert.time}',
                    style: Theme.of(context).textTheme.labelMedium),
                if (reviewed) const _Tag(text: 'REVIEWED', color: _green),
              ],
            ),
            const SizedBox(height: 10),
            Text(alert.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(alert.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _Detail(label: 'Source', value: alert.source),
                _Detail(label: 'Likely stage', value: alert.stage),
                _Detail(label: 'Risk score', value: '${alert.score}/100'),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReview,
                icon: Icon(reviewed ? Icons.undo : Icons.check_circle_outline),
                label: Text(reviewed ? 'Reopen' : 'Mark reviewed'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TelemetryPage extends StatelessWidget {
  const TelemetryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeading(
          title: 'Telemetry',
          subtitle: 'A sample feed of normalized security events.',
        ),
        const SizedBox(height: 18),
        const DemoNotice(),
        const SizedBox(height: 12),
        for (final event in demoEvents)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.bolt_outlined,
                color: eventSeverityColor(event.$5),
              ),
              title: Text(event.$2),
              subtitle: Text('${event.$4} · Source ${event.$3}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(event.$1),
                  Text(
                    event.$5,
                    style: TextStyle(
                      color: eventSeverityColor(event.$5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AttackChainPage extends StatelessWidget {
  const AttackChainPage({super.key});

  static const _stages = [
    ('Initial Access', 'Unusual sign-in time', true),
    ('Credential Access', 'Repeated SSH login failures', true),
    ('Discovery', 'Unexpected command sequence', true),
    ('Execution', 'No sample evidence yet', false),
    ('Privilege Escalation', 'No sample evidence yet', false),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeading(
          title: 'Attack chain',
          subtitle: 'See how related sample alerts can form an investigation.',
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHAIN-001 · Possible account compromise',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 4),
                const Text(
                    'Correlated by sample account, source, and event time.'),
                const SizedBox(height: 16),
                for (var i = 0; i < _stages.length; i++)
                  _ChainStage(
                    title: _stages[i].$1,
                    evidence: _stages[i].$2,
                    hasEvidence: _stages[i].$3,
                    isLast: i == _stages.length - 1,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const DemoNotice(),
      ],
    );
  }
}

class _ChainStage extends StatelessWidget {
  const _ChainStage({
    required this.title,
    required this.evidence,
    required this.hasEvidence,
    required this.isLast,
  });

  final String title;
  final String evidence;
  final bool hasEvidence;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = hasEvidence ? _blue : Theme.of(context).disabledColor;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Icon(
                  hasEvidence ? Icons.check_circle : Icons.circle_outlined,
                  color: color,
                  size: 20,
                ),
                if (!isLast)
                  Expanded(
                    child:
                        Container(width: 2, color: color.withValues(alpha: .3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(evidence),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum SettingsSubPage { main, dataSource, externalServices }

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.isDark,
    required this.onThemeChanged,
    this.initialSubPage = SettingsSubPage.main,
    super.key,
  });

  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final SettingsSubPage initialSubPage;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SettingsSubPage _subPage;

  @override
  void initState() {
    super.initState();
    _subPage = widget.initialSubPage;
  }

  @override
  Widget build(BuildContext context) {
    switch (_subPage) {
      case SettingsSubPage.dataSource:
        return DataSourceDetailsScreen(
          onBack: () => setState(() => _subPage = SettingsSubPage.main),
        );
      case SettingsSubPage.externalServices:
        return ExternalServicesCatalogueScreen(
          onBack: () => setState(() => _subPage = SettingsSubPage.main),
        );
      case SettingsSubPage.main:
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _PageHeading(
              title: 'Settings',
              subtitle: 'Customize the appearance and review demo boundaries.',
            ),
            const SizedBox(height: 18),
            Card(
              child: SwitchListTile(
                title: const Text('Dark theme'),
                subtitle: const Text('Change the appearance of the dashboard.'),
                value: widget.isDark,
                onChanged: widget.onThemeChanged,
                secondary: const Icon(Icons.dark_mode_outlined),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Data source'),
                subtitle: const Text(
                  'Local demo fixtures for alerts, telemetry, graphs, and investigations. '
                  'Investigation records remain in memory for this app process.',
                ),
                isThreeLine: true,
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('Local demo'),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () =>
                    setState(() => _subPage = SettingsSubPage.dataSource),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('External services'),
                subtitle: const Text(
                  'No backend, live telemetry, threat intelligence, or AI service is configured.',
                ),
                isThreeLine: true,
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('Not configured'),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () =>
                    setState(() => _subPage = SettingsSubPage.externalServices),
              ),
            ),
          ],
        );
    }
  }
}
