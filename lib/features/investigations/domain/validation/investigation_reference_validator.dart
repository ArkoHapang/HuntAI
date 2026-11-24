import '../models/analyst_decision.dart';
import '../models/evidence.dart';
import '../models/hypothesis.dart';
import '../models/investigation.dart';
import '../models/model_validation.dart';

abstract final class InvestigationReferenceValidator {
  static void validateSnapshot({
    required Investigation investigation,
    required Iterable<String> availableEntityIds,
    required Iterable<String> availableConnectionIds,
    required Iterable<Evidence> evidence,
    required Iterable<Hypothesis> hypotheses,
  }) {
    final entityIds = availableEntityIds.toSet();
    final connectionIds = availableConnectionIds.toSet();
    final evidenceById = _uniqueById(evidence, 'evidence');
    final hypothesesById = _uniqueById(hypotheses, 'hypotheses');

    ModelValidation.requireSubset(
      investigation.relatedEntityIds,
      entityIds,
      'relatedEntityIds',
    );
    ModelValidation.requireSubset(
      investigation.relatedConnectionIds,
      connectionIds,
      'relatedConnectionIds',
    );
    _requireAllRecordsListed(
      investigation.evidenceIds,
      evidenceById,
      'evidenceIds',
    );
    _requireAllRecordsListed(
      investigation.hypothesisIds,
      hypothesesById,
      'hypothesisIds',
    );

    for (final item in evidenceById.values) {
      if (item.investigationId != investigation.id) {
        throw ArgumentError(
          'Evidence ${item.id} belongs to a different investigation.',
        );
      }
      ModelValidation.requireSubset(
        item.relatedEntityIds,
        investigation.relatedEntityIds.toSet(),
        'evidence.relatedEntityIds',
      );
      ModelValidation.requireSubset(
        item.relatedConnectionIds,
        investigation.relatedConnectionIds.toSet(),
        'evidence.relatedConnectionIds',
      );
    }

    final evidenceIds = evidenceById.keys.toSet();
    for (final hypothesis in hypothesesById.values) {
      if (hypothesis.investigationId != investigation.id) {
        throw ArgumentError(
          'Hypothesis ${hypothesis.id} belongs to a different investigation.',
        );
      }
      ModelValidation.requireSubset(
        hypothesis.supportingEvidenceIds,
        evidenceIds,
        'hypothesis.supportingEvidenceIds',
      );
      ModelValidation.requireSubset(
        hypothesis.contradictingEvidenceIds,
        evidenceIds,
        'hypothesis.contradictingEvidenceIds',
      );
      ModelValidation.requireSubset(
        hypothesis.relatedEntityIds,
        investigation.relatedEntityIds.toSet(),
        'hypothesis.relatedEntityIds',
      );
      ModelValidation.requireSubset(
        hypothesis.relatedConnectionIds,
        investigation.relatedConnectionIds.toSet(),
        'hypothesis.relatedConnectionIds',
      );
    }
  }

  static void validateDecision({
    required Investigation investigation,
    required Hypothesis hypothesis,
    required AnalystDecision decision,
  }) {
    if (hypothesis.investigationId != investigation.id ||
        decision.investigationId != investigation.id ||
        decision.hypothesisId != hypothesis.id ||
        !investigation.hypothesisIds.contains(hypothesis.id)) {
      throw ArgumentError(
        'Decision, hypothesis, and investigation references must agree.',
      );
    }
  }

  static Map<String, T> _uniqueById<T>(
    Iterable<T> values,
    String fieldName,
  ) {
    final result = <String, T>{};
    for (final value in values) {
      final id = switch (value) {
        Evidence item => item.id,
        Hypothesis item => item.id,
        _ => throw ArgumentError.value(
            value, fieldName, 'has an unsupported type.'),
      };
      if (result.containsKey(id)) {
        throw ArgumentError.value(id, fieldName, 'must contain unique IDs.');
      }
      result[id] = value;
    }
    return result;
  }

  static void _requireAllRecordsListed<T>(
    List<String> listedIds,
    Map<String, T> recordsById,
    String fieldName,
  ) {
    ModelValidation.requireSubset(
        listedIds, recordsById.keys.toSet(), fieldName);
    ModelValidation.requireSubset(
      recordsById.keys,
      listedIds.toSet(),
      fieldName,
    );
  }
}
