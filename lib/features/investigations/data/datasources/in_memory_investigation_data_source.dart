import '../../domain/models/analyst_decision.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/hypothesis_assessment.dart';
import '../../domain/models/investigation.dart';
import '../../domain/models/model_validation.dart';
import 'investigation_graph_catalog.dart';

/// Low-level volatile storage used by repositories; use repository contracts
/// for validated writes.
class InMemoryInvestigationDataSource implements InvestigationGraphCatalog {
  InMemoryInvestigationDataSource({
    Iterable<String> availableEntityIds = const [],
    Iterable<String> availableConnectionIds = const [],
    DateTime Function()? clock,
  })  : availableEntityIds = Set<String>.unmodifiable(
          ModelValidation.immutableUniqueIds(
            availableEntityIds,
            'availableEntityIds',
          ),
        ),
        availableConnectionIds = Set<String>.unmodifiable(
          ModelValidation.immutableUniqueIds(
            availableConnectionIds,
            'availableConnectionIds',
          ),
        ),
        _clock = clock ?? DateTime.now;

  final Map<String, Investigation> _investigations = {};
  final Map<String, Evidence> _evidence = {};
  final Map<String, Hypothesis> _hypotheses = {};
  final Map<String, AnalystAssessment> _assessments = {};
  final Map<String, AnalystDecision> _decisions = {};
  final DateTime Function() _clock;

  @override
  final Set<String> availableEntityIds;

  @override
  final Set<String> availableConnectionIds;

  Map<String, Investigation> get investigations =>
      Map<String, Investigation>.unmodifiable(_investigations);

  Map<String, Evidence> get evidence =>
      Map<String, Evidence>.unmodifiable(_evidence);

  Map<String, Hypothesis> get hypotheses =>
      Map<String, Hypothesis>.unmodifiable(_hypotheses);

  Map<String, AnalystAssessment> get assessments =>
      Map<String, AnalystAssessment>.unmodifiable(_assessments);

  Map<String, AnalystDecision> get decisions =>
      Map<String, AnalystDecision>.unmodifiable(_decisions);

  DateTime nextUpdatedAt(DateTime previous) {
    final now = _clock().toUtc();
    return now.isBefore(previous) ? previous : now;
  }

  /// Commit methods are called only after repository validation succeeds.
  void commitInvestigation(Investigation investigation) {
    _investigations[investigation.id] = investigation;
  }

  void commitEvidence({
    required Investigation investigation,
    required Evidence evidence,
  }) {
    _investigations[investigation.id] = investigation;
    _evidence[evidence.id] = evidence;
  }

  void commitHypothesis({
    required Investigation investigation,
    required Hypothesis hypothesis,
  }) {
    _investigations[investigation.id] = investigation;
    _hypotheses[hypothesis.id] = hypothesis;
  }

  void commitAssessment(AnalystAssessment assessment) {
    _assessments[assessment.id] = assessment;
  }

  void commitHypotheses({
    required Investigation investigation,
    required Iterable<Hypothesis> hypotheses,
  }) {
    _investigations[investigation.id] = investigation;
    for (final hypothesis in hypotheses) {
      _hypotheses[hypothesis.id] = hypothesis;
    }
  }

  void commitDecision({
    required Investigation investigation,
    required AnalystDecision decision,
  }) {
    _investigations[investigation.id] = investigation;
    _decisions[decision.id] = decision;
  }

  void commitHypothesisReview({
    required Investigation investigation,
    required Hypothesis hypothesis,
    required AnalystDecision decision,
  }) {
    _investigations[investigation.id] = investigation;
    _hypotheses[hypothesis.id] = hypothesis;
    _decisions[decision.id] = decision;
  }

  void deleteInvestigation(String id) {
    _investigations.remove(id);
  }
}
