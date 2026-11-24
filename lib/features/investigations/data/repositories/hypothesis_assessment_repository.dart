import '../../domain/models/hypothesis_assessment.dart';

abstract interface class AnalystAssessmentRepository {
  Future<void> append(AnalystAssessment assessment);

  Future<AnalystAssessment> getById(String id);

  Future<List<AnalystAssessment>> getByHypothesisId(String hypothesisId);

  Future<List<AnalystAssessment>> getByInvestigationId(
    String investigationId,
  );
}

typedef HypothesisAssessmentRepository = AnalystAssessmentRepository;
