enum InvestigationStatus {
  draft,
  active,
  onHold,
  closed,
}

enum InvestigationPriority {
  low,
  medium,
  high,
  critical,
}

enum EvidenceType {
  alert,
  telemetryEvent,
  graphEntity,
  graphRelationship,
  analystObservation,
  artifact,
  other,
}

enum DataOrigin {
  observedTelemetry,
  syntheticDemo,
  analystCreated,
  aiGenerated,
  imported,
}

enum EvidenceReliability {
  unassessed,
  low,
  medium,
  high,
}

enum DataClassification {
  public,
  internal,
  confidential,
  restricted,
}

enum HypothesisStatus {
  candidate,
  underReview,
  acceptedForInvestigation,
  rejected,
  deferred,
  inconclusive,
  superseded,
}

enum AnalystDecisionType {
  accept,
  reject,
  defer,
  inconclusive,
}
