import 'hypothesis_generation_result.dart';
import '../../domain/models/hypothesis.dart';

class HypothesisGenerationRun {
  HypothesisGenerationRun({
    required this.result,
    Iterable<Hypothesis> newlyPersisted = const [],
    Iterable<Hypothesis> alreadyPresent = const [],
  })  : newlyPersisted = List<Hypothesis>.unmodifiable(newlyPersisted),
        alreadyPresent = List<Hypothesis>.unmodifiable(alreadyPresent);

  final HypothesisGenerationResult result;
  final List<Hypothesis> newlyPersisted;
  final List<Hypothesis> alreadyPresent;
}
