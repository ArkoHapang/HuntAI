import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/features/investigations/application/models/investigation_summary.dart';
import 'package:huntai/features/investigations/application/services/investigation_workflow_service.dart';
import 'package:huntai/features/investigations/data/datasources/in_memory_investigation_data_source.dart';
import 'package:huntai/features/investigations/data/repositories/analyst_decision_repository.dart';
import 'package:huntai/features/investigations/data/repositories/evidence_repository.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_assessment_repository.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_repository.dart';
import 'package:huntai/features/investigations/data/repositories/in_memory_investigation_repositories.dart';
import 'package:huntai/features/investigations/data/repositories/investigation_repository.dart';
import 'package:huntai/features/investigations/domain/enums/investigation_enums.dart';
import 'package:huntai/features/investigations/domain/models/investigation.dart';
import 'package:huntai/features/investigations/generation/providers/deterministic_mock_hypothesis_generator.dart';
import 'package:huntai/features/investigations/generation/services/hypothesis_generation_service.dart';
import 'package:huntai/features/investigations/presentation/controllers/investigation_ui_controller.dart';

void main() {
  test('a stale workspace load cannot replace the latest selection', () async {
    final harness = _ControllerHarness();
    addTearDown(harness.dispose);
    final first = await harness.workflow.createInvestigation(
      id: 'INV-FIRST',
      title: 'First case',
      description: '',
    );
    final second = await harness.workflow.createInvestigation(
      id: 'INV-SECOND',
      title: 'Second case',
      description: '',
    );
    final firstSummary = Completer<InvestigationSummary>();
    final secondSummary = Completer<InvestigationSummary>();
    harness.workflow.pendingSummaries[first.id] = firstSummary;
    harness.workflow.pendingSummaries[second.id] = secondSummary;

    final firstLoad = harness.controller.openInvestigation(first.id);
    final secondLoad = harness.controller.openInvestigation(second.id);
    secondSummary.complete(
      InvestigationSummary(
        investigation: second,
        evidenceCount: 0,
        hypothesisCount: 0,
        latestDecision: null,
      ),
    );
    await secondLoad;
    expect(harness.controller.summary!.investigation.id, second.id);

    firstSummary.complete(
      InvestigationSummary(
        investigation: first,
        evidenceCount: 0,
        hypothesisCount: 0,
        latestDecision: null,
      ),
    );
    await firstLoad;
    expect(harness.controller.summary!.investigation.id, second.id);
    expect(harness.controller.isLoadingWorkspace, isFalse);
  });

  test('finishing an async load after disposal does not notify disposed state',
      () async {
    final harness = _ControllerHarness();
    final investigation = await harness.workflow.createInvestigation(
      id: 'INV-DISPOSED',
      title: 'Disposed case',
      description: '',
    );
    final pending = Completer<InvestigationSummary>();
    harness.workflow.pendingSummaries[investigation.id] = pending;

    final load = harness.controller.openInvestigation(investigation.id);
    harness.dispose();
    pending.complete(
      InvestigationSummary(
        investigation: investigation,
        evidenceCount: 0,
        hypothesisCount: 0,
        latestDecision: null,
      ),
    );

    await expectLater(load, completes);
  });

  test(
      'rejected concurrent writes surface an error instead of failing silently',
      () async {
    final harness = _ControllerHarness();
    addTearDown(harness.dispose);
    final investigation = await harness.workflow.createInvestigation(
      id: 'INV-SUBMIT',
      title: 'Submission case',
      description: '',
    );
    final gate = Completer<void>();
    harness.workflow.metadataUpdateGate = gate;

    final firstUpdate = harness.controller.updateMetadata(
      investigationId: investigation.id,
      title: 'Updated case',
    );
    final duplicateUpdate = await harness.controller.changePriority(
      investigationId: investigation.id,
      priority: InvestigationPriority.high,
    );

    expect(duplicateUpdate, isNull);
    expect(
      harness.controller.errorMessage,
      contains('operation is in progress'),
    );

    gate.complete();
    expect((await firstUpdate)!.title, 'Updated case');
  });
}

class _ControllerHarness {
  _ControllerHarness() {
    dataSource = InMemoryInvestigationDataSource();
    investigations = InMemoryInvestigationRepository(dataSource);
    evidence = InMemoryEvidenceRepository(dataSource);
    hypotheses = InMemoryHypothesisRepository(dataSource);
    decisions = InMemoryAnalystDecisionRepository(dataSource);
    assessments = InMemoryAnalystAssessmentRepository(dataSource);
    workflow = _ControlledWorkflowService(
      investigationRepository: investigations,
      evidenceRepository: evidence,
      hypothesisRepository: hypotheses,
      analystDecisionRepository: decisions,
      assessmentRepository: assessments,
      graphCatalog: dataSource,
    );
    final generation = HypothesisGenerationService(
      workflowService: workflow,
      generator: DeterministicMockHypothesisGenerator(),
    );
    controller = InvestigationUiController(
      workflowService: workflow,
      generationService: generation,
    );
  }

  late final InMemoryInvestigationDataSource dataSource;
  late final InvestigationRepository investigations;
  late final EvidenceRepository evidence;
  late final HypothesisRepository hypotheses;
  late final AnalystDecisionRepository decisions;
  late final AnalystAssessmentRepository assessments;
  late final _ControlledWorkflowService workflow;
  late final InvestigationUiController controller;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
  }
}

class _ControlledWorkflowService extends InvestigationWorkflowService {
  _ControlledWorkflowService({
    required super.investigationRepository,
    required super.evidenceRepository,
    required super.hypothesisRepository,
    required super.analystDecisionRepository,
    required super.assessmentRepository,
    required super.graphCatalog,
  });

  final Map<String, Completer<InvestigationSummary>> pendingSummaries = {};
  Completer<void>? metadataUpdateGate;

  @override
  Future<InvestigationSummary> getSummary(String investigationId) =>
      pendingSummaries[investigationId]?.future ??
      super.getSummary(investigationId);

  @override
  Future<Investigation> updateMetadata({
    required String investigationId,
    String? title,
    String? description,
    String? assignedAnalystId,
    bool clearAssignedAnalyst = false,
  }) async {
    final gate = metadataUpdateGate;
    metadataUpdateGate = null;
    if (gate != null) await gate.future;
    return super.updateMetadata(
      investigationId: investigationId,
      title: title,
      description: description,
      assignedAnalystId: assignedAnalystId,
      clearAssignedAnalyst: clearAssignedAnalyst,
    );
  }
}
