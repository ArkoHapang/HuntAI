enum EvidenceCuePolarity { supporting, contradicting }

/// Caller-supplied mock cue; it is not inferred from the evidence text.
class EvidenceGenerationCue {
  const EvidenceGenerationCue({
    required this.evidenceId,
    required this.polarity,
  });

  final String evidenceId;
  final EvidenceCuePolarity polarity;
}

class HypothesisGenerationConfiguration {
  HypothesisGenerationConfiguration({
    Iterable<EvidenceGenerationCue> evidenceCues = const [],
    this.minimumSupportingEvidence = 1,
    this.maximumHypotheses = 3,
  }) : evidenceCues = List<EvidenceGenerationCue>.unmodifiable(evidenceCues);

  final List<EvidenceGenerationCue> evidenceCues;
  final int minimumSupportingEvidence;
  final int maximumHypotheses;
}
