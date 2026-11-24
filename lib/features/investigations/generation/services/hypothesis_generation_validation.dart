import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/model_validation.dart';
import '../exceptions/hypothesis_generation_exception.dart';
import '../models/hypothesis_generation_configuration.dart';
import '../models/hypothesis_generation_request.dart';

class ValidatedHypothesisGenerationRequest {
  ValidatedHypothesisGenerationRequest({
    required Map<String, Evidence> evidenceById,
    required Map<String, EvidenceCuePolarity> cuePolarityByEvidenceId,
    required Set<String> associatedEntityIds,
    required Set<String> associatedConnectionIds,
  })  : evidenceById = Map<String, Evidence>.unmodifiable(evidenceById),
        cuePolarityByEvidenceId = Map<String, EvidenceCuePolarity>.unmodifiable(
          cuePolarityByEvidenceId,
        ),
        associatedEntityIds = Set<String>.unmodifiable(associatedEntityIds),
        associatedConnectionIds =
            Set<String>.unmodifiable(associatedConnectionIds);

  final Map<String, Evidence> evidenceById;
  final Map<String, EvidenceCuePolarity> cuePolarityByEvidenceId;
  final Set<String> associatedEntityIds;
  final Set<String> associatedConnectionIds;
}

abstract final class HypothesisGenerationValidation {
  static ValidatedHypothesisGenerationRequest validateRequest(
    HypothesisGenerationRequest request,
  ) {
    final investigationId = request.investigationId.trim();
    if (investigationId.isEmpty) {
      throw const InvalidGenerationContextException(
        'Investigation ID must not be empty.',
      );
    }
    if (request.configuration.minimumSupportingEvidence < 1 ||
        request.configuration.maximumHypotheses < 1) {
      throw const InvalidGenerationContextException(
        'Generation thresholds must be positive.',
      );
    }

    final entityIds = _validatedIds(
      request.associatedEntityIds,
      'associatedEntityIds',
    );
    final connectionIds = _validatedIds(
      request.associatedConnectionIds,
      'associatedConnectionIds',
    );
    final evidenceById = <String, Evidence>{};
    for (final evidence in request.evidence) {
      if (evidence.investigationId != investigationId) {
        throw InvalidEvidenceReferencesException(
          'Evidence "${evidence.id}" belongs to another investigation.',
        );
      }
      final previous = evidenceById[evidence.id];
      if (previous != null && !_sameEvidence(previous, evidence)) {
        throw InvalidEvidenceReferencesException(
          'Evidence ID "${evidence.id}" has conflicting records.',
        );
      }
      evidenceById.putIfAbsent(evidence.id, () => evidence);
    }

    for (final evidence in evidenceById.values) {
      _requireSubset(
        evidence.relatedEntityIds,
        entityIds,
        'Evidence "${evidence.id}" references an unknown graph entity.',
      );
      _requireSubset(
        evidence.relatedConnectionIds,
        connectionIds,
        'Evidence "${evidence.id}" references an unknown graph connection.',
      );
    }

    final existingHypothesisIds = <String>{};
    for (final hypothesis in request.existingHypotheses) {
      if (hypothesis.investigationId != investigationId) {
        throw InvalidGenerationContextException(
          'Hypothesis "${hypothesis.id}" belongs to another investigation.',
        );
      }
      if (!existingHypothesisIds.add(hypothesis.id)) {
        throw InvalidGenerationContextException(
          'Existing hypothesis ID "${hypothesis.id}" is duplicated.',
        );
      }
      _requireSubset(
        [
          ...hypothesis.supportingEvidenceIds,
          ...hypothesis.contradictingEvidenceIds,
        ],
        evidenceById.keys.toSet(),
        'Hypothesis "${hypothesis.id}" references unavailable evidence.',
      );
      _requireSubset(
        hypothesis.relatedEntityIds,
        entityIds,
        'Hypothesis "${hypothesis.id}" references an unknown graph entity.',
      );
      _requireSubset(
        hypothesis.relatedConnectionIds,
        connectionIds,
        'Hypothesis "${hypothesis.id}" references an unknown graph connection.',
      );
    }

    final cuePolarityById = <String, EvidenceCuePolarity>{};
    for (final cue in request.configuration.evidenceCues) {
      late final String evidenceId;
      try {
        evidenceId = ModelValidation.requiredIdentifier(
          cue.evidenceId,
          'evidenceId',
        );
      } on ArgumentError catch (error) {
        throw InvalidEvidenceReferencesException(error.message.toString());
      }
      if (!evidenceById.containsKey(evidenceId)) {
        throw InvalidEvidenceReferencesException(
          'Generation cue references unavailable evidence "$evidenceId".',
        );
      }
      final prior = cuePolarityById[evidenceId];
      if (prior != null && prior != cue.polarity) {
        throw InvalidEvidenceReferencesException(
          'Evidence "$evidenceId" cannot support and contradict the same '
          'mock generation rule.',
        );
      }
      cuePolarityById[evidenceId] = cue.polarity;
    }

    return ValidatedHypothesisGenerationRequest(
      evidenceById: evidenceById,
      cuePolarityByEvidenceId: cuePolarityById,
      associatedEntityIds: entityIds,
      associatedConnectionIds: connectionIds,
    );
  }

  static void validateGeneratedHypotheses({
    required HypothesisGenerationRequest request,
    required Iterable<Hypothesis> hypotheses,
    required String generatorName,
    required String generatorVersion,
  }) {
    final context = validateRequest(request);
    final ids = <String>{};
    final validatedHypotheses = <Hypothesis>[];
    for (final hypothesis in hypotheses) {
      if (hypothesis.investigationId != request.investigationId.trim()) {
        throw InvalidGeneratedHypothesesException(
          'Generated hypothesis "${hypothesis.id}" belongs to another '
          'investigation.',
        );
      }
      if (!ids.add(hypothesis.id)) {
        throw InvalidGeneratedHypothesesException(
          'Generated hypothesis ID "${hypothesis.id}" is duplicated.',
        );
      }
      if (validatedHypotheses.any(
        (item) => equivalentGeneratedContent(item, hypothesis),
      )) {
        throw const InvalidGeneratedHypothesesException(
          'Generated hypothesis content is duplicated.',
        );
      }
      if (hypothesis.status != HypothesisStatus.candidate ||
          hypothesis.reviewedAt != null) {
        throw const InvalidGeneratedHypothesesException(
          'Generated hypotheses must begin as unreviewed candidates.',
        );
      }
      if (hypothesis.mitreAttackReferences.isNotEmpty) {
        throw const InvalidGeneratedHypothesesException(
          'Generated hypotheses must not create ATT&CK mappings; mappings '
          'require an analyst proposal.',
        );
      }
      final provenance = hypothesis.provenance;
      if (provenance.origin != DataOrigin.aiGenerated ||
          provenance.generatorName != generatorName ||
          provenance.generatorVersion != generatorVersion ||
          !provenance.recordedAt.isAtSameMomentAs(hypothesis.generatedAt) ||
          hypothesis.generationMetadata == null ||
          hypothesis.generationMetadata!.ruleSetVersion != generatorVersion) {
        throw const InvalidGeneratedHypothesesException(
          'Generated hypothesis provenance does not identify this generator.',
        );
      }
      final sourceEvidenceIds = {
        ...hypothesis.supportingEvidenceIds,
        ...hypothesis.contradictingEvidenceIds,
      };
      if (sourceEvidenceIds.isEmpty) {
        throw const InvalidGeneratedHypothesesException(
          'Generated hypotheses must reference source evidence.',
        );
      }
      _requireSubset(
        sourceEvidenceIds,
        context.evidenceById.keys.toSet(),
        'Generated hypothesis "${hypothesis.id}" references unavailable '
        'evidence.',
      );
      _requireSubset(
        hypothesis.relatedEntityIds,
        context.associatedEntityIds,
        'Generated hypothesis "${hypothesis.id}" references an unknown graph '
        'entity.',
      );
      _requireSubset(
        hypothesis.relatedConnectionIds,
        context.associatedConnectionIds,
        'Generated hypothesis "${hypothesis.id}" references an unknown graph '
        'connection.',
      );
      validatedHypotheses.add(hypothesis);
    }
  }

  static Set<String> _validatedIds(
    Iterable<String> ids,
    String field,
  ) {
    try {
      return ModelValidation.immutableUniqueIds(ids, field).toSet();
    } on ArgumentError catch (error) {
      throw InvalidGenerationContextException(error.message.toString());
    }
  }

  static void _requireSubset(
    Iterable<String> references,
    Set<String> available,
    String message,
  ) {
    for (final reference in references) {
      if (!available.contains(reference)) {
        throw InvalidEvidenceReferencesException(message);
      }
    }
  }

  static bool equivalentGeneratedContent(
    Hypothesis first,
    Hypothesis second,
  ) =>
      first.investigationId == second.investigationId &&
      first.title == second.title &&
      first.explanation == second.explanation &&
      _sameIds(first.supportingEvidenceIds, second.supportingEvidenceIds) &&
      _sameIds(
        first.contradictingEvidenceIds,
        second.contradictingEvidenceIds,
      ) &&
      _sameIds(first.relatedEntityIds, second.relatedEntityIds) &&
      _sameIds(first.relatedConnectionIds, second.relatedConnectionIds) &&
      first.confidence == second.confidence &&
      first.confidenceExplanation == second.confidenceExplanation &&
      first.status == HypothesisStatus.candidate &&
      second.status == HypothesisStatus.candidate &&
      _sameIds(
        first.alternativeExplanations,
        second.alternativeExplanations,
      ) &&
      _sameEvidenceGaps(first.evidenceGaps, second.evidenceGaps) &&
      first.generationMetadata?.method == second.generationMetadata?.method &&
      first.generationMetadata?.ruleSetVersion ==
          second.generationMetadata?.ruleSetVersion &&
      _sameGeneratedProvenance(first.provenance, second.provenance);

  static bool _sameEvidence(Evidence first, Evidence second) =>
      first.id == second.id &&
      first.investigationId == second.investigationId &&
      first.title == second.title &&
      first.description == second.description &&
      first.evidenceType == second.evidenceType &&
      first.provenance.origin == second.provenance.origin &&
      first.provenance.source.description ==
          second.provenance.source.description &&
      first.provenance.source.identifier ==
          second.provenance.source.identifier &&
      first.provenance.authorId == second.provenance.authorId &&
      first.provenance.recordedAt.isAtSameMomentAs(
        second.provenance.recordedAt,
      ) &&
      first.provenance.generatorName == second.provenance.generatorName &&
      first.provenance.generatorVersion == second.provenance.generatorVersion &&
      _sameOptionalDate(first.observedAt, second.observedAt) &&
      first.collectedAt.isAtSameMomentAs(second.collectedAt) &&
      first.reliability == second.reliability &&
      first.reliabilityRationale == second.reliabilityRationale &&
      first.dataClassification == second.dataClassification &&
      _sameIds(first.relatedEntityIds, second.relatedEntityIds) &&
      _sameIds(first.relatedConnectionIds, second.relatedConnectionIds);

  static bool _sameIds(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static bool _sameOptionalDate(DateTime? first, DateTime? second) =>
      first == null
          ? second == null
          : second != null && first.isAtSameMomentAs(second);

  static bool _sameEvidenceGaps(
      List<EvidenceGap> first, List<EvidenceGap> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      final a = first[index];
      final b = second[index];
      if (a.description != b.description ||
          a.reason != b.reason ||
          a.suggestedSource != b.suggestedSource) {
        return false;
      }
    }
    return true;
  }

  static bool _sameGeneratedProvenance(
    DataProvenance first,
    DataProvenance second,
  ) =>
      first.origin == second.origin &&
      first.generatorName == second.generatorName &&
      first.generatorVersion == second.generatorVersion &&
      first.source.description == second.source.description &&
      first.source.identifier == second.source.identifier;
}
