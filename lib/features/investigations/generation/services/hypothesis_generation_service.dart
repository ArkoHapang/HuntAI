import '../../application/services/investigation_workflow_service.dart';
import '../../data/exceptions/investigation_repository_exception.dart';
import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/investigation.dart';
import '../contracts/hypothesis_generator.dart';
import '../exceptions/hypothesis_generation_exception.dart';
import '../models/hypothesis_generation_configuration.dart';
import '../models/hypothesis_generation_request.dart';
import '../models/hypothesis_generation_result.dart';
import '../models/hypothesis_generation_run.dart';
import 'hypothesis_generation_validation.dart';

class HypothesisGenerationService {
  HypothesisGenerationService({
    required InvestigationWorkflowService workflowService,
    required HypothesisGenerator generator,
  })  : _workflow = workflowService,
        _generator = generator;

  final InvestigationWorkflowService _workflow;
  final HypothesisGenerator _generator;

  Future<HypothesisGenerationRun> generateForInvestigation({
    required String investigationId,
    HypothesisGenerationConfiguration? configuration,
  }) async {
    late final Investigation investigation;
    try {
      investigation = await _workflow.getInvestigation(investigationId);
    } on RecordNotFoundException catch (error) {
      return _run(InvalidGenerationContextResult(error.message));
    }
    if (investigation.status == InvestigationStatus.closed) {
      return _run(
        const InvalidGenerationContextResult(
          'Hypotheses cannot be generated for a closed investigation.',
        ),
      );
    }

    final evidence =
        await _workflow.getEvidenceForInvestigation(investigationId);
    final existingHypotheses =
        await _workflow.getHypothesesForInvestigation(investigationId);
    final request = HypothesisGenerationRequest(
      investigationId: investigation.id,
      evidence: evidence,
      existingHypotheses: existingHypotheses,
      associatedEntityIds: investigation.relatedEntityIds,
      associatedConnectionIds: investigation.relatedConnectionIds,
      configuration: configuration ?? HypothesisGenerationConfiguration(),
    );

    try {
      HypothesisGenerationValidation.validateRequest(request);
    } on InvalidGenerationContextException catch (error) {
      return _run(InvalidGenerationContextResult(error.message));
    } on InvalidEvidenceReferencesException catch (error) {
      return _run(InvalidEvidenceReferencesResult(error.message));
    }

    late final HypothesisGenerationResult result;
    try {
      result = await _generator.generate(request);
    } on HypothesisGenerationException catch (error) {
      return _run(GenerationFailureResult(error.message));
    }
    if (result is! HypothesesGeneratedResult) {
      return _run(result);
    }

    try {
      HypothesisGenerationValidation.validateGeneratedHypotheses(
        request: request,
        hypotheses: result.hypotheses,
        generatorName: _generator.name,
        generatorVersion: _generator.version,
      );
    } on InvalidGenerationContextException catch (error) {
      return _run(InvalidGenerationContextResult(error.message));
    } on InvalidEvidenceReferencesException catch (error) {
      return _run(InvalidEvidenceReferencesResult(error.message));
    } on InvalidGeneratedHypothesesException catch (error) {
      return _run(InvalidGeneratedHypothesesResult(error.message));
    }

    final existingById = {
      for (final hypothesis in existingHypotheses) hypothesis.id: hypothesis,
    };
    final newHypotheses = <Hypothesis>[];
    final alreadyPresent = <Hypothesis>[];
    for (final generated in result.hypotheses) {
      final existing = existingById[generated.id];
      if (existing == null) {
        Hypothesis? contentMatch;
        for (final candidate in existingHypotheses) {
          if (HypothesisGenerationValidation.equivalentGeneratedContent(
            candidate,
            generated,
          )) {
            contentMatch = candidate;
            break;
          }
        }
        if (contentMatch != null) {
          alreadyPresent.add(contentMatch);
        } else {
          newHypotheses.add(generated);
        }
      } else if (HypothesisGenerationValidation.equivalentGeneratedContent(
        existing,
        generated,
      )) {
        alreadyPresent.add(existing);
      } else {
        return _run(
          InvalidGeneratedHypothesesResult(
            'Generated hypothesis ID "${generated.id}" conflicts with an '
            'existing record.',
          ),
        );
      }
    }

    if (newHypotheses.isNotEmpty) {
      await _workflow.addHypotheses(
        investigationId: investigation.id,
        hypotheses: newHypotheses,
      );
    }
    return HypothesisGenerationRun(
      result: result,
      newlyPersisted: newHypotheses,
      alreadyPresent: alreadyPresent,
    );
  }

  HypothesisGenerationRun _run(HypothesisGenerationResult result) =>
      HypothesisGenerationRun(result: result);
}
