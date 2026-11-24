import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/features/investigations/application/exceptions/investigation_workflow_exception.dart';
import 'package:huntai/features/investigations/application/services/investigation_workflow_service.dart';
import 'package:huntai/features/investigations/data/datasources/in_memory_investigation_data_source.dart';
import 'package:huntai/features/investigations/data/exceptions/investigation_repository_exception.dart';
import 'package:huntai/features/investigations/data/repositories/analyst_decision_repository.dart';
import 'package:huntai/features/investigations/data/repositories/evidence_repository.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_assessment_repository.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_repository.dart';
import 'package:huntai/features/investigations/data/repositories/in_memory_investigation_repositories.dart';
import 'package:huntai/features/investigations/data/repositories/investigation_repository.dart';
import 'package:huntai/features/investigations/domain/enums/investigation_enums.dart';
import 'package:huntai/features/investigations/domain/models/analyst_decision.dart';
import 'package:huntai/features/investigations/domain/models/data_provenance.dart';
import 'package:huntai/features/investigations/domain/models/evidence.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis_assessment.dart';
import 'package:huntai/features/investigations/domain/models/investigation.dart';
import 'package:huntai/features/investigations/domain/models/mitre_attack_reference.dart';
import 'package:huntai/features/investigations/application/models/mitre_reference_verification_result.dart';

final _baseTime = DateTime.utc(2026, 12, 4, 9);

void main() {
  late DateTime now;
  late InMemoryInvestigationDataSource dataSource;
  late InvestigationRepository investigations;
  late EvidenceRepository evidence;
  late HypothesisRepository hypotheses;
  late AnalystDecisionRepository decisions;
  late AnalystAssessmentRepository assessments;
  late InvestigationWorkflowService service;

  setUp(() {
    now = _baseTime;
    dataSource = InMemoryInvestigationDataSource(
      availableEntityIds: const ['entity-1', 'entity-2'],
      availableConnectionIds: const ['connection-1', 'connection-2'],
      clock: () => now,
    );
    investigations = InMemoryInvestigationRepository(dataSource);
    evidence = InMemoryEvidenceRepository(dataSource);
    hypotheses = InMemoryHypothesisRepository(dataSource);
    decisions = InMemoryAnalystDecisionRepository(dataSource);
    assessments = InMemoryAnalystAssessmentRepository(dataSource);
    service = InvestigationWorkflowService(
      investigationRepository: investigations,
      evidenceRepository: evidence,
      hypothesisRepository: hypotheses,
      analystDecisionRepository: decisions,
      assessmentRepository: assessments,
      graphCatalog: dataSource,
      clock: () => now,
    );
  });

  Future<Investigation> createInvestigation({
    String id = 'investigation-1',
    InvestigationPriority priority = InvestigationPriority.medium,
    Iterable<String> entityIds = const [],
    Iterable<String> connectionIds = const [],
  }) =>
      service.createInvestigation(
        id: id,
        title: 'Investigation $id',
        description: 'Workflow service test.',
        priority: priority,
        relatedEntityIds: entityIds,
        relatedConnectionIds: connectionIds,
      );

  Future<void> addHypothesis({
    required String id,
    required String investigationId,
    HypothesisStatus status = HypothesisStatus.candidate,
    Iterable<String> supportingEvidenceIds = const [],
    Iterable<String> contradictingEvidenceIds = const [],
  }) async {
    await hypotheses.add(
      Hypothesis(
        id: id,
        investigationId: investigationId,
        title: 'Hypothesis $id',
        explanation: 'A reviewable explanation, not a finding.',
        supportingEvidenceIds: supportingEvidenceIds,
        contradictingEvidenceIds: contradictingEvidenceIds,
        confidence: .5,
        confidenceExplanation: 'Uncalibrated test score.',
        status: status,
        generatedAt: _baseTime,
        provenance: DataProvenance(
          origin: DataOrigin.analystCreated,
          source:
              EvidenceSource(description: 'Analyst-created test hypothesis'),
          authorId: 'analyst-1',
          recordedAt: _baseTime,
        ),
      ),
    );
  }

  group('investigation lifecycle and metadata', () {
    test('creates, retrieves, and lists investigations deterministically',
        () async {
      final first = await createInvestigation();
      await createInvestigation(
        id: 'investigation-2',
        priority: InvestigationPriority.high,
      );
      final active = await service.changeStatus(
        investigationId: 'investigation-2',
        status: InvestigationStatus.active,
      );

      expect((await service.getInvestigation(first.id)).status,
          InvestigationStatus.draft);
      expect(
        (await service.listInvestigations(status: InvestigationStatus.active))
            .map((item) => item.id),
        ['investigation-2'],
      );
      expect(
        (await service.listInvestigations(
          priority: InvestigationPriority.high,
        ))
            .single
            .id,
        active.id,
      );
    });

    test('rejects invalid creation without storing a partial record', () async {
      await expectLater(
        service.createInvestigation(
          id: 'invalid',
          title: '  ',
          description: 'invalid title',
        ),
        throwsA(isA<InvalidWorkflowInputException>()),
      );
      expect(await investigations.getAll(), isEmpty);
    });

    test('allows draft, active, on-hold, and close lifecycle transitions',
        () async {
      await createInvestigation();
      await service.changeStatus(
        investigationId: 'investigation-1',
        status: InvestigationStatus.active,
      );
      await service.changeStatus(
        investigationId: 'investigation-1',
        status: InvestigationStatus.onHold,
      );
      await service.changeStatus(
        investigationId: 'investigation-1',
        status: InvestigationStatus.active,
      );
      final closed = await service.closeInvestigation('investigation-1');

      expect(closed.status, InvestigationStatus.closed);
    });

    test('rejects invalid transitions and keeps the original status', () async {
      await createInvestigation();
      await expectLater(
        service.closeInvestigation('investigation-1'),
        throwsA(isA<InvalidLifecycleTransitionException>()),
      );
      await expectLater(
        service.changeStatus(
          investigationId: 'investigation-1',
          status: InvestigationStatus.onHold,
        ),
        throwsA(isA<InvalidLifecycleTransitionException>()),
      );
      expect(
        (await service.getInvestigation('investigation-1')).status,
        InvestigationStatus.draft,
      );
    });

    test('closed investigations reject workflow writes', () async {
      await createInvestigation();
      await service.changeStatus(
        investigationId: 'investigation-1',
        status: InvestigationStatus.active,
      );
      await service.closeInvestigation('investigation-1');

      await expectLater(
        service.changePriority(
          investigationId: 'investigation-1',
          priority: InvestigationPriority.critical,
        ),
        throwsA(isA<InvestigationClosedException>()),
      );
      await expectLater(
        service.updateMetadata(
          investigationId: 'investigation-1',
          title: 'Cannot update closed record',
        ),
        throwsA(isA<InvestigationClosedException>()),
      );
      await expectLater(
        service.appendAnalystNote(
          investigationId: 'investigation-1',
          noteId: 'note-1',
          authorId: 'analyst-1',
          content: 'No note after closure.',
        ),
        throwsA(isA<InvestigationClosedException>()),
      );
    });

    test('updates priority and editable metadata without changing notes',
        () async {
      await createInvestigation();
      final note = await service.appendAnalystNote(
        investigationId: 'investigation-1',
        noteId: 'note-1',
        authorId: 'analyst-1',
        content: 'First note.',
      );

      await service.changePriority(
        investigationId: 'investigation-1',
        priority: InvestigationPriority.critical,
      );
      final updated = await service.updateMetadata(
        investigationId: 'investigation-1',
        title: 'Updated title',
        assignedAnalystId: 'analyst-2',
      );

      expect(updated.priority, InvestigationPriority.critical);
      expect(updated.title, 'Updated title');
      expect(updated.assignedAnalystId, 'analyst-2');
      expect(updated.analystNotes, [note]);
      expect(
        (await service.updateMetadata(
          investigationId: 'investigation-1',
          clearAssignedAnalyst: true,
        ))
            .assignedAnalystId,
        isNull,
      );
    });

    test('rejects empty metadata updates', () async {
      await createInvestigation();
      await expectLater(
        service.updateMetadata(investigationId: 'investigation-1'),
        throwsA(isA<InvalidWorkflowInputException>()),
      );
    });
  });

  group('graph associations and evidence', () {
    test('associates known entities and connections without creating evidence',
        () async {
      await createInvestigation();
      await service.associateGraphEntities(
        investigationId: 'investigation-1',
        entityIds: const ['entity-1'],
      );
      await service.associateGraphConnections(
        investigationId: 'investigation-1',
        connectionIds: const ['connection-1'],
      );

      final summary = await service.getSummary('investigation-1');
      expect(summary.associatedEntityCount, 1);
      expect(summary.associatedConnectionCount, 1);
      expect(summary.evidenceCount, 0);
    });

    test('rejects unknown and duplicate graph associations without mutation',
        () async {
      await createInvestigation();
      await expectLater(
        service.associateGraphEntities(
          investigationId: 'investigation-1',
          entityIds: const ['unknown-entity'],
        ),
        throwsA(isA<UnknownGraphReferenceException>()),
      );
      await service.associateGraphEntities(
        investigationId: 'investigation-1',
        entityIds: const ['entity-1'],
      );
      await expectLater(
        service.associateGraphEntities(
          investigationId: 'investigation-1',
          entityIds: const ['entity-1'],
        ),
        throwsA(isA<DuplicateGraphAssociationException>()),
      );

      expect(
        (await service.getInvestigation('investigation-1')).relatedEntityIds,
        ['entity-1'],
      );
    });

    test(
        'adds and retrieves evidence while preserving provenance and reliability',
        () async {
      await createInvestigation(entityIds: const ['entity-1']);
      final provenance = DataProvenance(
        origin: DataOrigin.observedTelemetry,
        source: EvidenceSource(
          description: 'Endpoint event stream',
          identifier: 'sensor-12',
        ),
        recordedAt: _baseTime,
      );
      final item = _evidence(
        id: 'evidence-1',
        investigationId: 'investigation-1',
        provenance: provenance,
        entityIds: const ['entity-1'],
      );

      expect(await service.addEvidence(item), same(item));
      final retrieved =
          (await service.getEvidenceForInvestigation('investigation-1')).single;
      expect(retrieved.provenance, same(provenance));
      expect(retrieved.reliability, EvidenceReliability.high);
      expect(retrieved.reliabilityRationale, 'Corroborated by two sources.');
    });

    test(
        'rejects evidence whose graph references belong to another association',
        () async {
      await createInvestigation(entityIds: const ['entity-1']);
      await createInvestigation(
        id: 'investigation-2',
        entityIds: const ['entity-2'],
      );
      final item = _evidence(
        id: 'cross-evidence',
        investigationId: 'investigation-1',
        entityIds: const ['entity-2'],
      );

      await expectLater(
        service.addEvidence(item),
        throwsA(isA<InvalidWorkflowInputException>()),
      );
      expect(await evidence.getByInvestigationId('investigation-1'), isEmpty);
    });

    test('rejects evidence with an unknown investigation', () async {
      final item = _evidence(
        id: 'missing-evidence',
        investigationId: 'missing-investigation',
      );
      await expectLater(
        service.addEvidence(item),
        throwsA(isA<RecordNotFoundException>()),
      );
      expect(dataSource.evidence, isEmpty);
    });

    test('domain validation prevents AI-generated content from being evidence',
        () {
      final aiProvenance = DataProvenance(
        origin: DataOrigin.aiGenerated,
        source: EvidenceSource(description: 'Generated output'),
        generatorName: 'test-generator',
        generatorVersion: '1',
        recordedAt: _baseTime,
      );
      expect(
        () => _evidence(
          id: 'ai-evidence',
          investigationId: 'investigation-1',
          provenance: aiProvenance,
        ),
        throwsArgumentError,
      );
    });
  });

  group('notes, hypothesis review, and summaries', () {
    test('appends analyst notes and preserves earlier notes', () async {
      await createInvestigation();
      final first = await service.appendAnalystNote(
        investigationId: 'investigation-1',
        noteId: 'note-1',
        authorId: 'analyst-1',
        content: 'Initial observation.',
      );
      final second = await service.appendAnalystNote(
        investigationId: 'investigation-1',
        noteId: 'note-2',
        authorId: 'analyst-2',
        content: 'Follow-up observation.',
      );
      final investigation = await service.getInvestigation('investigation-1');

      expect(investigation.analystNotes, [first, second]);
      expect(first.authorId, 'analyst-1');
      expect(first.timestamp, _baseTime);
    });

    test('retrieves hypotheses and starts a review without confirming them',
        () async {
      await createInvestigation();
      await addHypothesis(
        id: 'hypothesis-1',
        investigationId: 'investigation-1',
      );
      final before =
          await service.getHypothesesForInvestigation('investigation-1');
      final reviewed = await service.startHypothesisReview(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
      );

      expect(before.single.status, HypothesisStatus.candidate);
      expect(reviewed.status, HypothesisStatus.underReview);
      expect(
        (await service.getInvestigation('investigation-1')).status,
        InvestigationStatus.draft,
      );
    });

    test('records all analyst decision types with append-only history',
        () async {
      await createInvestigation();
      final decisionTypes = <String, AnalystDecisionType>{
        'accept': AnalystDecisionType.accept,
        'reject': AnalystDecisionType.reject,
        'defer': AnalystDecisionType.defer,
        'inconclusive': AnalystDecisionType.inconclusive,
      };
      final statuses = <String, HypothesisStatus>{
        'accept': HypothesisStatus.acceptedForInvestigation,
        'reject': HypothesisStatus.rejected,
        'defer': HypothesisStatus.deferred,
        'inconclusive': HypothesisStatus.inconclusive,
      };
      for (final entry in decisionTypes.entries) {
        final hypothesisId = 'hypothesis-${entry.key}';
        await addHypothesis(
          id: hypothesisId,
          investigationId: 'investigation-1',
        );
        await service.startHypothesisReview(
          investigationId: 'investigation-1',
          hypothesisId: hypothesisId,
        );
        final decision = await service.recordHypothesisDecision(
          investigationId: 'investigation-1',
          hypothesisId: hypothesisId,
          decisionId: 'decision-${entry.key}',
          analystId: 'analyst-1',
          rationale: 'Reviewed the available supporting and contrary context.',
          decision: entry.value,
        );
        expect(decision.decision, entry.value);
        expect(
          (await hypotheses.getById(hypothesisId)).status,
          statuses[entry.key],
        );
      }

      final investigation = await service.getInvestigation('investigation-1');
      expect(investigation.status, InvestigationStatus.draft);
      expect(await decisions.getHistoryForInvestigation(investigation.id),
          hasLength(4));
    });

    test('preserves supporting and contradicting evidence during review',
        () async {
      await createInvestigation();
      await service.addEvidence(
        _evidence(id: 'evidence-support', investigationId: 'investigation-1'),
      );
      await service.addEvidence(
        _evidence(
            id: 'evidence-contradict', investigationId: 'investigation-1'),
      );
      await addHypothesis(
        id: 'hypothesis-1',
        investigationId: 'investigation-1',
        supportingEvidenceIds: const ['evidence-support'],
        contradictingEvidenceIds: const ['evidence-contradict'],
      );
      await service.startHypothesisReview(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
      );
      await service.acceptHypothesis(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decisionId: 'decision-1',
        analystId: 'analyst-1',
        rationale: 'Continue testing the explanation.',
      );

      final reviewed = await hypotheses.getById('hypothesis-1');
      expect(reviewed.supportingEvidenceIds, ['evidence-support']);
      expect(reviewed.contradictingEvidenceIds, ['evidence-contradict']);
    });

    test('retains earlier decisions and returns append order/latest correctly',
        () async {
      await createInvestigation();
      await addHypothesis(
        id: 'hypothesis-1',
        investigationId: 'investigation-1',
      );
      await service.startHypothesisReview(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
      );
      final first = await service.acceptHypothesis(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decisionId: 'decision-1',
        analystId: 'analyst-1',
        rationale: 'Continue investigating the hypothesis.',
      );
      now = now.add(const Duration(minutes: 1));
      await service.startHypothesisReview(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
      );
      final second = await service.rejectHypothesis(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decisionId: 'decision-2',
        analystId: 'analyst-2',
        rationale: 'New evidence contradicts the hypothesis.',
      );

      final history =
          await service.getDecisionHistoryForHypothesis('hypothesis-1');
      expect(history, [first, second]);
      expect(await decisions.getLatestForHypothesis('hypothesis-1'), second);
      expect((await hypotheses.getById('hypothesis-1')).status,
          HypothesisStatus.rejected);
    });

    test('requires rationale and rejects cross-investigation decisions',
        () async {
      await createInvestigation();
      await createInvestigation(id: 'investigation-2');
      await addHypothesis(
        id: 'hypothesis-1',
        investigationId: 'investigation-1',
      );
      await addHypothesis(
        id: 'hypothesis-2',
        investigationId: 'investigation-2',
      );
      await service.startHypothesisReview(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
      );

      await expectLater(
        service.acceptHypothesis(
          investigationId: 'investigation-1',
          hypothesisId: 'hypothesis-1',
          decisionId: 'empty-rationale',
          analystId: 'analyst-1',
          rationale: '  ',
        ),
        throwsA(isA<InvalidWorkflowInputException>()),
      );
      await expectLater(
        service.acceptHypothesis(
          investigationId: 'investigation-1',
          hypothesisId: 'hypothesis-1',
          decisionId: 'short-rationale',
          analystId: 'analyst-1',
          rationale: 'short',
        ),
        throwsA(isA<InvalidWorkflowInputException>()),
      );
      await expectLater(
        service.acceptHypothesis(
          investigationId: 'investigation-1',
          hypothesisId: 'missing-hypothesis',
          decisionId: 'missing-hypothesis-decision',
          analystId: 'analyst-1',
          rationale: 'No hypothesis should be found.',
        ),
        throwsA(isA<RecordNotFoundException>()),
      );
      await expectLater(
        service.acceptHypothesis(
          investigationId: 'investigation-1',
          hypothesisId: 'hypothesis-2',
          decisionId: 'cross-decision',
          analystId: 'analyst-1',
          rationale: 'This hypothesis is in another investigation.',
        ),
        throwsA(isA<InvalidWorkflowInputException>()),
      );
      expect(dataSource.decisions, isEmpty);
      expect(
        (await hypotheses.getById('hypothesis-1')).status,
        HypothesisStatus.underReview,
      );
    });

    test('summary derives counts, latest decision, and empty values from repos',
        () async {
      await createInvestigation(
        entityIds: const ['entity-1'],
        connectionIds: const ['connection-1'],
      );
      final empty = await service.getSummary('investigation-1');
      expect(empty.evidenceCount, 0);
      expect(empty.hypothesisCount, 0);
      expect(empty.latestDecision, isNull);
      expect(empty.status, InvestigationStatus.draft);

      await service.addEvidence(
        _evidence(
          id: 'evidence-1',
          investigationId: 'investigation-1',
          entityIds: const ['entity-1'],
          connectionIds: const ['connection-1'],
        ),
      );
      await addHypothesis(
        id: 'hypothesis-1',
        investigationId: 'investigation-1',
      );
      await service.startHypothesisReview(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
      );
      final decision = await service.deferHypothesis(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decisionId: 'decision-1',
        analystId: 'analyst-1',
        rationale: 'Wait for additional telemetry.',
      );
      final summary = await service.getSummary('investigation-1');

      expect(summary.associatedEntityCount, 1);
      expect(summary.associatedConnectionCount, 1);
      expect(summary.evidenceCount, 1);
      expect(summary.hypothesisCount, 1);
      expect(summary.latestDecision, decision);
      expect(summary.status, InvestigationStatus.draft);
    });
  });

  test('integrates assessments and ATT&CK proposals without changing decisions',
      () async {
    await createInvestigation();
    await service.addEvidence(
      _evidence(
        id: 'evidence-1',
        investigationId: 'investigation-1',
      ),
    );
    await addHypothesis(
      id: 'hypothesis-1',
      investigationId: 'investigation-1',
      supportingEvidenceIds: const ['evidence-1'],
    );

    final assessment = await service.addAssessment(
      id: 'assessment-1',
      investigationId: 'investigation-1',
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-1',
      rationale: 'The available record supports the hypothesis.',
      outcome: AnalystAssessmentOutcome.supports,
      evidenceReviewedIds: const ['evidence-1'],
      supportingEvidenceIds: const ['evidence-1'],
      alternativeExplanations: const ['The behavior may be administrative.'],
    );
    expect(await service.getAssessment('assessment-1'), same(assessment));
    expect(
      await service.getAssessmentHistoryForHypothesis('hypothesis-1'),
      [assessment],
    );
    expect(
      await service.getAssessmentsForInvestigation('investigation-1'),
      [assessment],
    );

    await service.addProposedMitreReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-1',
      reference: MitreAttackReference(
        techniqueId: 'T1059',
        techniqueName: 'Command and Scripting Interpreter',
        tactic: 'Execution',
        description: 'Official ATT&CK reference test fixture.',
        referenceUrl: 'https://attack.mitre.org/techniques/T1059/',
      ),
    );
    final proposed =
        (await service.getMitreReferencesForHypothesis('hypothesis-1')).single;
    expect(proposed.isProposed, isTrue);
    expect(
      await service.verifyMitreReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-1',
        techniqueId: 'T1059',
      ),
      isA<MitreReferenceVerificationUnavailableResult>(),
    );
    await service.removeProposedMitreReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-1',
      techniqueId: 'T1059',
    );

    expect(
      await service.getAssessmentHistoryForHypothesis('hypothesis-1'),
      [assessment],
    );
    expect(
      await service.getEvidenceForInvestigation('investigation-1'),
      hasLength(1),
    );
    expect(dataSource.decisions, isEmpty);
    expect(
      (await hypotheses.getById('hypothesis-1')).status,
      HypothesisStatus.candidate,
    );
    expect(
      (await service.getInvestigation('investigation-1')).status,
      InvestigationStatus.draft,
    );
  });

  test(
      'repository failures propagate and atomic review leaves no partial write',
      () async {
    await createInvestigation();
    await addHypothesis(
      id: 'hypothesis-1',
      investigationId: 'investigation-1',
    );
    await service.startHypothesisReview(
      investigationId: 'investigation-1',
      hypothesisId: 'hypothesis-1',
    );
    final failingService = InvestigationWorkflowService(
      investigationRepository: investigations,
      evidenceRepository: evidence,
      hypothesisRepository: hypotheses,
      analystDecisionRepository: _FailingReviewRepository(),
      assessmentRepository: assessments,
      graphCatalog: dataSource,
      clock: () => now,
    );

    await expectLater(
      failingService.acceptHypothesis(
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decisionId: 'decision-1',
        analystId: 'analyst-1',
        rationale: 'Failure path.',
      ),
      throwsA(isA<StateError>()),
    );
    expect(dataSource.decisions, isEmpty);
    expect(
      (await hypotheses.getById('hypothesis-1')).status,
      HypothesisStatus.underReview,
    );
  });
}

Evidence _evidence({
  required String id,
  required String investigationId,
  DataProvenance? provenance,
  Iterable<String> entityIds = const [],
  Iterable<String> connectionIds = const [],
}) =>
    Evidence(
      id: id,
      investigationId: investigationId,
      title: 'Evidence $id',
      description: 'Workflow evidence test.',
      evidenceType: EvidenceType.telemetryEvent,
      provenance: provenance ??
          DataProvenance(
            origin: DataOrigin.analystCreated,
            source: EvidenceSource(description: 'Analyst observation'),
            authorId: 'analyst-1',
            recordedAt: _baseTime,
          ),
      collectedAt: _baseTime,
      relatedEntityIds: entityIds,
      relatedConnectionIds: connectionIds,
      reliability: EvidenceReliability.high,
      reliabilityRationale: 'Corroborated by two sources.',
      dataClassification: DataClassification.internal,
    );

class _FailingReviewRepository implements AnalystDecisionRepository {
  @override
  Future<void> append(AnalystDecision decision) async {
    throw StateError('Injected repository failure.');
  }

  @override
  Future<void> appendReview({
    required AnalystDecision decision,
    required Hypothesis updatedHypothesis,
  }) async {
    throw StateError('Injected atomic review failure.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
