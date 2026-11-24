import 'package:flutter/material.dart';

import '../../../data/demo_data.dart';

enum AttackEntityType {
  attacker,
  suspiciousIp,
  userAccount,
  workstation,
  endpoint,
  applicationServer,
  databaseServer,
  internalNetwork,
  compromisedHost,
  criticalInfrastructure,
}

extension AttackEntityTypeLabel on AttackEntityType {
  String get label {
    switch (this) {
      case AttackEntityType.attacker:
        return 'Attacker';
      case AttackEntityType.suspiciousIp:
        return 'Suspicious IP';
      case AttackEntityType.userAccount:
        return 'User account';
      case AttackEntityType.workstation:
        return 'Workstation';
      case AttackEntityType.endpoint:
        return 'Endpoint';
      case AttackEntityType.applicationServer:
        return 'Application server';
      case AttackEntityType.databaseServer:
        return 'Database server';
      case AttackEntityType.internalNetwork:
        return 'Internal network';
      case AttackEntityType.compromisedHost:
        return 'Compromised host';
      case AttackEntityType.criticalInfrastructure:
        return 'Critical infrastructure';
    }
  }
}

class AttackEntity {
  const AttackEntity({
    required this.id,
    required this.name,
    required this.entityType,
    required this.position,
    required this.z,
    required this.severity,
    required this.riskScore,
    required this.description,
    required this.investigationStatus,
    this.ipAddress,
    this.lastObserved,
  });

  final String id;
  final String name;
  final AttackEntityType entityType;
  final Offset position;
  final double z;
  final Severity severity;
  final int riskScore;
  final String? ipAddress;
  final String description;
  final String? lastObserved;
  final String investigationStatus;

  double get x => position.dx;
  double get y => position.dy;
}
