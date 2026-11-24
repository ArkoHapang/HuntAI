import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/features/investigations/data/datasources/in_memory_investigation_data_source.dart';
import 'package:huntai/features/investigations/data/exceptions/investigation_repository_exception.dart';
import 'package:huntai/features/investigations/data/repositories/analyst_decision_repository.dart';
import 'package:huntai/features/investigations/data/repositories/evidence_repository.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_repository.dart';
import 'package:huntai/features/investigations/data/repositories/in_memory_investigation_repositories.dart';
import 'package:huntai/features/investigations/data/repositories/investigation_repository.dart';
import 'package:huntai/features/investigations/domain/enums/investigation_enums.dart';
import 'package:huntai/features/investigations/domain/models/analyst_decision.dart';
import 'package:huntai/features/investigations/domain/models/data_provenance.dart';
import 'package:huntai/features/investigations/domain/models/evidence.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis.dart';
import 'package:huntai/features/investigations/domain/models/investigation.dart';

final _createdAt = DateTime.utc(2026, 11, 19, 10);
final _updatedAt = DateTime.utc(2026, 11, 19, 11);
final _laterAt = DateTime.utc(2026, 11, 19, 12);

Investigation _investigation({
  String id = 'investigation-1',
  String title = 'Sample investigation',
  InvestigationStatus status = InvestigationStatus.draft,
  InvestigationPriority priority = InvestigationPriority.medium,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? assignedAnalystId,
  Iterable<String> entityIds = const ['entity-1'],
  Iterable<String> connectionIds = const ['connection-1'],
  Iterable<String> evidenceIds = const [],
  Iterable<String> hypothesisIds = const [],
  Iterable<AnalystNote> notes = const [],
}) =>
    Investigation(
      id: id,
      title: title,
      description: 'Repository test investigation.',
      status: status,
      priority: priority,
      createdAt: createdAt ?? _createdAt,
      updatedAt: updatedAt ?? _createdAt,
      assignedAnalystId: assignedAnalystId,
      relatedEntityIds: entityIds,
      relatedConnectionIds: connectionIds,
      evidenceIds: evidenceIds,
      hypothesisIds: hypothesisIds,
      analystNotes: notes,
    );

Evidence _evidence({
  String id = 'evidence-1',
  String investigationId = 'investigation-1',
  Iterable<String> entityIds = const ['entity-1'],
  Iterable<String> connectionIds = const ['connection-1'],
}) =>
    Evidence(
      id: id,
      investigationId: investigationId,
      title: 'Sample evidence $id',
      description: 'Repository test evidence.',
      evidenceType: EvidenceType.analystObservation,
      provenance: DataProvenance(
        origin: DataOrigin.analystCreated,
        source: EvidenceSource(description: 'Analyst supplied source'),
        authorId: 'analyst-1',
        recordedAt: _updatedAt,
      ),
      collectedAt: _updatedAt,
      relatedEntityIds: entityIds,
      relatedConnectionIds: connectionIds,
      reliability: EvidenceReliability.unassessed,
      reliabilityRationale: 'Not assessed in this test.',
      dataClassification: DataClassification.internal,
    );

Hypothesis _hypothesis({
  String id = 'hypothesis-1',
  String investigationId = 'investigation-1',
  Iterable<String> supportingEvidenceIds = const ['evidence-1'],
  Iterable<String> contradictingEvidenceIds = const [],
  Iterable<String> entityIds = const ['entity-1'],
  Iterable<String> connectionIds = const ['connection-1'],
}) =>
    Hypothesis(
      id: id,
      investigationId: investigationId,
      title: 'Candidate explanation $id',
      explanation: 'A repository test hypothesis, not a finding.',
      supportingEvidenceIds: supportingEvidenceIds,
      contradictingEvidenceIds: contradictingEvidenceIds,
      relatedEntityIds: entityIds,
      relatedConnectionIds: connectionIds,
      confidence: .4,
      confidenceExplanation: 'Uncalibrated test score.',
      status: HypothesisStatus.candidate,
      generatedAt: _updatedAt,
      provenance: DataProvenance(
        origin: DataOrigin.analystCreated,
        source: EvidenceSource(description: 'Analyst hypothesis'),
        authorId: 'analyst-1',
        recordedAt: _updatedAt,
      ),
    );

AnalystDecision _decision({
  String id = 'decision-1',
  String investigationId = 'investigation-1',
  String hypothesisId = 'hypothesis-1',
  AnalystDecisionType decision = AnalystDecisionType.defer,
  DateTime? decidedAt,
}) =>
    AnalystDecision(
      id: id,
      investigationId: investigationId,
      hypothesisId: hypothesisId,
      decision: decision,
      rationale: 'Repository test rationale.',
      analystId: 'analyst-1',
      decidedAt: decidedAt ?? _updatedAt,
    );

void main() {
  late InMemoryInvestigationDataSource dataSource;
  late InvestigationRepository investigations;
  late EvidenceRepository evidence;
  late HypothesisRepository hypotheses;
  late AnalystDecisionRepository decisions;

  setUp(() {
    dataSource = InMemoryInvestigationDataSource(
      availableEntityIds: const ['entity-1', 'entity-2'],
      availableConnectionIds: const ['connection-1'],
      clock: () => _laterAt,
    );
    investigations = InMemoryInvestigationRepository(dataSource);
    evidence = InMemoryEvidenceRepository(dataSource);
    hypotheses = InMemoryHypothesisRepository(dataSource);
    decisions = InMemoryAnalystDecisionRepository(dataSource);
  });

  Future<void> createInvestigation({
    String id = 'investigation-1',
    InvestigationStatus status = InvestigationStatus.draft,
    InvestigationPriority priority = InvestigationPriority.medium,
    Iterable<String> entityIds = const ['entity-1'],
    Iterable<String> connectionIds = const ['connection-1'],
  }) =>
      investigations.create(
        _investigation(
          id: id,
          status: status,
          priority: priority,
          entityIds: entityIds,
          connectionIds: connectionIds,
        ),
      );

  Future<void> addEvidence({
    String id = 'evidence-1',
    String investigationId = 'investigation-1',
    Iterable<String> entityIds = const ['entity-1'],
    Iterable<String> connectionIds = const ['connection-1'],
  }) =>
      evidence.add(
        _evidence(
          id: id,
          investigationId: investigationId,
          entityIds: entityIds,
          connectionIds: connectionIds,
        ),
      );

  Future<void> addHypothesis({
    String id = 'hypothesis-1',
    String investigationId = 'investigation-1',
    Iterable<String> supportingEvidenceIds = const ['evidence-1'],
    Iterable<String> contradictingEvidenceIds = const [],
  }) =>
      hypotheses.add(
        _hypothesis(
          id: id,
          investigationId: investigationId,
          supportingEvidenceIds: supportingEvidenceIds,
          contradictingEvidenceIds: contradictingEvidenceIds,
        ),
      );

  group('investigation repository', () {
    test('creates and retrieves an investigation', () async {
      await createInvestigation();

      expect((await investigations.getById('investigation-1')).title,
          'Sample investigation');
    });

    test('rejects duplicate investigation IDs', () async {
      await createInvestigation();

      await expectLater(
        investigations.create(_investigation()),
        throwsA(isA<DuplicateRecordException>()),
      );
      expect((await investigations.getAll()).length, 1);
    });

    test('returns all investigations in insertion order', () async {
      await createInvestigation(id: 'investigation-1');
      await createInvestigation(id: 'investigation-2');

      expect(
        (await investigations.getAll()).map((item) => item.id),
        ['investigation-1', 'investigation-2'],
      );
    });

    test('filters by status and priority', () async {
      await createInvestigation(
        id: 'active-critical',
        status: InvestigationStatus.active,
        priority: InvestigationPriority.critical,
      );
      await createInvestigation(
        id: 'draft-medium',
        status: InvestigationStatus.draft,
        priority: InvestigationPriority.medium,
      );

      expect(
        (await investigations.getByStatus(InvestigationStatus.active))
            .map((item) => item.id),
        ['active-critical'],
      );
      expect(
        (await investigations.getByPriority(InvestigationPriority.medium))
            .map((item) => item.id),
        ['draft-medium'],
      );
    });

    test('updates metadata while preserving creation and linked records',
        () async {
      await createInvestigation();
      final current = await investigations.getById('investigation-1');
      final updated = _investigation(
        title: 'Updated title',
        status: InvestigationStatus.active,
        priority: InvestigationPriority.high,
        assignedAnalystId: 'analyst-2',
        createdAt: current.createdAt,
        updatedAt: _updatedAt,
        entityIds: current.relatedEntityIds,
        connectionIds: current.relatedConnectionIds,
        evidenceIds: current.evidenceIds,
        hypothesisIds: current.hypothesisIds,
        notes: current.analystNotes,
      );

      final result = await investigations.update(updated);

      expect(result.title, 'Updated title');
      expect(result.status, InvestigationStatus.active);
      expect(result.priority, InvestigationPriority.high);
      expect(result.assignedAnalystId, 'analyst-2');
      expect(result.createdAt, current.createdAt);
    });

    test('rejects removing linked evidence during update without mutation',
        () async {
      await createInvestigation();
      await addEvidence();
      final current = await investigations.getById('investigation-1');
      final invalidUpdate = _investigation(
        title: 'Should not be saved',
        createdAt: current.createdAt,
        updatedAt: _laterAt,
        entityIds: current.relatedEntityIds,
        connectionIds: current.relatedConnectionIds,
      );

      await expectLater(
        investigations.update(invalidUpdate),
        throwsA(isA<InvalidUpdateException>()),
      );
      expect(
        (await investigations.getById('investigation-1')).title,
        current.title,
      );
      expect((await evidence.getById('evidence-1')).id, 'evidence-1');
    });

    test('rejects deleting an investigation with related records', () async {
      await createInvestigation();
      await addEvidence();

      await expectLater(
        investigations.deleteById('investigation-1'),
        throwsA(isA<UnsafeDeletionException>()),
      );
      expect(await investigations.getById('investigation-1'), isNotNull);
      expect(await evidence.getById('evidence-1'), isNotNull);
    });

    test('deletes an investigation with no related records', () async {
      await createInvestigation();

      await investigations.deleteById('investigation-1');

      expect(await investigations.getAll(), isEmpty);
      await expectLater(
        investigations.getById('investigation-1'),
        throwsA(isA<RecordNotFoundException>()),
      );
    });

    test('reports inconsistent stored references without deleting records',
        () async {
      dataSource.commitInvestigation(
        _investigation(evidenceIds: const ['missing-evidence']),
      );

      await expectLater(
        investigations.deleteById('investigation-1'),
        throwsA(isA<InconsistentRepositoryStateException>()),
      );
      expect(dataSource.investigations, contains('investigation-1'));
    });

    test('returns immutable results and empty collections for empty storage',
        () async {
      expect(await investigations.getAll(), isEmpty);
      await createInvestigation();
      final results = await investigations.getAll();

      expect(
        () => results.clear(),
        throwsUnsupportedError,
      );
      expect(
        await evidence.getByInvestigationId('investigation-1'),
        isEmpty,
      );
      expect(
        await hypotheses.getByInvestigationId('investigation-1'),
        isEmpty,
      );
    });
  });

  group('evidence repository', () {
    test('adds and retrieves evidence for its investigation', () async {
      await createInvestigation();
      await addEvidence();

      expect((await evidence.getById('evidence-1')).source.description,
          'Analyst supplied source');
      expect(
        (await evidence.getByInvestigationId('investigation-1'))
            .map((item) => item.id),
        ['evidence-1'],
      );
      expect(
        (await evidence.getAllForInvestigation('investigation-1')).length,
        1,
      );
      expect(
        (await investigations.getById('investigation-1')).evidenceIds,
        ['evidence-1'],
      );
    });

    test('rejects duplicate evidence IDs', () async {
      await createInvestigation();
      await addEvidence();

      await expectLater(
        addEvidence(),
        throwsA(isA<DuplicateRecordException>()),
      );
      expect(
        (await evidence.getByInvestigationId('investigation-1')).length,
        1,
      );
    });

    test('rejects evidence for a nonexistent investigation', () async {
      await expectLater(
        addEvidence(investigationId: 'missing-investigation'),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(dataSource.evidence, isEmpty);
    });

    test('rejects unknown graph links without partially adding evidence',
        () async {
      await createInvestigation();

      await expectLater(
        addEvidence(entityIds: const ['unknown-entity']),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(dataSource.evidence, isEmpty);
      expect(
        (await investigations.getById('investigation-1')).evidenceIds,
        isEmpty,
      );
    });

    test('returns an immutable evidence list', () async {
      await createInvestigation();
      await addEvidence();
      final results = await evidence.getByInvestigationId('investigation-1');

      expect(() => results.clear(), throwsUnsupportedError);
    });
  });

  group('hypothesis repository', () {
    test('adds a valid hypothesis batch atomically', () async {
      await createInvestigation();
      await addEvidence();
      final first = _hypothesis(id: 'hypothesis-1');
      final second = _hypothesis(
        id: 'hypothesis-2',
        contradictingEvidenceIds: const [],
      );

      await hypotheses.addAll([first, second]);

      expect(dataSource.hypotheses.values, [first, second]);
      expect(
        (await investigations.getById('investigation-1')).hypothesisIds,
        ['hypothesis-1', 'hypothesis-2'],
      );
    });

    test('rejects an invalid hypothesis batch without partial mutation',
        () async {
      await createInvestigation();
      await addEvidence();
      final valid = _hypothesis(id: 'valid-hypothesis');
      final invalid = _hypothesis(
        id: 'invalid-hypothesis',
        supportingEvidenceIds: const ['missing-evidence'],
      );

      await expectLater(
        hypotheses.addAll([valid, invalid]),
        throwsA(isA<InvalidRelationshipException>()),
      );

      expect(dataSource.hypotheses, isEmpty);
      expect(
        (await investigations.getById('investigation-1')).hypothesisIds,
        isEmpty,
      );
    });

    test('adds, retrieves, and preserves supporting and contradicting IDs',
        () async {
      await createInvestigation();
      await addEvidence(id: 'support-1');
      await addEvidence(id: 'contradict-1');
      await hypotheses.add(
        _hypothesis(
          supportingEvidenceIds: const ['support-1'],
          contradictingEvidenceIds: const ['contradict-1'],
        ),
      );

      final hypothesis = await hypotheses.getById('hypothesis-1');
      expect(hypothesis.supportingEvidenceIds, ['support-1']);
      expect(hypothesis.contradictingEvidenceIds, ['contradict-1']);
      expect(
        (await hypotheses.getByInvestigationId('investigation-1')).single.id,
        'hypothesis-1',
      );
      expect(
        (await investigations.getById('investigation-1')).hypothesisIds,
        ['hypothesis-1'],
      );
    });

    test('rejects a hypothesis with unresolved evidence references', () async {
      await createInvestigation();

      await expectLater(
        addHypothesis(supportingEvidenceIds: const ['missing-evidence']),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(dataSource.hypotheses, isEmpty);
      expect(
        (await investigations.getById('investigation-1')).hypothesisIds,
        isEmpty,
      );
    });

    test('rejects duplicate hypothesis IDs without changing the link list',
        () async {
      await createInvestigation();
      await addEvidence();
      await addHypothesis();

      await expectLater(
        addHypothesis(),
        throwsA(isA<DuplicateRecordException>()),
      );
      expect(
        (await investigations.getById('investigation-1')).hypothesisIds,
        ['hypothesis-1'],
      );
      expect(
        (await hypotheses.getByInvestigationId('investigation-1')).length,
        1,
      );
    });

    test('rejects evidence belonging to another investigation', () async {
      await createInvestigation();
      await createInvestigation(id: 'investigation-2');
      await addEvidence(
        id: 'evidence-2',
        investigationId: 'investigation-2',
      );

      await expectLater(
        addHypothesis(supportingEvidenceIds: const ['evidence-2']),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(dataSource.hypotheses, isEmpty);
    });

    test('updates review status only through permitted transitions', () async {
      await createInvestigation();
      await addEvidence();
      await addHypothesis();

      await expectLater(
        hypotheses.updateReviewStatus(
          hypothesisId: 'hypothesis-1',
          status: HypothesisStatus.acceptedForInvestigation,
          reviewedAt: _laterAt,
        ),
        throwsA(isA<InvalidUpdateException>()),
      );

      final underReview = await hypotheses.updateReviewStatus(
        hypothesisId: 'hypothesis-1',
        status: HypothesisStatus.underReview,
        reviewedAt: _laterAt,
      );
      expect(underReview.status, HypothesisStatus.underReview);
      expect(underReview.supportingEvidenceIds, ['evidence-1']);

      final accepted = await hypotheses.updateReviewStatus(
        hypothesisId: 'hypothesis-1',
        status: HypothesisStatus.acceptedForInvestigation,
        reviewedAt: _laterAt.add(const Duration(minutes: 1)),
      );
      expect(accepted.status, HypothesisStatus.acceptedForInvestigation);
      expect(accepted.reviewedAt, _laterAt.add(const Duration(minutes: 1)));
      expect(dataSource.decisions, isEmpty);
    });

    test('does not expose mutable hypothesis result lists', () async {
      await createInvestigation();
      await addEvidence();
      await addHypothesis();
      final results = await hypotheses.getByInvestigationId('investigation-1');

      expect(() => results.clear(), throwsUnsupportedError);
      expect(
        () => results.single.supportingEvidenceIds.add('other'),
        throwsUnsupportedError,
      );
    });
  });

  group('analyst decision repository', () {
    test('appends history and returns the last appended decision', () async {
      await createInvestigation();
      await addEvidence();
      await addHypothesis();
      final first = _decision(id: 'decision-1');
      final second = _decision(
        id: 'decision-2',
        decision: AnalystDecisionType.accept,
        decidedAt: _laterAt.add(const Duration(minutes: 1)),
      );

      await decisions.append(first);
      await decisions.append(second);

      final history = await decisions.getHistoryForHypothesis('hypothesis-1');
      expect(history.map((item) => item.id), ['decision-1', 'decision-2']);
      expect(identical(history.first, first), isTrue);
      expect(identical(history.last, second), isTrue);
      expect(
        (await decisions.getHistoryForInvestigation('investigation-1')).length,
        2,
      );
      expect(
        (await decisions.getLatestForHypothesis('hypothesis-1'))!.id,
        'decision-2',
      );
      expect(
        (await hypotheses.getById('hypothesis-1')).status,
        HypothesisStatus.candidate,
      );
    });

    test('returns null for the latest decision when history is empty',
        () async {
      await createInvestigation();
      await addEvidence();
      await addHypothesis();

      expect(
        await decisions.getLatestForHypothesis('hypothesis-1'),
        isNull,
      );
    });

    test('rejects decisions referencing nonexistent hypotheses', () async {
      await createInvestigation();

      await expectLater(
        decisions.append(_decision(hypothesisId: 'missing-hypothesis')),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(dataSource.decisions, isEmpty);
    });

    test('rejects cross-investigation decisions without appending', () async {
      await createInvestigation();
      await createInvestigation(id: 'investigation-2');
      await addEvidence();
      await addHypothesis();

      await expectLater(
        decisions.append(
          _decision(investigationId: 'investigation-2'),
        ),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(dataSource.decisions, isEmpty);
    });

    test('rejects duplicate decision IDs and preserves earlier history',
        () async {
      await createInvestigation();
      await addEvidence();
      await addHypothesis();
      final first = _decision();
      await decisions.append(first);

      await expectLater(
        decisions.append(_decision(decision: AnalystDecisionType.reject)),
        throwsA(isA<DuplicateRecordException>()),
      );
      expect(
        (await decisions.getHistoryForHypothesis('hypothesis-1')).single,
        same(first),
      );
    });

    test('returns decision history in deterministic append order', () async {
      await createInvestigation();
      await addEvidence();
      await addHypothesis();
      await decisions.append(_decision(id: 'first'));
      await decisions.append(
        _decision(
          id: 'second',
          decidedAt: _laterAt.add(const Duration(minutes: 1)),
        ),
      );

      expect(
        (await decisions.getHistoryForHypothesis('hypothesis-1'))
            .map((item) => item.id),
        ['first', 'second'],
      );
    });

    test('rejects an inconsistent atomic review without partially updating',
        () async {
      await createInvestigation();
      await addEvidence();
      await addHypothesis();
      final current = await hypotheses.updateReviewStatus(
        hypothesisId: 'hypothesis-1',
        status: HypothesisStatus.underReview,
        reviewedAt: _laterAt,
      );
      final reviewTime = _laterAt.add(const Duration(minutes: 1));
      final invalidUpdate = Hypothesis(
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
        status: HypothesisStatus.acceptedForInvestigation,
        generatedAt: current.generatedAt,
        reviewedAt: reviewTime,
        alternativeExplanations: current.alternativeExplanations,
        evidenceGaps: current.evidenceGaps,
        generationMetadata: current.generationMetadata,
        provenance: current.provenance,
      );

      await expectLater(
        decisions.appendReview(
          decision: _decision(
            id: 'decision-1',
            decision: AnalystDecisionType.defer,
            decidedAt: reviewTime,
          ),
          updatedHypothesis: invalidUpdate,
        ),
        throwsA(isA<InvalidRelationshipException>()),
      );
      expect(
        (await hypotheses.getById('hypothesis-1')).status,
        HypothesisStatus.underReview,
      );
      expect(dataSource.decisions, isEmpty);
    });
  });
}
