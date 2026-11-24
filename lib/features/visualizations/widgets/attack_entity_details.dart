import 'package:flutter/material.dart';

import '../../../data/demo_data.dart';
import '../models/attack_connection.dart';
import '../models/attack_entity.dart';

class AttackEntityDetails extends StatelessWidget {
  const AttackEntityDetails({
    required this.entity,
    required this.connection,
    required this.entities,
    required this.connections,
    super.key,
  });

  final AttackEntity? entity;
  final AttackConnection? connection;
  final List<AttackEntity> entities;
  final List<AttackConnection> connections;

  @override
  Widget build(BuildContext context) {
    if (connection != null) {
      return _ConnectionDetails(
        connection: connection!,
        entities: entities,
      );
    }
    if (entity == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Select a node or relationship to inspect illustrative details.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final selected = entity!;
    final relatedIds = connections
        .where((edge) =>
            edge.sourceEntityId == selected.id ||
            edge.targetEntityId == selected.id)
        .map((edge) => edge.sourceEntityId == selected.id
            ? edge.targetEntityId
            : edge.sourceEntityId)
        .toSet();
    final related = entities.where((item) => relatedIds.contains(item.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(selected.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(selected.entityType.label,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailTag(
                  label: selected.severity.label,
                  color: selected.severity.color,
                ),
                _DetailTag(
                  label: 'Risk ${selected.riskScore}/100',
                  color: selected.severity.color,
                ),
                _DetailTag(
                  label: selected.investigationStatus,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailLine(label: 'Description', value: selected.description),
            if (selected.ipAddress != null)
              _DetailLine(label: 'Address', value: selected.ipAddress!),
            if (selected.lastObserved != null)
              _DetailLine(label: 'Observed', value: selected.lastObserved!),
            _DetailLine(
              label: 'Connected entities',
              value: related.isEmpty
                  ? 'None in this view'
                  : related.map((item) => item.name).join(', '),
            ),
            const SizedBox(height: 4),
            Text(
              'Illustrative graph fixture · not a verified incident.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionDetails extends StatelessWidget {
  const _ConnectionDetails({
    required this.connection,
    required this.entities,
  });

  final AttackConnection connection;
  final List<AttackEntity> entities;

  @override
  Widget build(BuildContext context) {
    final source = entities
        .where((entity) => entity.id == connection.sourceEntityId)
        .firstOrNull;
    final target = entities
        .where((entity) => entity.id == connection.targetEntityId)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selected relationship',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _DetailLine(
              label: 'Path',
              value:
                  '${source?.name ?? 'Unknown'} → ${target?.name ?? 'Unknown'}',
            ),
            _DetailLine(
              label: 'Classification',
              value: connection.connectionType.label,
            ),
            _DetailLine(label: 'Status', value: connection.status.name),
            _DetailLine(
              label: 'Confirmation',
              value: connection.isConfirmed ? 'Confirmed' : 'Not confirmed',
            ),
            _DetailLine(
              label: 'Direction',
              value: connection.isDirected ? 'Directed' : 'Undirected',
            ),
            _DetailLine(label: 'Description', value: connection.description),
            Text(
              _confirmationMessage(connection),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _confirmationMessage(AttackConnection connection) {
    if (connection.isConfirmed) {
      return 'Marked confirmed in the fixture; this is demo data.';
    }
    return switch (connection.connectionType) {
      AttackConnectionType.observed =>
        'Observed classification · not independently confirmed in this demo.',
      AttackConnectionType.suspicious =>
        'Suspicious relationship · not confirmed as an attack.',
      AttackConnectionType.hypothesized =>
        'Hypothesized relationship · not confirmed as an attack path.',
    };
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
