import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import 'hypothesis_generation_configuration.dart';

class HypothesisGenerationRequest {
  HypothesisGenerationRequest({
    required String investigationId,
    required Iterable<Evidence> evidence,
    required Iterable<Hypothesis> existingHypotheses,
    required Iterable<String> associatedEntityIds,
    required Iterable<String> associatedConnectionIds,
    required this.configuration,
  })  : investigationId = investigationId.trim(),
        evidence = List<Evidence>.unmodifiable(evidence),
        existingHypotheses = List<Hypothesis>.unmodifiable(existingHypotheses),
        associatedEntityIds = List<String>.unmodifiable(associatedEntityIds),
        associatedConnectionIds =
            List<String>.unmodifiable(associatedConnectionIds);

  final String investigationId;
  final List<Evidence> evidence;
  final List<Hypothesis> existingHypotheses;
  final List<String> associatedEntityIds;
  final List<String> associatedConnectionIds;
  final HypothesisGenerationConfiguration configuration;
}
