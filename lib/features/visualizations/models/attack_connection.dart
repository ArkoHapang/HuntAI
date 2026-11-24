import '../../../data/demo_data.dart';

enum AttackConnectionType {
  observed,
  suspicious,
  hypothesized,
}

extension AttackConnectionTypeLabel on AttackConnectionType {
  String get label {
    switch (this) {
      case AttackConnectionType.observed:
        return 'Observed';
      case AttackConnectionType.suspicious:
        return 'Suspicious relationship';
      case AttackConnectionType.hypothesized:
        return 'Hypothesized path';
    }
  }
}

enum AttackConnectionStatus {
  illustrative,
  pendingReview,
  confirmed,
}

class AttackConnection {
  const AttackConnection({
    required this.id,
    required this.sourceEntityId,
    required this.targetEntityId,
    required this.connectionType,
    required this.severity,
    required this.status,
    required this.isDirected,
    required this.isConfirmed,
    required this.description,
  });

  final String id;
  final String sourceEntityId;
  final String targetEntityId;
  final AttackConnectionType connectionType;
  final Severity severity;
  final AttackConnectionStatus status;
  final bool isDirected;
  final bool isConfirmed;
  final String description;
}
