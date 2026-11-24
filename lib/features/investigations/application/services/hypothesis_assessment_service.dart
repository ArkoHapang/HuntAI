import '../../data/repositories/evidence_repository.dart';
import '../../data/repositories/hypothesis_assessment_repository.dart';
import '../../data/repositories/hypothesis_repository.dart';
import '../../data/repositories/investigation_repository.dart';
import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/hypothesis_assessment.dart';
import '../exceptions/investigation_workflow_exception.dart';

class AnalystAssessmentService {
  AnalystAssessmentService({
    required InvestigationRepository investigationRepository,
    required EvidenceRepository evidenceRepository,
    required HypothesisRepository hypothesisRepository,
    required AnalystAssessmentRepository assessmentRepository,
    DateTime Function()? clock,
  })  : _investigations = investigationRepository,
        _evidence = evidenceRepository,
        _hypotheses = hypothesisRepository,
        _assessments = assessmentRepository,
        _clock = clock ?? DateTime.now;

  final InvestigationRepository _investigations;
  final EvidenceRepository _evidence;
  final HypothesisRepository _hypotheses;
  final AnalystAssessmentRepository _assessments;
  final DateTime Function() _clock;

  Future<AnalystAssessment> createAssessment({
    required String id,
    required String investigationId,
    required String hypothesisId,
    required String analystId,
    required String rationale,
    required AnalystAssessmentOutcome outcome,
    Iterable<String> evidenceReviewedIds = const [],
    Iterable<String> supportingEvidenceIds = const [],
    Iterable<String> contradictingEvidenceIds = const [],
    Iterable<String> alternativeExplanations = const [],
    Iterable<EvidenceGap> evidenceGaps = const [],
  }) async {
    final assessment = _buildAssessment(
      id: id,
      investigationId: investigationId,
      hypothesisId: hypothesisId,
      analystId: analystId,
      assessedAt: _clock().toUtc(),
      rationale: rationale,
      outcome: outcome,
      evidenceReviewedIds: evidenceReviewedIds,
      supportingEvidenceIds: supportingEvidenceIds,
      contradictingEvidenceIds: contradictingEvidenceIds,
      alternativeExplanations: alternativeExplanations,
      evidenceGaps: evidenceGaps,
    );

    final investigation =
        await _investigations.getById(assessment.investigationId);
    if (investigation.status == InvestigationStatus.closed) {
      throw InvestigationClosedException(investigation.id);
    }
    final hypothesis = await _hypotheses.getById(assessment.hypothesisId);
    if (hypothesis.investigationId != assessment.investigationId) {
      throw const InvalidWorkflowInputException(
        'Assessment and hypothesis must belong to the same investigation.',
      );
    }

    final evidenceIds = {
      ...assessment.evidenceReviewedIds,
      ...assessment.supportingEvidenceIds,
      ...assessment.contradictingEvidenceIds,
    };
    for (final evidenceId in evidenceIds) {
      final evidence = await _evidence.getById(evidenceId);
      if (evidence.investigationId != assessment.investigationId) {
        throw InvalidWorkflowInputException(
          'Evidence "$evidenceId" belongs to another investigation.',
        );
      }
    }

    await _assessments.append(assessment);
    return assessment;
  }

  Future<List<AnalystAssessment>> getByHypothesisId(
    String hypothesisId,
  ) =>
      _assessments.getByHypothesisId(hypothesisId);

  Future<AnalystAssessment> getById(String id) => _assessments.getById(id);

  Future<List<AnalystAssessment>> getByInvestigationId(
    String investigationId,
  ) =>
      _assessments.getByInvestigationId(investigationId);

  AnalystAssessment _buildAssessment({
    required String id,
    required String investigationId,
    required String hypothesisId,
    required String analystId,
    required DateTime assessedAt,
    required String rationale,
    required AnalystAssessmentOutcome outcome,
    required Iterable<String> evidenceReviewedIds,
    required Iterable<String> supportingEvidenceIds,
    required Iterable<String> contradictingEvidenceIds,
    required Iterable<String> alternativeExplanations,
    required Iterable<EvidenceGap> evidenceGaps,
  }) {
    try {
      return AnalystAssessment(
        id: id,
        investigationId: investigationId,
        hypothesisId: hypothesisId,
        analystId: analystId,
        assessedAt: assessedAt,
        rationale: rationale,
        outcome: outcome,
        evidenceReviewedIds: evidenceReviewedIds,
        supportingEvidenceIds: supportingEvidenceIds,
        contradictingEvidenceIds: contradictingEvidenceIds,
        alternativeExplanations: alternativeExplanations,
        evidenceGaps: evidenceGaps,
      );
    } on ArgumentError catch (error) {
      throw InvalidWorkflowInputException(error.message.toString());
    }
  }
}

typedef HypothesisAssessmentService = AnalystAssessmentService;
