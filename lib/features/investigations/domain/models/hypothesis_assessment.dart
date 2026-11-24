import 'hypothesis.dart';
import 'model_validation.dart';

enum AnalystAssessmentOutcome {
  supports,
  partiallySupports,
  doesNotSupport,
  inconclusive,
  needsMoreEvidence,
}

abstract final class HypothesisAssessmentOutcome {
  static const supportsHypothesis = AnalystAssessmentOutcome.supports;
  static const partiallySupportsHypothesis =
      AnalystAssessmentOutcome.partiallySupports;
  static const doesNotSupportHypothesis =
      AnalystAssessmentOutcome.doesNotSupport;
  static const inconclusive = AnalystAssessmentOutcome.inconclusive;
  static const requiresAdditionalEvidence =
      AnalystAssessmentOutcome.needsMoreEvidence;
}

class AnalystAssessment {
  AnalystAssessment({
    required String id,
    required String investigationId,
    required String hypothesisId,
    required String analystId,
    required DateTime assessedAt,
    required String rationale,
    required this.outcome,
    Iterable<String> evidenceReviewedIds = const [],
    Iterable<String> supportingEvidenceIds = const [],
    Iterable<String> contradictingEvidenceIds = const [],
    Iterable<String> alternativeExplanations = const [],
    Iterable<EvidenceGap> evidenceGaps = const [],
  })  : id = ModelValidation.requiredIdentifier(id, 'id'),
        investigationId = ModelValidation.requiredIdentifier(
            investigationId, 'investigationId'),
        hypothesisId =
            ModelValidation.requiredIdentifier(hypothesisId, 'hypothesisId'),
        analystId = ModelValidation.requiredIdentifier(analystId, 'analystId'),
        assessedAt = ModelValidation.utc(assessedAt),
        rationale = _meaningfulRationale(rationale),
        evidenceReviewedIds = ModelValidation.immutableUniqueIds(
          evidenceReviewedIds,
          'evidenceReviewedIds',
        ),
        supportingEvidenceIds = ModelValidation.immutableUniqueIds(
          supportingEvidenceIds,
          'supportingEvidenceIds',
        ),
        contradictingEvidenceIds = ModelValidation.immutableUniqueIds(
          contradictingEvidenceIds,
          'contradictingEvidenceIds',
        ),
        alternativeExplanations = ModelValidation.immutableRequiredTexts(
          alternativeExplanations,
          'alternativeExplanations',
        ),
        evidenceGaps = List<EvidenceGap>.unmodifiable(evidenceGaps) {
    final reviewed = this.evidenceReviewedIds.toSet();
    final supporting = this.supportingEvidenceIds.toSet();
    final contradicting = this.contradictingEvidenceIds.toSet();
    if (supporting.intersection(contradicting).isNotEmpty) {
      throw ArgumentError(
        'Supporting and contradicting evidence IDs must be disjoint.',
      );
    }
    if (!reviewed.containsAll(supporting) ||
        !reviewed.containsAll(contradicting)) {
      throw ArgumentError(
        'Supporting and contradicting evidence must be listed as reviewed.',
      );
    }
  }

  final String id;
  final String investigationId;
  final String hypothesisId;
  final String analystId;
  final DateTime assessedAt;
  final String rationale;
  final AnalystAssessmentOutcome outcome;
  final List<String> evidenceReviewedIds;
  final List<String> supportingEvidenceIds;
  final List<String> contradictingEvidenceIds;
  final List<String> alternativeExplanations;
  final List<EvidenceGap> evidenceGaps;

  static String _meaningfulRationale(String value) {
    final rationale = ModelValidation.requiredText(value, 'rationale');
    if (rationale.trim().length < 8) {
      throw ArgumentError.value(
        value,
        'rationale',
        'must contain at least 8 non-whitespace characters.',
      );
    }
    return rationale;
  }
}

typedef HypothesisAssessment = AnalystAssessment;
