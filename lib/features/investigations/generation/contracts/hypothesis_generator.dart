import '../models/hypothesis_generation_request.dart';
import '../models/hypothesis_generation_result.dart';

abstract interface class HypothesisGenerator {
  String get name;

  String get version;

  Future<HypothesisGenerationResult> generate(
    HypothesisGenerationRequest request,
  );
}

abstract interface class HypothesisIdGenerator {
  String generate({
    required String investigationId,
    required String generationKey,
  });
}
