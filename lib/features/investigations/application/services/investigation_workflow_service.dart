import '../../data/datasources/investigation_graph_catalog.dart';
import '../../data/repositories/analyst_decision_repository.dart';
import '../../data/repositories/hypothesis_assessment_repository.dart';
import '../../data/repositories/evidence_repository.dart';
import '../../data/repositories/hypothesis_repository.dart';
import '../../data/repositories/investigation_repository.dart';
import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/analyst_decision.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/hypothesis_assessment.dart';
import '../../domain/models/investigation.dart';
import '../../domain/models/mitre_attack_reference.dart';
import '../../domain/models/model_validation.dart';
import '../../domain/validation/hypothesis_status_transition_policy.dart';
import '../exceptions/investigation_workflow_exception.dart';
import '../contracts/mitre_reference_verifier.dart';
import '../models/mitre_reference_verification_result.dart';
import '../models/investigation_summary.dart';
import 'hypothesis_assessment_service.dart';
import 'mitre_reference_workflow_service.dart';
import '../validation/investigation_workflow_validator.dart';

class InvestigationWorkflowService {
  InvestigationWorkflowService({
    required InvestigationRepository investigationRepository,
    required EvidenceRepository evidenceRepository,
    required HypothesisRepository hypothesisRepository,
    required AnalystDecisionRepository analystDecisionRepository,
    required AnalystAssessmentRepository assessmentRepository,
    required InvestigationGraphCatalog graphCatalog,
    MitreReferenceVerifier mitreReferenceVerifier =
        const UnavailableMitreReferenceVerifier(),
    DateTime Function()? clock,
  })  : _investigations = investigationRepository,
        _evidence = evidenceRepository,
        _hypotheses = hypothesisRepository,
        _decisions = analystDecisionRepository,
        _graphCatalog = graphCatalog,
        _assessmentWorkflow = AnalystAssessmentService(
          investigationRepository: investigationRepository,
          evidenceRepository: evidenceRepository,
          hypothesisRepository: hypothesisRepository,
          assessmentRepository: assessmentRepository,
          clock: clock,
        ),
        _mitreReferenceWorkflow = MitreReferenceWorkflowService(
          hypothesisRepository: hypothesisRepository,
          investigationRepository: investigationRepository,
          verifier: mitreReferenceVerifier,
          clock: clock,
        ),
        _clock = clock ?? DateTime.now;

  final InvestigationRepository _investigations;
  final EvidenceRepository _evidence;
  final HypothesisRepository _hypotheses;
  final AnalystDecisionRepository _decisions;
  final InvestigationGraphCatalog _graphCatalog;
  final AnalystAssessmentService _assessmentWorkflow;
  final MitreReferenceWorkflowService _mitreReferenceWorkflow;
  final DateTime Function() _clock;

  Future<Investigation> createInvestigation({
    required String id,
    required String title,
    required String description,
    InvestigationPriority priority = InvestigationPriority.medium,
    String? assignedAnalystId,
    Iterable<String> relatedEntityIds = const [],
    Iterable<String> relatedConnectionIds = const [],
  }) async {
    final entityIds = List<String>.of(relatedEntityIds);
    final connectionIds = List<String>.of(relatedConnectionIds);
    InvestigationWorkflowValidator.validateKnownGraphReferences(
      entityIds: entityIds,
      connectionIds: connectionIds,
      graphCatalog: _graphCatalog,
    );
    final now = _now();
    final investigation = _buildInvestigation(
      id: id,
      title: title,
      description: description,
      status: InvestigationStatus.draft,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      assignedAnalystId: assignedAnalystId,
      relatedEntityIds: entityIds,
      relatedConnectionIds: connectionIds,
    );
    await _investigations.create(investigation);
    return investigation;
  }

  Future<Investigation> getInvestigation(String id) =>
      _investigations.getById(id);

  Future<List<Investigation>> listInvestigations({
    InvestigationStatus? status,
    InvestigationPriority? priority,
  }) async {
    if (status != null) {
      final investigations = await _investigations.getByStatus(status);
      return List<Investigation>.unmodifiable(
        priority == null
            ? investigations
            : investigations.where((item) => item.priority == priority),
      );
    }
    if (priority != null) {
      return List<Investigation>.unmodifiable(
        await _investigations.getByPriority(priority),
      );
    }
    return List<Investigation>.unmodifiable(await _investigations.getAll());
  }

  Future<Investigation> changeStatus({
    required String investigationId,
    required InvestigationStatus status,
  }) async {
    final current = await _getOpenInvestigation(investigationId);
    InvestigationWorkflowValidator.validateLifecycleTransition(
      current.status,
      status,
    );
    return _saveInvestigation(
      _copyInvestigation(
        current,
        status: status,
        updatedAt: _nextUpdatedAt(current),
      ),
    );
  }

  Future<Investigation> closeInvestigation(String investigationId) =>
      changeStatus(
        investigationId: investigationId,
        status: InvestigationStatus.closed,
      );

  Future<Investigation> changePriority({
    required String investigationId,
    required InvestigationPriority priority,
  }) async {
    final current = await _getOpenInvestigation(investigationId);
    return _saveInvestigation(
      _copyInvestigation(
        current,
        priority: priority,
        updatedAt: _nextUpdatedAt(current),
      ),
    );
  }

  Future<Investigation> updateMetadata({
    required String investigationId,
    String? title,
    String? description,
    String? assignedAnalystId,
    bool clearAssignedAnalyst = false,
  }) async {
    if (title == null &&
        description == null &&
        assignedAnalystId == null &&
        !clearAssignedAnalyst) {
      throw const InvalidWorkflowInputException(
        'At least one editable metadata field must be provided.',
      );
    }
    if (assignedAnalystId != null && clearAssignedAnalyst) {
      throw const InvalidWorkflowInputException(
        'An analyst cannot be assigned and cleared in the same update.',
      );
    }
    final current = await _getOpenInvestigation(investigationId);
    return _saveInvestigation(
      _copyInvestigation(
        current,
        title: title,
        description: description,
        assignedAnalystId: assignedAnalystId,
        clearAssignedAnalyst: clearAssignedAnalyst,
        updatedAt: _nextUpdatedAt(current),
      ),
    );
  }

  Future<Investigation> associateGraphEntities({
    required String investigationId,
    required Iterable<String> entityIds,
  }) async {
    final current = await _getOpenInvestigation(investigationId);
    final updatedIds = InvestigationWorkflowValidator.graphAssociations(
      requestedIds: entityIds,
      currentIds: current.relatedEntityIds,
      knownIds: _graphCatalog.availableEntityIds,
      graphType: 'Graph entity',
    );
    return _saveInvestigation(
      _copyInvestigation(
        current,
        relatedEntityIds: updatedIds,
        updatedAt: _nextUpdatedAt(current),
      ),
    );
  }

  Future<Investigation> associateGraphConnections({
    required String investigationId,
    required Iterable<String> connectionIds,
  }) async {
    final current = await _getOpenInvestigation(investigationId);
    final updatedIds = InvestigationWorkflowValidator.graphAssociations(
      requestedIds: connectionIds,
      currentIds: current.relatedConnectionIds,
      knownIds: _graphCatalog.availableConnectionIds,
      graphType: 'Graph connection',
    );
    return _saveInvestigation(
      _copyInvestigation(
        current,
        relatedConnectionIds: updatedIds,
        updatedAt: _nextUpdatedAt(current),
      ),
    );
  }

  Future<Evidence> addEvidence(Evidence evidence) async {
    final investigation = await _getOpenInvestigation(evidence.investigationId);
    InvestigationWorkflowValidator.validateEvidence(
      investigation: investigation,
      evidence: evidence,
      graphCatalog: _graphCatalog,
    );
    await _evidence.add(evidence);
    return evidence;
  }

  Future<List<Evidence>> getEvidenceForInvestigation(
    String investigationId,
  ) async {
    await _investigations.getById(investigationId);
    return List<Evidence>.unmodifiable(
      await _evidence.getAllForInvestigation(investigationId),
    );
  }

  Future<AnalystNote> appendAnalystNote({
    required String investigationId,
    required String noteId,
    required String authorId,
    required String content,
  }) async {
    final current = await _getOpenInvestigation(investigationId);
    if (current.analystNotes.any((note) => note.id == noteId.trim())) {
      throw InvalidWorkflowInputException(
        'Analyst note "$noteId" already exists.',
      );
    }
    final note = _buildAnalystNote(
      id: noteId,
      authorId: authorId,
      text: content,
      timestamp: _now(),
    );
    await _saveInvestigation(
      _copyInvestigation(
        current,
        analystNotes: [...current.analystNotes, note],
        updatedAt: _nextUpdatedAt(current),
      ),
    );
    return note;
  }

  Future<List<Hypothesis>> getHypothesesForInvestigation(
    String investigationId,
  ) async {
    await _investigations.getById(investigationId);
    return List<Hypothesis>.unmodifiable(
      await _hypotheses.getByInvestigationId(investigationId),
    );
  }

  Future<List<Hypothesis>> addHypotheses({
    required String investigationId,
    required Iterable<Hypothesis> hypotheses,
  }) async {
    final investigation = await _getOpenInvestigation(investigationId);
    final batch = List<Hypothesis>.of(hypotheses);
    final ids = <String>{};
    for (final hypothesis in batch) {
      if (hypothesis.investigationId != investigation.id) {
        throw const InvalidWorkflowInputException(
          'Every hypothesis must belong to the requested investigation.',
        );
      }
      if (!ids.add(hypothesis.id)) {
        throw InvalidWorkflowInputException(
          'Hypothesis "${hypothesis.id}" occurs more than once in the batch.',
        );
      }
    }
    if (batch.isNotEmpty) {
      await _hypotheses.addAll(batch);
    }
    return List<Hypothesis>.unmodifiable(batch);
  }

  Future<AnalystAssessment> addAssessment({
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
  }) =>
      _assessmentWorkflow.createAssessment(
        id: id,
        investigationId: investigationId,
        hypothesisId: hypothesisId,
        analystId: analystId,
        rationale: rationale,
        outcome: outcome,
        evidenceReviewedIds: evidenceReviewedIds,
        supportingEvidenceIds: supportingEvidenceIds,
        contradictingEvidenceIds: contradictingEvidenceIds,
        alternativeExplanations: alternativeExplanations,
        evidenceGaps: evidenceGaps,
      );

  Future<AnalystAssessment> getAssessment(String id) =>
      _assessmentWorkflow.getById(id);

  Future<List<AnalystAssessment>> getAssessmentHistoryForHypothesis(
    String hypothesisId,
  ) =>
      _assessmentWorkflow.getByHypothesisId(hypothesisId);

  Future<List<AnalystAssessment>> getAssessmentsForInvestigation(
    String investigationId,
  ) =>
      _assessmentWorkflow.getByInvestigationId(investigationId);

  Future<Hypothesis> addProposedMitreReference({
    required String hypothesisId,
    required String analystId,
    required MitreAttackReference reference,
  }) =>
      _mitreReferenceWorkflow.addProposedReference(
        hypothesisId: hypothesisId,
        analystId: analystId,
        reference: reference,
      );

  Future<List<MitreAttackReference>> getMitreReferencesForHypothesis(
    String hypothesisId,
  ) =>
      _mitreReferenceWorkflow.getReferencesForHypothesis(hypothesisId);

  Future<Hypothesis> removeProposedMitreReference({
    required String hypothesisId,
    required String analystId,
    required String techniqueId,
  }) =>
      _mitreReferenceWorkflow.removeProposedReference(
        hypothesisId: hypothesisId,
        analystId: analystId,
        techniqueId: techniqueId,
      );

  Future<MitreReferenceVerificationResult> verifyMitreReference({
    required String hypothesisId,
    required String analystId,
    required String techniqueId,
  }) =>
      _mitreReferenceWorkflow.verifyReference(
        hypothesisId: hypothesisId,
        analystId: analystId,
        techniqueId: techniqueId,
      );

  Future<Hypothesis> startHypothesisReview({
    required String investigationId,
    required String hypothesisId,
  }) async {
    final investigation = await _getOpenInvestigation(investigationId);
    final current = await _hypotheses.getById(hypothesisId);
    InvestigationWorkflowValidator.validateHypothesisRelationship(
      investigation: investigation,
      hypothesis: current,
    );
    InvestigationWorkflowValidator.validateHypothesisTransition(
      current.status,
      HypothesisStatus.underReview,
    );
    final reviewedAt = _now();
    _ensureReviewTimeDoesNotRegress(current, reviewedAt);
    return _hypotheses.updateReviewStatus(
      hypothesisId: current.id,
      status: HypothesisStatus.underReview,
      reviewedAt: reviewedAt,
    );
  }

  Future<AnalystDecision> acceptHypothesis({
    required String investigationId,
    required String hypothesisId,
    required String decisionId,
    required String analystId,
    required String rationale,
  }) =>
      recordHypothesisDecision(
        investigationId: investigationId,
        hypothesisId: hypothesisId,
        decisionId: decisionId,
        analystId: analystId,
        rationale: rationale,
        decision: AnalystDecisionType.accept,
      );

  Future<AnalystDecision> rejectHypothesis({
    required String investigationId,
    required String hypothesisId,
    required String decisionId,
    required String analystId,
    required String rationale,
  }) =>
      recordHypothesisDecision(
        investigationId: investigationId,
        hypothesisId: hypothesisId,
        decisionId: decisionId,
        analystId: analystId,
        rationale: rationale,
        decision: AnalystDecisionType.reject,
      );

  Future<AnalystDecision> deferHypothesis({
    required String investigationId,
    required String hypothesisId,
    required String decisionId,
    required String analystId,
    required String rationale,
  }) =>
      recordHypothesisDecision(
        investigationId: investigationId,
        hypothesisId: hypothesisId,
        decisionId: decisionId,
        analystId: analystId,
        rationale: rationale,
        decision: AnalystDecisionType.defer,
      );

  Future<AnalystDecision> markHypothesisInconclusive({
    required String investigationId,
    required String hypothesisId,
    required String decisionId,
    required String analystId,
    required String rationale,
  }) =>
      recordHypothesisDecision(
        investigationId: investigationId,
        hypothesisId: hypothesisId,
        decisionId: decisionId,
        analystId: analystId,
        rationale: rationale,
        decision: AnalystDecisionType.inconclusive,
      );

  Future<AnalystDecision> recordHypothesisDecision({
    required String investigationId,
    required String hypothesisId,
    required String decisionId,
    required String analystId,
    required String rationale,
    required AnalystDecisionType decision,
  }) async {
    final investigation = await _getOpenInvestigation(investigationId);
    final current = await _hypotheses.getById(hypothesisId);
    InvestigationWorkflowValidator.validateHypothesisRelationship(
      investigation: investigation,
      hypothesis: current,
    );
    final nextStatus =
        HypothesisStatusTransitionPolicy.statusForDecision(decision);
    InvestigationWorkflowValidator.validateHypothesisTransition(
      current.status,
      nextStatus,
    );
    final decidedAt = _now();
    _ensureReviewTimeDoesNotRegress(current, decidedAt);
    final updatedHypothesis = _copyHypothesisForReview(
      current,
      status: nextStatus,
      reviewedAt: decidedAt,
    );
    final analystDecision = _buildAnalystDecision(
      id: decisionId,
      investigationId: investigationId,
      hypothesisId: hypothesisId,
      decision: decision,
      rationale: rationale,
      analystId: analystId,
      decidedAt: decidedAt,
    );
    await _decisions.appendReview(
      decision: analystDecision,
      updatedHypothesis: updatedHypothesis,
    );
    return analystDecision;
  }

  Future<List<AnalystDecision>> getDecisionHistoryForHypothesis(
    String hypothesisId,
  ) async =>
      List<AnalystDecision>.unmodifiable(
        await _decisions.getHistoryForHypothesis(hypothesisId),
      );

  Future<InvestigationSummary> getSummary(String investigationId) async {
    final investigation = await _investigations.getById(investigationId);
    final evidence = await _evidence.getAllForInvestigation(investigationId);
    final hypotheses = await _hypotheses.getByInvestigationId(investigationId);
    final decisions =
        await _decisions.getHistoryForInvestigation(investigationId);
    return InvestigationSummary(
      investigation: investigation,
      evidenceCount: evidence.length,
      hypothesisCount: hypotheses.length,
      latestDecision: decisions.isEmpty ? null : decisions.last,
    );
  }

  Future<Investigation> _getOpenInvestigation(String id) async {
    final investigation = await _investigations.getById(id);
    InvestigationWorkflowValidator.requireOpen(investigation);
    return investigation;
  }

  Future<Investigation> _saveInvestigation(Investigation investigation) async {
    return _investigations.update(investigation);
  }

  Investigation _buildInvestigation({
    required String id,
    required String title,
    required String description,
    required InvestigationStatus status,
    required InvestigationPriority priority,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? assignedAnalystId,
    Iterable<String> relatedEntityIds = const [],
    Iterable<String> relatedConnectionIds = const [],
    Iterable<String> evidenceIds = const [],
    Iterable<String> hypothesisIds = const [],
    Iterable<AnalystNote> analystNotes = const [],
  }) {
    try {
      return Investigation(
        id: id,
        title: title,
        description: description,
        status: status,
        priority: priority,
        createdAt: createdAt,
        updatedAt: updatedAt,
        assignedAnalystId: assignedAnalystId,
        relatedEntityIds: relatedEntityIds,
        relatedConnectionIds: relatedConnectionIds,
        evidenceIds: evidenceIds,
        hypothesisIds: hypothesisIds,
        analystNotes: analystNotes,
      );
    } on ArgumentError catch (error) {
      throw InvalidWorkflowInputException(error.message.toString());
    }
  }

  Investigation _copyInvestigation(
    Investigation current, {
    String? title,
    String? description,
    InvestigationStatus? status,
    InvestigationPriority? priority,
    String? assignedAnalystId,
    bool clearAssignedAnalyst = false,
    Iterable<String>? relatedEntityIds,
    Iterable<String>? relatedConnectionIds,
    Iterable<AnalystNote>? analystNotes,
    required DateTime updatedAt,
  }) =>
      _buildInvestigation(
        id: current.id,
        title: title ?? current.title,
        description: description ?? current.description,
        status: status ?? current.status,
        priority: priority ?? current.priority,
        createdAt: current.createdAt,
        updatedAt: updatedAt,
        assignedAnalystId: clearAssignedAnalyst
            ? null
            : assignedAnalystId ?? current.assignedAnalystId,
        relatedEntityIds: relatedEntityIds ?? current.relatedEntityIds,
        relatedConnectionIds:
            relatedConnectionIds ?? current.relatedConnectionIds,
        evidenceIds: current.evidenceIds,
        hypothesisIds: current.hypothesisIds,
        analystNotes: analystNotes ?? current.analystNotes,
      );

  AnalystNote _buildAnalystNote({
    required String id,
    required String authorId,
    required String text,
    required DateTime timestamp,
  }) {
    try {
      return AnalystNote(
        id: id,
        authorId: authorId,
        text: text,
        timestamp: timestamp,
      );
    } on ArgumentError catch (error) {
      throw InvalidWorkflowInputException(error.message.toString());
    }
  }

  Hypothesis _copyHypothesisForReview(
    Hypothesis current, {
    required HypothesisStatus status,
    required DateTime reviewedAt,
  }) {
    try {
      return Hypothesis(
        id: current.id,
        investigationId: current.investigationId,
        title: current.title,
        explanation: current.explanation,
        supportingEvidenceIds: current.supportingEvidenceIds,
        contradictingEvidenceIds: current.contradictingEvidenceIds,
        relatedEntityIds: current.relatedEntityIds,
        relatedConnectionIds: current.relatedConnectionIds,
        confidence: current.confidence,
        confidenceExplanation: current.confidenceExplanation,
        status: status,
        generatedAt: current.generatedAt,
        reviewedAt: reviewedAt,
        alternativeExplanations: current.alternativeExplanations,
        evidenceGaps: current.evidenceGaps,
        mitreAttackReferences: current.mitreAttackReferences,
        generationMetadata: current.generationMetadata,
        provenance: current.provenance,
      );
    } on ArgumentError catch (error) {
      throw InvalidWorkflowInputException(error.message.toString());
    }
  }

  AnalystDecision _buildAnalystDecision({
    required String id,
    required String investigationId,
    required String hypothesisId,
    required AnalystDecisionType decision,
    required String rationale,
    required String analystId,
    required DateTime decidedAt,
  }) {
    try {
      ModelValidation.requiredText(rationale, 'rationale');
      return AnalystDecision(
        id: id,
        investigationId: investigationId,
        hypothesisId: hypothesisId,
        decision: decision,
        rationale: rationale,
        analystId: analystId,
        decidedAt: decidedAt,
      );
    } on ArgumentError catch (error) {
      throw InvalidWorkflowInputException(error.message.toString());
    }
  }

  DateTime _now() => _clock().toUtc();

  DateTime _nextUpdatedAt(Investigation investigation) {
    final now = _now();
    if (now.isBefore(investigation.updatedAt)) {
      throw const InvalidWorkflowInputException(
        'The workflow clock cannot move an investigation update backward.',
      );
    }
    return now;
  }

  void _ensureReviewTimeDoesNotRegress(Hypothesis hypothesis, DateTime time) {
    if (time.isBefore(hypothesis.generatedAt) ||
        (hypothesis.reviewedAt != null &&
            time.isBefore(hypothesis.reviewedAt!))) {
      throw const InvalidWorkflowInputException(
        'The workflow clock cannot move a hypothesis review backward.',
      );
    }
  }
}
