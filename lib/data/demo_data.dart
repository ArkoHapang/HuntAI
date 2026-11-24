import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum Severity { critical, high, medium, low }

class SecurityAlert {
  const SecurityAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.source,
    required this.time,
    required this.score,
    required this.severity,
    required this.stage,
  });

  final String id;
  final String title;
  final String description;
  final String source;
  final String time;
  final int score;
  final Severity severity;
  final String stage;
}

const demoAlerts = [
  SecurityAlert(
    id: 'ALT-2048',
    title: 'Repeated SSH login failures',
    description: '18 failed attempts observed before a successful login.',
    source: '203.0.113.42',
    time: '2 minutes ago',
    score: 92,
    severity: Severity.critical,
    stage: 'Credential Access',
  ),
  SecurityAlert(
    id: 'ALT-2047',
    title: 'Unusual after-hours sign-in',
    description: 'Account signed in outside its typical activity window.',
    source: 'analyst-demo',
    time: '18 minutes ago',
    score: 74,
    severity: Severity.high,
    stage: 'Initial Access',
  ),
  SecurityAlert(
    id: 'ALT-2046',
    title: 'Unexpected command sequence',
    description: 'Several discovery-like commands ran in quick succession.',
    source: '10.0.0.24',
    time: '41 minutes ago',
    score: 58,
    severity: Severity.medium,
    stage: 'Discovery',
  ),
];

const demoEvents = [
  ('14:32:08', 'ssh.login_failed', '203.0.113.42', 'Authentication', 'High'),
  ('14:31:52', 'ssh.login_failed', '203.0.113.42', 'Authentication', 'High'),
  ('14:29:11', 'ssh.login_success', '10.0.0.24', 'Authentication', 'Low'),
  ('14:11:03', 'process.command', '10.0.0.24', 'System', 'Medium'),
  ('13:54:38', 'user.sign_in', 'analyst-demo', 'Authentication', 'Low'),
];

extension SeverityPresentation on Severity {
  String get label {
    switch (this) {
      case Severity.critical:
        return 'Critical';
      case Severity.high:
        return 'High';
      case Severity.medium:
        return 'Medium';
      case Severity.low:
        return 'Low';
    }
  }

  Color get color {
    switch (this) {
      case Severity.critical:
        return AppColors.red;
      case Severity.high:
        return AppColors.orange;
      case Severity.medium:
        return AppColors.blue;
      case Severity.low:
        return AppColors.green;
    }
  }
}

Color eventSeverityColor(String severity) {
  switch (severity) {
    case 'Critical':
    case 'High':
      return AppColors.red;
    case 'Medium':
      return AppColors.orange;
    default:
      return AppColors.green;
  }
}
