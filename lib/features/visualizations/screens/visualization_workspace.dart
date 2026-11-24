import 'package:flutter/material.dart';

import '../../../core/constants/soc_constants.dart';
import '../../../data/demo_data.dart';
import '../../../shared/widgets/demo_banner.dart';
import '../models/attack_connection.dart';
import '../models/attack_entity.dart';
import '../widgets/attack_graph_2d.dart';
import '../widgets/attack_graph_3d.dart';
import '../widgets/security_heatmap.dart';
import '../widgets/threat_activity_chart.dart';
import '../widgets/threat_severity_chart.dart';
import '../widgets/vulnerability_analytics_chart.dart';

class VisualizationWorkspace extends StatefulWidget {
  const VisualizationWorkspace({
    required this.selectedSeverity,
    required this.onSeverityChanged,
    this.associationInvestigationId,
    this.onAssociateGraphEntity,
    this.onAssociateGraphConnection,
    this.onExitAssociationMode,
    super.key,
  });

  final Severity? selectedSeverity;
  final ValueChanged<Severity?> onSeverityChanged;
  final String? associationInvestigationId;
  final Future<bool> Function(String investigationId, String entityId)?
      onAssociateGraphEntity;
  final Future<bool> Function(String investigationId, String connectionId)?
      onAssociateGraphConnection;
  final VoidCallback? onExitAssociationMode;

  @override
  State<VisualizationWorkspace> createState() => _VisualizationWorkspaceState();
}

class _VisualizationWorkspaceState extends State<VisualizationWorkspace> {
  String _section = 'Overview';
  bool _use3dGraph = false;
  AttackEntity? _selectedEntity;
  AttackConnection? _selectedConnection;

  static const _sections = [
    'Overview',
    'Threat Timeline',
    'Event Heatmap',
    'Severity',
    'Attack Graph',
    'Vulnerability',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding =
            constraints.maxWidth < SocConstants.narrowPageBreakpoint
                ? 16.0
                : 24.0;
        final contentWidth = constraints.maxWidth - horizontalPadding * 2;
        final columns =
            contentWidth >= SocConstants.threeColumnBreakpoint ? 2 : 1;
        const gap = 14.0;
        final panelWidth = (contentWidth - gap * (columns - 1)) / columns;
        final showOverview = _section == 'Overview';

        final timeline = SizedBox(
          width: panelWidth,
          child: const ThreatActivityChart(),
        );
        final heatmap = SizedBox(
          width: panelWidth,
          child: const SecurityHeatmap(),
        );
        final severity = SizedBox(
          width: panelWidth,
          child: ThreatSeverityChart(
            selectedSeverity: widget.selectedSeverity,
            onSeveritySelected: widget.onSeverityChanged,
          ),
        );
        final attackGraph = SizedBox(
          width: contentWidth,
          child: _buildAttackGraph(contentWidth),
        );
        final vulnerabilities = SizedBox(
          width: panelWidth,
          child: const VulnerabilityAnalyticsChart(),
        );

        final selectedPanels = switch (_section) {
          'Threat Timeline' => [timeline],
          'Event Heatmap' => [heatmap],
          'Severity' => [severity],
          'Attack Graph' => [attackGraph],
          'Vulnerability' => [vulnerabilities],
          _ => [timeline, heatmap, severity, attackGraph, vulnerabilities],
        };

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            22,
            horizontalPadding,
            28,
          ),
          children: [
            Text(
              'Threat analysis workspace',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 5),
            Text(
              'Explore sample activity, relationships, and severity distribution.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            const DemoNotice(),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final section in _sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(section),
                        selected: _section == section,
                        onSelected: (_) => setState(() => _section = section),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (showOverview)
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  timeline,
                  heatmap,
                  severity,
                  vulnerabilities,
                  attackGraph,
                ],
              )
            else
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: selectedPanels,
              ),
          ],
        );
      },
    );
  }

  Widget _buildAttackGraph(double contentWidth) {
    return SizedBox(
      width: contentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.associationInvestigationId != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Graph association mode',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onExitAssociationMode,
                          child: const Text('Back to investigation'),
                        ),
                      ],
                    ),
                    const Text(
                      'Selected items are synthetic graph fixtures. '
                      'Association does not make them evidence or prove '
                      'malicious activity.',
                    ),
                    const SizedBox(height: 8),
                    if (_selectedEntity != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Entity: ${_selectedEntity!.name} '
                            '(${_selectedEntity!.id})',
                          ),
                          OutlinedButton(
                            onPressed: widget.onAssociateGraphEntity == null
                                ? null
                                : () => _associateEntity(_selectedEntity!.id),
                            child: const Text('Associate entity'),
                          ),
                        ],
                      ),
                    if (_selectedConnection != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Connection: ${_selectedConnection!.id}',
                          ),
                          OutlinedButton(
                            onPressed: widget.onAssociateGraphConnection == null
                                ? null
                                : () => _associateConnection(
                                      _selectedConnection!.id,
                                    ),
                            child: const Text('Associate connection'),
                          ),
                        ],
                      ),
                    if (_selectedEntity == null && _selectedConnection == null)
                      const Text('Select a graph node or connection below.'),
                  ],
                ),
              ),
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('attack-graph-view-2d'),
                label: const Text('2D Graph'),
                selected: !_use3dGraph,
                onSelected: (_) => setState(() => _use3dGraph = false),
              ),
              ChoiceChip(
                key: const ValueKey('attack-graph-view-3d'),
                label: const Text('3D Graph'),
                selected: _use3dGraph,
                onSelected: (_) => setState(() => _use3dGraph = true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _use3dGraph
              ? AttackGraph3D(
                  onEntitySelectionChanged: _onEntitySelected,
                  onConnectionSelectionChanged: _onConnectionSelected,
                )
              : AttackGraph2D(
                  onEntitySelectionChanged: _onEntitySelected,
                  onConnectionSelectionChanged: _onConnectionSelected,
                ),
        ],
      ),
    );
  }

  void _onEntitySelected(AttackEntity? entity) {
    setState(() {
      _selectedEntity = entity;
      if (entity != null) _selectedConnection = null;
    });
  }

  void _onConnectionSelected(AttackConnection? connection) {
    setState(() {
      _selectedConnection = connection;
      if (connection != null) _selectedEntity = null;
    });
  }

  Future<void> _associateEntity(String entityId) async {
    final investigationId = widget.associationInvestigationId;
    final associate = widget.onAssociateGraphEntity;
    if (investigationId == null || associate == null) return;
    final succeeded = await associate(investigationId, entityId);
    if (succeeded && mounted) setState(() => _selectedEntity = null);
  }

  Future<void> _associateConnection(String connectionId) async {
    final investigationId = widget.associationInvestigationId;
    final associate = widget.onAssociateGraphConnection;
    if (investigationId == null || associate == null) return;
    final succeeded = await associate(investigationId, connectionId);
    if (succeeded && mounted) setState(() => _selectedConnection = null);
  }
}
