import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/analyst_decision.dart';
import '../../domain/models/investigation.dart';

class InvestigationSummary {
  const InvestigationSummary({
    required this.investigation,
    required this.evidenceCount,
    required this.hypothesisCount,
    required this.latestDecision,
  });

  final Investigation investigation;
  final int evidenceCount;
  final int hypothesisCount;
  final AnalystDecision? latestDecision;

  int get associatedEntityCount => investigation.relatedEntityIds.length;

  int get associatedConnectionCount =>
      investigation.relatedConnectionIds.length;

  InvestigationStatus get status => investigation.status;
}
