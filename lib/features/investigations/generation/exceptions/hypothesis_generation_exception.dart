abstract class HypothesisGenerationException implements Exception {
  const HypothesisGenerationException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class InvalidGenerationContextException extends HypothesisGenerationException {
  const InvalidGenerationContextException(super.message);
}

class InvalidEvidenceReferencesException extends HypothesisGenerationException {
  const InvalidEvidenceReferencesException(super.message);
}

class InvalidGeneratedHypothesesException
    extends HypothesisGenerationException {
  const InvalidGeneratedHypothesesException(super.message);
}
