import '../../data/datasources/investigation_graph_catalog.dart';
import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/investigation.dart';
import '../../domain/models/model_validation.dart';
import '../../domain/validation/hypothesis_status_transition_policy.dart';
import '../exceptions/investigation_workflow_exception.dart';

abstract final class InvestigationWorkflowValidator {
  static const Map<InvestigationStatus, Set<InvestigationStatus>>
      _lifecycleTransitions = {
    InvestigationStatus.draft: {InvestigationStatus.active},
    InvestigationStatus.active: {
      InvestigationStatus.onHold,
      InvestigationStatus.closed,
    },
    InvestigationStatus.onHold: {
      InvestigationStatus.active,
      InvestigationStatus.closed,
    },
    InvestigationStatus.closed: {},
  };

  static void requireOpen(Investigation investigation) {
    if (investigation.status == InvestigationStatus.closed) {
      throw InvestigationClosedException(investigation.id);
    }
  }

  static void validateLifecycleTransition(
    InvestigationStatus from,
    InvestigationStatus to,
  ) {
    if (!_lifecycleTransitions[from]!.contains(to)) {
      throw InvalidLifecycleTransitionException(
        from: from.name,
        to: to.name,
      );
    }
  }

  static void validateHypothesisTransition(
    HypothesisStatus from,
    HypothesisStatus to,
  ) {
    if (!HypothesisStatusTransitionPolicy.allows(from, to)) {
      throw InvalidHypothesisTransitionException(
        from: from.name,
        to: to.name,
      );
    }
  }

  static List<String> graphAssociations({
    required Iterable<String> requestedIds,
    required Iterable<String> currentIds,
    required Set<String> knownIds,
    required String graphType,
  }) {
    final normalized = _uniqueIds(requestedIds, graphType);
    if (normalized.isEmpty) {
      throw InvalidWorkflowInputException(
        'At least one $graphType ID must be supplied.',
      );
    }
    final existing = currentIds.toSet();
    for (final id in normalized) {
      if (!knownIds.contains(id)) {
        throw UnknownGraphReferenceException(
          graphType: graphType,
          graphId: id,
        );
      }
      if (existing.contains(id)) {
        throw DuplicateGraphAssociationException(
          graphType: graphType,
          graphId: id,
        );
      }
    }
    return List<String>.unmodifiable([...currentIds, ...normalized]);
  }

  static void validateKnownGraphReferences({
    required Iterable<String> entityIds,
    required Iterable<String> connectionIds,
    required InvestigationGraphCatalog graphCatalog,
  }) {
    final entities = _uniqueIds(entityIds, 'graph entity');
    final connections = _uniqueIds(connectionIds, 'graph connection');
    for (final id in entities) {
      if (!graphCatalog.availableEntityIds.contains(id)) {
        throw UnknownGraphReferenceException(
          graphType: 'Graph entity',
          graphId: id,
        );
      }
    }
    for (final id in connections) {
      if (!graphCatalog.availableConnectionIds.contains(id)) {
        throw UnknownGraphReferenceException(
          graphType: 'Graph connection',
          graphId: id,
        );
      }
    }
  }

  static void validateEvidence({
    required Investigation investigation,
    required Evidence evidence,
    required InvestigationGraphCatalog graphCatalog,
  }) {
    if (evidence.investigationId != investigation.id) {
      throw const InvalidWorkflowInputException(
        'Evidence belongs to a different investigation.',
      );
    }
    if (evidence.provenance.origin == DataOrigin.aiGenerated) {
      throw const InvalidWorkflowInputException(
        'AI-generated hypotheses cannot be represented as evidence.',
      );
    }
    _validateEvidenceGraphIds(
      evidence.relatedEntityIds,
      investigation.relatedEntityIds.toSet(),
      graphCatalog.availableEntityIds,
      'Graph entity',
    );
    _validateEvidenceGraphIds(
      evidence.relatedConnectionIds,
      investigation.relatedConnectionIds.toSet(),
      graphCatalog.availableConnectionIds,
      'Graph connection',
    );
  }

  static void validateHypothesisRelationship({
    required Investigation investigation,
    required Hypothesis hypothesis,
  }) {
    if (hypothesis.investigationId != investigation.id ||
        !investigation.hypothesisIds.contains(hypothesis.id)) {
      throw const InvalidWorkflowInputException(
        'Hypothesis must belong to and be linked from the investigation.',
      );
    }
  }

  static List<String> _uniqueIds(Iterable<String> values, String label) {
    try {
      return ModelValidation.immutableUniqueIds(values, label);
    } on ArgumentError catch (error) {
      throw InvalidWorkflowInputException(error.message.toString());
    }
  }

  static void _validateEvidenceGraphIds(
    Iterable<String> references,
    Set<String> associatedIds,
    Set<String> catalogIds,
    String graphType,
  ) {
    for (final id in references) {
      if (!catalogIds.contains(id)) {
        throw UnknownGraphReferenceException(graphType: graphType, graphId: id);
      }
      if (!associatedIds.contains(id)) {
        throw InvalidWorkflowInputException(
          '$graphType "$id" must be associated with the investigation before '
          'it is referenced by evidence.',
        );
      }
    }
  }
}
