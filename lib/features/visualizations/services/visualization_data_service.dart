import 'package:flutter/material.dart';

import '../../../data/demo_data.dart';
import '../models/attack_connection.dart';
import '../models/attack_entity.dart';
import '../models/visualization_data.dart';

class VisualizationDataService {
  const VisualizationDataService();

  static const periods = ['00', '04', '08', '12', '16', '20'];
  static const categories = [
    'Authentication',
    'Network',
    'Endpoint',
    'Process execution',
    'Privilege escalation',
    'Data access',
    'DNS activity',
  ];

  List<TimelinePoint> timeline(String range) {
    switch (range) {
      case '1h':
        return _hourlyWindow;
      case '24h':
        return _dayWindow;
      case '7d':
        return _weekWindow;
      case '30d':
        return _monthWindow;
      default:
        return _dayWindow;
    }
  }

  Map<Severity, int> severityCounts(Iterable<SecurityAlert> alerts) {
    return {
      for (final severity in Severity.values)
        severity: alerts.where((alert) => alert.severity == severity).length,
    };
  }

  List<HeatmapCellData> heatmap(String range) {
    final multiplier = switch (range) {
      '1h' => 1,
      '24h' => 2,
      '7d' => 4,
      '30d' => 7,
      _ => 2,
    };
    const counts = [
      [1, 0, 0, 0],
      [0, 0, 0, 0],
      [1, 1, 0, 1],
      [2, 4, 1, 2],
      [0, 1, 1, 2],
      [0, 0, 1, 1],
    ];
    const categoryScale = [1, 0, 1, 1, 0, 0, 0];
    return [
      for (var categoryIndex = 0;
          categoryIndex < categories.length;
          categoryIndex++)
        for (var periodIndex = 0; periodIndex < periods.length; periodIndex++)
          HeatmapCellData(
            category: categories[categoryIndex],
            period: periods[periodIndex],
            counts: {
              for (var severityIndex = 0;
                  severityIndex < Severity.values.length;
                  severityIndex++)
                Severity.values[severityIndex]: counts[periodIndex]
                        [severityIndex] *
                    categoryScale[categoryIndex] *
                    multiplier,
            },
          ),
    ];
  }

  static const entities = [
    AttackEntity(
      id: 'demo-external',
      name: 'External source',
      entityType: AttackEntityType.attacker,
      position: Offset(90, 160),
      z: 0,
      severity: Severity.high,
      riskScore: 74,
      ipAddress: 'Documentation-only sample',
      description: 'Illustrative external entity in the demo attack path.',
      lastObserved: 'Sample time: 18 minutes ago',
      investigationStatus: 'Demo only · not verified',
    ),
    AttackEntity(
      id: 'demo-ip',
      name: 'Suspicious source',
      entityType: AttackEntityType.suspiciousIp,
      position: Offset(240, 160),
      z: 1,
      severity: Severity.critical,
      riskScore: 92,
      ipAddress: '203.0.113.42',
      description: 'Source shown in the repeated-login sample alert.',
      lastObserved: 'Sample time: 2 minutes ago',
      investigationStatus: 'Demo only · not verified',
    ),
    AttackEntity(
      id: 'demo-account',
      name: 'analyst-demo',
      entityType: AttackEntityType.userAccount,
      position: Offset(400, 160),
      z: 2,
      severity: Severity.high,
      riskScore: 74,
      description: 'Fictional account referenced by a sample sign-in alert.',
      lastObserved: 'Sample time: 18 minutes ago',
      investigationStatus: 'Demo only · not verified',
    ),
    AttackEntity(
      id: 'demo-workstation',
      name: 'Sample workstation',
      entityType: AttackEntityType.workstation,
      position: Offset(560, 160),
      z: 3,
      severity: Severity.medium,
      riskScore: 58,
      ipAddress: '10.0.0.24',
      description: 'Fictional endpoint referenced by sample telemetry.',
      lastObserved: 'Sample time: 41 minutes ago',
      investigationStatus: 'Demo only · not verified',
    ),
    AttackEntity(
      id: 'demo-server',
      name: 'Internal server',
      entityType: AttackEntityType.applicationServer,
      position: Offset(720, 160),
      z: 4,
      severity: Severity.low,
      riskScore: 0,
      description:
          'Illustrative target node; no server telemetry is connected.',
      investigationStatus: 'Hypothesized · no evidence',
    ),
  ];

  static const connections = [
    AttackConnection(
      id: 'demo-link-1',
      sourceEntityId: 'demo-external',
      targetEntityId: 'demo-ip',
      connectionType: AttackConnectionType.hypothesized,
      severity: Severity.high,
      status: AttackConnectionStatus.illustrative,
      isDirected: true,
      isConfirmed: false,
      description:
          'Illustrative relationship; not a verified network connection.',
    ),
    AttackConnection(
      id: 'demo-link-2',
      sourceEntityId: 'demo-ip',
      targetEntityId: 'demo-account',
      connectionType: AttackConnectionType.hypothesized,
      severity: Severity.critical,
      status: AttackConnectionStatus.illustrative,
      isDirected: true,
      isConfirmed: false,
      description: 'A sample sequence suggests a possible relationship only.',
    ),
    AttackConnection(
      id: 'demo-link-3',
      sourceEntityId: 'demo-account',
      targetEntityId: 'demo-workstation',
      connectionType: AttackConnectionType.suspicious,
      severity: Severity.medium,
      status: AttackConnectionStatus.illustrative,
      isDirected: true,
      isConfirmed: false,
      description: 'Illustrative association from fictional sample records.',
    ),
    AttackConnection(
      id: 'demo-link-4',
      sourceEntityId: 'demo-workstation',
      targetEntityId: 'demo-server',
      connectionType: AttackConnectionType.hypothesized,
      severity: Severity.low,
      status: AttackConnectionStatus.illustrative,
      isDirected: true,
      isConfirmed: false,
      description: 'Hypothesized path only; no target telemetry is available.',
    ),
  ];

  static const _hourlyWindow = [
    TimelinePoint(
      label: '−60m',
      counts: {
        Severity.critical: 0,
        Severity.high: 1,
        Severity.medium: 2,
        Severity.low: 3,
      },
    ),
    TimelinePoint(
      label: '−30m',
      counts: {
        Severity.critical: 1,
        Severity.high: 2,
        Severity.medium: 3,
        Severity.low: 4,
      },
    ),
    TimelinePoint(
      label: 'Now',
      counts: {
        Severity.critical: 1,
        Severity.high: 1,
        Severity.medium: 2,
        Severity.low: 2,
      },
    ),
  ];

  static const _dayWindow = [
    TimelinePoint(
      label: '00',
      counts: {
        Severity.critical: 0,
        Severity.high: 1,
        Severity.medium: 2,
        Severity.low: 4,
      },
    ),
    TimelinePoint(
      label: '04',
      counts: {
        Severity.critical: 1,
        Severity.high: 2,
        Severity.medium: 3,
        Severity.low: 5,
      },
    ),
    TimelinePoint(
      label: '08',
      counts: {
        Severity.critical: 0,
        Severity.high: 3,
        Severity.medium: 4,
        Severity.low: 6,
      },
    ),
    TimelinePoint(
      label: '12',
      counts: {
        Severity.critical: 2,
        Severity.high: 5,
        Severity.medium: 7,
        Severity.low: 9,
      },
    ),
    TimelinePoint(
      label: '16',
      counts: {
        Severity.critical: 1,
        Severity.high: 3,
        Severity.medium: 5,
        Severity.low: 8,
      },
    ),
    TimelinePoint(
      label: '20',
      counts: {
        Severity.critical: 0,
        Severity.high: 2,
        Severity.medium: 3,
        Severity.low: 5,
      },
    ),
  ];

  static const _weekWindow = [
    TimelinePoint(
      label: 'D-6',
      counts: {
        Severity.critical: 1,
        Severity.high: 2,
        Severity.medium: 4,
        Severity.low: 6,
      },
    ),
    TimelinePoint(
      label: 'D-5',
      counts: {
        Severity.critical: 0,
        Severity.high: 2,
        Severity.medium: 3,
        Severity.low: 5,
      },
    ),
    TimelinePoint(
      label: 'D-4',
      counts: {
        Severity.critical: 1,
        Severity.high: 3,
        Severity.medium: 5,
        Severity.low: 8,
      },
    ),
    TimelinePoint(
      label: 'D-3',
      counts: {
        Severity.critical: 0,
        Severity.high: 1,
        Severity.medium: 4,
        Severity.low: 6,
      },
    ),
    TimelinePoint(
      label: 'D-2',
      counts: {
        Severity.critical: 2,
        Severity.high: 4,
        Severity.medium: 6,
        Severity.low: 9,
      },
    ),
    TimelinePoint(
      label: 'D-1',
      counts: {
        Severity.critical: 1,
        Severity.high: 2,
        Severity.medium: 4,
        Severity.low: 7,
      },
    ),
    TimelinePoint(
      label: 'Today',
      counts: {
        Severity.critical: 0,
        Severity.high: 1,
        Severity.medium: 3,
        Severity.low: 5,
      },
    ),
  ];

  static const _monthWindow = [
    TimelinePoint(
      label: 'D-30',
      counts: {
        Severity.critical: 0,
        Severity.high: 2,
        Severity.medium: 4,
        Severity.low: 7,
      },
    ),
    TimelinePoint(
      label: 'D-27',
      counts: {
        Severity.critical: 1,
        Severity.high: 3,
        Severity.medium: 5,
        Severity.low: 8,
      },
    ),
    TimelinePoint(
      label: 'D-24',
      counts: {
        Severity.critical: 0,
        Severity.high: 1,
        Severity.medium: 3,
        Severity.low: 6,
      },
    ),
    TimelinePoint(
      label: 'D-21',
      counts: {
        Severity.critical: 1,
        Severity.high: 2,
        Severity.medium: 5,
        Severity.low: 7,
      },
    ),
    TimelinePoint(
      label: 'D-18',
      counts: {
        Severity.critical: 2,
        Severity.high: 4,
        Severity.medium: 6,
        Severity.low: 9,
      },
    ),
    TimelinePoint(
      label: 'D-15',
      counts: {
        Severity.critical: 1,
        Severity.high: 3,
        Severity.medium: 5,
        Severity.low: 7,
      },
    ),
    TimelinePoint(
      label: 'D-12',
      counts: {
        Severity.critical: 0,
        Severity.high: 2,
        Severity.medium: 4,
        Severity.low: 6,
      },
    ),
    TimelinePoint(
      label: 'D-9',
      counts: {
        Severity.critical: 1,
        Severity.high: 2,
        Severity.medium: 4,
        Severity.low: 7,
      },
    ),
    TimelinePoint(
      label: 'D-6',
      counts: {
        Severity.critical: 1,
        Severity.high: 2,
        Severity.medium: 4,
        Severity.low: 6,
      },
    ),
    TimelinePoint(
      label: 'D-3',
      counts: {
        Severity.critical: 0,
        Severity.high: 1,
        Severity.medium: 3,
        Severity.low: 5,
      },
    ),
    TimelinePoint(
      label: 'D-1',
      counts: {
        Severity.critical: 1,
        Severity.high: 3,
        Severity.medium: 5,
        Severity.low: 8,
      },
    ),
    TimelinePoint(
      label: 'Today',
      counts: {
        Severity.critical: 2,
        Severity.high: 5,
        Severity.medium: 7,
        Severity.low: 9,
      },
    ),
  ];
}
