import '../../domain/models/hypothesis.dart';

sealed class HypothesisGenerationResult {
  const HypothesisGenerationResult();
}

final class HypothesesGeneratedResult extends HypothesisGenerationResult {
  HypothesesGeneratedResult(Iterable<Hypothesis> hypotheses)
      : hypotheses = List<Hypothesis>.unmodifiable(hypotheses) {
    if (this.hypotheses.isEmpty) {
      throw ArgumentError.value(
        this.hypotheses,
        'hypotheses',
        'must not be empty for a generated result.',
      );
    }
  }

  final List<Hypothesis> hypotheses;
}

final class InsufficientEvidenceResult extends HypothesisGenerationResult {
  InsufficientEvidenceResult({
    required this.message,
    Iterable<EvidenceGap> evidenceGaps = const [],
  }) : evidenceGaps = List<EvidenceGap>.unmodifiable(evidenceGaps);

  final String message;
  final List<EvidenceGap> evidenceGaps;
}

final class NoApplicableGenerationRulesResult
    extends HypothesisGenerationResult {
  const NoApplicableGenerationRulesResult(this.message);

  final String message;
}

final class InvalidGenerationContextResult extends HypothesisGenerationResult {
  const InvalidGenerationContextResult(this.message);

  final String message;
}

final class InvalidEvidenceReferencesResult extends HypothesisGenerationResult {
  const InvalidEvidenceReferencesResult(this.message);

  final String message;
}

final class InvalidGeneratedHypothesesResult
    extends HypothesisGenerationResult {
  const InvalidGeneratedHypothesesResult(this.message);

  final String message;
}

final class GenerationFailureResult extends HypothesisGenerationResult {
  const GenerationFailureResult(this.message);

  final String message;
}
