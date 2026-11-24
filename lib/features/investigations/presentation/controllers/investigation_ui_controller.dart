import 'package:flutter/foundation.dart';

import '../../application/models/investigation_summary.dart';
import '../../application/models/mitre_reference_verification_result.dart';
import '../../application/services/investigation_workflow_service.dart';
import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/analyst_decision.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/hypothesis_assessment.dart';
import '../../domain/models/investigation.dart';
import '../../domain/models/mitre_attack_reference.dart';
import '../../generation/models/hypothesis_generation_configuration.dart';
import '../../generation/models/hypothesis_generation_run.dart';
import '../../generation/services/hypothesis_generation_service.dart';

class InvestigationUiController extends ChangeNotifier {
  InvestigationUiController({
    required InvestigationWorkflowService workflowService,
    required HypothesisGenerationService generationService,
  })  : _workflow = workflowService,
        _generation = generationService;

  final InvestigationWorkflowService _workflow;
  final HypothesisGenerationService _generation;

  bool isLoadingList = false;
  bool isLoadingWorkspace = false;
  bool isSubmitting = false;
  String? errorMessage;
  String? activeInvestigationId;
  List<InvestigationSummary> summaries = const [];
  InvestigationSummary? summary;
  List<Evidence> evidence = const [];
  List<Hypothesis> hypotheses = const [];
  Map<String, List<AnalystAssessment>> assessmentsByHypothesis = const {};
  Map<String, List<AnalystDecision>> decisionsByHypothesis = const {};
  HypothesisGenerationRun? generationRun;
  int _workspaceLoadGeneration = 0;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _workspaceLoadGeneration++;
    super.dispose();
  }

  Future<void> loadInvestigations() async {
    if (_isDisposed) return;
    isLoadingList = true;
    errorMessage = null;
    _notifyListeners();
    try {
      final investigations = await _workflow.listInvestigations();
      summaries = await Future.wait(
        investigations.map((item) => _workflow.getSummary(item.id)),
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoadingList = false;
      _notifyListeners();
    }
  }

  Future<void> openInvestigation(String id) async {
    if (_isDisposed) return;
    final generation = ++_workspaceLoadGeneration;
    if (activeInvestigationId != id) generationRun = null;
    activeInvestigationId = id;
    isLoadingWorkspace = true;
    errorMessage = null;
    _notifyListeners();
    try {
      await _readWorkspace(id, generation: generation);
    } catch (error) {
      if (_isCurrentWorkspaceLoad(id, generation)) {
        errorMessage = error.toString();
      }
    } finally {
      if (_isCurrentWorkspaceLoad(id, generation)) {
        isLoadingWorkspace = false;
        _notifyListeners();
      }
    }
  }

  Future<Investigation?> createInvestigation({
    required String id,
    required String title,
    required String description,
    required InvestigationPriority priority,
  }) =>
      _execute(
        () => _workflow.createInvestigation(
          id: id,
          title: title,
          description: description,
          priority: priority,
        ),
        refreshList: true,
      );

  Future<Investigation?> updateMetadata({
    required String investigationId,
    String? title,
    String? description,
  }) =>
      _execute(
        () => _workflow.updateMetadata(
          investigationId: investigationId,
          title: title,
          description: description,
        ),
      );

  Future<Investigation?> changePriority({
    required String investigationId,
    required InvestigationPriority priority,
  }) =>
      _execute(
        () => _workflow.changePriority(
          investigationId: investigationId,
          priority: priority,
        ),
      );

  Future<Investigation?> changeStatus({
    required String investigationId,
    required InvestigationStatus status,
  }) =>
      _execute(
        () => _workflow.changeStatus(
          investigationId: investigationId,
          status: status,
        ),
      );

  Future<AnalystNote?> appendNote({
    required String investigationId,
    required String noteId,
    required String authorId,
    required String content,
  }) =>
      _execute(
        () => _workflow.appendAnalystNote(
          investigationId: investigationId,
          noteId: noteId,
          authorId: authorId,
          content: content,
        ),
      );

  Future<Evidence?> addEvidence(Evidence item) =>
      _execute(() => _workflow.addEvidence(item));

  Future<HypothesisGenerationRun?> generateHypotheses({
    required String investigationId,
    required HypothesisGenerationConfiguration configuration,
  }) =>
      _execute(
        () => _generation.generateForInvestigation(
          investigationId: investigationId,
          configuration: configuration,
        ),
        refreshList: true,
      );

  Future<Hypothesis?> startHypothesisReview({
    required String investigationId,
    required String hypothesisId,
  }) =>
      _execute(
        () => _workflow.startHypothesisReview(
          investigationId: investigationId,
          hypothesisId: hypothesisId,
        ),
      );

  Future<AnalystDecision?> recordDecision({
    required String investigationId,
    required String hypothesisId,
    required String decisionId,
    required String analystId,
    required String rationale,
    required AnalystDecisionType decision,
  }) =>
      _execute(
        () => _workflow.recordHypothesisDecision(
          investigationId: investigationId,
          hypothesisId: hypothesisId,
          decisionId: decisionId,
          analystId: analystId,
          rationale: rationale,
          decision: decision,
        ),
      );

  Future<AnalystAssessment?> addAssessment({
    required String id,
    required String investigationId,
    required String hypothesisId,
    required String analystId,
    required String rationale,
    required AnalystAssessmentOutcome outcome,
    required Iterable<String> evidenceReviewedIds,
    required Iterable<String> supportingEvidenceIds,
    required Iterable<String> contradictingEvidenceIds,
    Iterable<String> alternativeExplanations = const [],
    Iterable<EvidenceGap> evidenceGaps = const [],
  }) =>
      _execute(
        () => _workflow.addAssessment(
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
        ),
      );

  Future<Hypothesis?> addProposedMitreReference({
    required String hypothesisId,
    required String analystId,
    required MitreAttackReference reference,
  }) =>
      _execute(
        () => _workflow.addProposedMitreReference(
          hypothesisId: hypothesisId,
          analystId: analystId,
          reference: reference,
        ),
      );

  Future<MitreReferenceVerificationResult?> verifyMitreReference({
    required String hypothesisId,
    required String analystId,
    required String techniqueId,
  }) =>
      _execute(
        () => _workflow.verifyMitreReference(
          hypothesisId: hypothesisId,
          analystId: analystId,
          techniqueId: techniqueId,
        ),
      );

  Future<Hypothesis?> removeProposedMitreReference({
    required String hypothesisId,
    required String analystId,
    required String techniqueId,
  }) =>
      _execute(
        () => _workflow.removeProposedMitreReference(
          hypothesisId: hypothesisId,
          analystId: analystId,
          techniqueId: techniqueId,
        ),
      );

  Future<Investigation?> associateGraphEntity({
    required String investigationId,
    required String entityId,
  }) =>
      _execute(
        () => _workflow.associateGraphEntities(
          investigationId: investigationId,
          entityIds: [entityId],
        ),
      );

  Future<Investigation?> associateGraphConnection({
    required String investigationId,
    required String connectionId,
  }) =>
      _execute(
        () => _workflow.associateGraphConnections(
          investigationId: investigationId,
          connectionIds: [connectionId],
        ),
      );

  void clearError() {
    if (_isDisposed) return;
    errorMessage = null;
    _notifyListeners();
  }

  Future<T?> _execute<T>(
    Future<T> Function() operation, {
    bool refreshList = false,
  }) async {
    if (_isDisposed) return null;
    if (isSubmitting) {
      errorMessage = 'Another investigation operation is in progress.';
      _notifyListeners();
      return null;
    }
    isSubmitting = true;
    errorMessage = null;
    _notifyListeners();
    try {
      final result = await operation();
      if (_isDisposed) return result;
      final selectedId = activeInvestigationId;
      if (selectedId != null) {
        final generation = ++_workspaceLoadGeneration;
        await _readWorkspace(selectedId, generation: generation);
      }
      if (refreshList) await _readSummaries();
      return result;
    } catch (error) {
      if (!_isDisposed) errorMessage = error.toString();
      return null;
    } finally {
      isSubmitting = false;
      _notifyListeners();
    }
  }

  Future<void> _readSummaries() async {
    final investigations = await _workflow.listInvestigations();
    final nextSummaries = await Future.wait(
      investigations.map((item) => _workflow.getSummary(item.id)),
    );
    if (!_isDisposed) summaries = nextSummaries;
  }

  Future<void> _readWorkspace(
    String id, {
    required int generation,
  }) async {
    final nextSummary = await _workflow.getSummary(id);
    final nextEvidence = await _workflow.getEvidenceForInvestigation(id);
    final nextHypotheses = await _workflow.getHypothesesForInvestigation(id);
    final assessments = <String, List<AnalystAssessment>>{};
    final decisions = <String, List<AnalystDecision>>{};
    for (final hypothesis in nextHypotheses) {
      assessments[hypothesis.id] =
          await _workflow.getAssessmentHistoryForHypothesis(hypothesis.id);
      decisions[hypothesis.id] =
          await _workflow.getDecisionHistoryForHypothesis(hypothesis.id);
    }
    if (!_isCurrentWorkspaceLoad(id, generation)) return;
    summary = nextSummary;
    evidence = nextEvidence;
    hypotheses = nextHypotheses;
    assessmentsByHypothesis = Map.unmodifiable(assessments);
    decisionsByHypothesis = Map.unmodifiable(decisions);
  }

  bool _isCurrentWorkspaceLoad(String id, int generation) =>
      !_isDisposed &&
      activeInvestigationId == id &&
      _workspaceLoadGeneration == generation;

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }
}
