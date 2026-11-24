import '../enums/investigation_enums.dart';
import 'data_provenance.dart';
import 'mitre_attack_reference.dart';
import 'model_validation.dart';

class EvidenceGap {
  EvidenceGap({
    required String description,
    required String reason,
    String? suggestedSource,
  })  : description = ModelValidation.requiredText(description, 'description'),
        reason = ModelValidation.requiredText(reason, 'reason'),
        suggestedSource = _optionalText(suggestedSource, 'suggestedSource');

  final String description;
  final String reason;
  final String? suggestedSource;

  static String? _optionalText(String? value, String fieldName) {
    if (value == null) return null;
    return ModelValidation.requiredText(value, fieldName);
  }
}

class GenerationMetadata {
  GenerationMetadata({
    required String method,
    required String ruleSetVersion,
  })  : method = ModelValidation.requiredText(method, 'method'),
        ruleSetVersion =
            ModelValidation.requiredText(ruleSetVersion, 'ruleSetVersion');

  final String method;
  final String ruleSetVersion;
}

class Hypothesis {
  Hypothesis({
    required String id,
    required String investigationId,
    required String title,
    required String explanation,
    required this.confidence,
    required String confidenceExplanation,
    required this.status,
    required DateTime generatedAt,
    required this.provenance,
    DateTime? reviewedAt,
    Iterable<String> supportingEvidenceIds = const [],
    Iterable<String> contradictingEvidenceIds = const [],
    Iterable<String> relatedEntityIds = const [],
    Iterable<String> relatedConnectionIds = const [],
    Iterable<String> alternativeExplanations = const [],
    Iterable<EvidenceGap> evidenceGaps = const [],
    Iterable<MitreAttackReference> mitreAttackReferences = const [],
    this.generationMetadata,
  })  : id = ModelValidation.requiredIdentifier(id, 'id'),
        investigationId = ModelValidation.requiredIdentifier(
            investigationId, 'investigationId'),
        title = ModelValidation.requiredText(title, 'title'),
        explanation = ModelValidation.requiredText(explanation, 'explanation'),
        confidenceExplanation = ModelValidation.requiredText(
          confidenceExplanation,
          'confidenceExplanation',
        ),
        generatedAt = ModelValidation.utc(generatedAt),
        reviewedAt =
            reviewedAt == null ? null : ModelValidation.utc(reviewedAt),
        supportingEvidenceIds = ModelValidation.immutableUniqueIds(
          supportingEvidenceIds,
          'supportingEvidenceIds',
        ),
        contradictingEvidenceIds = ModelValidation.immutableUniqueIds(
          contradictingEvidenceIds,
          'contradictingEvidenceIds',
        ),
        relatedEntityIds = ModelValidation.immutableUniqueIds(
          relatedEntityIds,
          'relatedEntityIds',
        ),
        relatedConnectionIds = ModelValidation.immutableUniqueIds(
          relatedConnectionIds,
          'relatedConnectionIds',
        ),
        alternativeExplanations = ModelValidation.immutableRequiredTexts(
          alternativeExplanations,
          'alternativeExplanations',
        ),
        evidenceGaps = List<EvidenceGap>.unmodifiable(evidenceGaps),
        mitreAttackReferences = ModelValidation.immutableUniqueItems(
          mitreAttackReferences,
          'mitreAttackReferences',
          (reference) => reference.techniqueId,
        ) {
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be finite and between 0 and 1 inclusive.',
      );
    }
    if (reviewedAt != null && this.reviewedAt!.isBefore(this.generatedAt)) {
      throw ArgumentError.value(
        reviewedAt,
        'reviewedAt',
        'must not be earlier than generatedAt.',
      );
    }
    if (provenance.origin == DataOrigin.observedTelemetry) {
      throw ArgumentError(
        'Observed telemetry must be represented as evidence, not a hypothesis.',
      );
    }
    if (provenance.origin == DataOrigin.aiGenerated &&
        generationMetadata == null) {
      throw ArgumentError(
        'generationMetadata is required for AI-generated hypotheses.',
      );
    }
    if (provenance.origin != DataOrigin.aiGenerated &&
        generationMetadata != null) {
      throw ArgumentError(
        'generationMetadata is only valid for AI-generated hypotheses.',
      );
    }
    final supporting = this.supportingEvidenceIds.toSet();
    final contradictory = this.contradictingEvidenceIds.toSet();
    if (supporting.intersection(contradictory).isNotEmpty) {
      throw ArgumentError(
        'Supporting and contradicting evidence IDs must be disjoint.',
      );
    }
  }

  final String id;
  final String investigationId;
  final String title;
  final String explanation;
  final List<String> supportingEvidenceIds;
  final List<String> contradictingEvidenceIds;
  final List<String> relatedEntityIds;
  final List<String> relatedConnectionIds;

  /// An uncalibrated heuristic in [0, 1], not a probability or proof.
  final double confidence;

  final String confidenceExplanation;
  final HypothesisStatus status;
  final DateTime generatedAt;
  final DateTime? reviewedAt;
  final List<String> alternativeExplanations;
  final List<EvidenceGap> evidenceGaps;
  final List<MitreAttackReference> mitreAttackReferences;
  final GenerationMetadata? generationMetadata;
  final DataProvenance provenance;
}
