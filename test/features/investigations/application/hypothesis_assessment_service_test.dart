import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/features/investigations/application/exceptions/investigation_workflow_exception.dart';
import 'package:huntai/features/investigations/application/services/hypothesis_assessment_service.dart';
import 'package:huntai/features/investigations/data/datasources/in_memory_investigation_data_source.dart';
import 'package:huntai/features/investigations/data/exceptions/investigation_repository_exception.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_assessment_repository.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_repository.dart';
import 'package:huntai/features/investigations/data/repositories/in_memory_investigation_repositories.dart';
import 'package:huntai/features/investigations/data/repositories/investigation_repository.dart';
import 'package:huntai/features/investigations/data/repositories/evidence_repository.dart';
import 'package:huntai/features/investigations/domain/enums/investigation_enums.dart';
import 'package:huntai/features/investigations/domain/models/analyst_decision.dart';
import 'package:huntai/features/investigations/domain/models/data_provenance.dart';
import 'package:huntai/features/investigations/domain/models/evidence.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis_assessment.dart';
import 'package:huntai/features/investigations/domain/models/investigation.dart';

final _createdAt = DateTime.utc(2026, 11, 19, 10);

void main() {
  late InMemoryInvestigationDataSource dataSource;
  late InvestigationRepository investigations;
  late EvidenceRepository evidence;
  late HypothesisRepository hypotheses;
  late AnalystAssessmentRepository assessments;
  late AnalystAssessmentService service;
  var clockTick = 0;

  setUp(() async {
    clockTick = 0;
    dataSource = InMemoryInvestigationDataSource(clock: () => _createdAt);
    investigations = InMemoryInvestigationRepository(dataSource);
    evidence = InMemoryEvidenceRepository(dataSource);
    hypotheses = InMemoryHypothesisRepository(dataSource);
    assessments = InMemoryAnalystAssessmentRepository(dataSource);
    service = AnalystAssessmentService(
      investigationRepository: investigations,
      evidenceRepository: evidence,
      hypothesisRepository: hypotheses,
      assessmentRepository: assessments,
      clock: () => _createdAt.add(Duration(minutes: clockTick++)),
    );

    await investigations.create(_investigation('investigation-1'));
    await investigations.create(_investigation('investigation-2'));
    await evidence.add(_evidence('evidence-1', 'investigation-1'));
    await evidence.add(_evidence('evidence-2', 'investigation-1'));
    await evidence.add(_evidence('evidence-3', 'investigation-2'));
    await hypotheses.add(_hypothesis('hypothesis-1', 'investigation-1'));
    await hypotheses.add(_hypothesis('hypothesis-2', 'investigation-2'));
    await InMemoryAnalystDecisionRepository(dataSource).append(
      AnalystDecision(
        id: 'decision-1',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decision: AnalystDecisionType.defer,
        rationale: 'Retained before this independent assessment.',
        analystId: 'analyst-7',
        decidedAt: _createdAt,
      ),
    );
  });

  Future<AnalystAssessment> createAssessment({
    String id = 'assessment-1',
    Iterable<String> reviewed = const ['evidence-1', 'evidence-2'],
  }) =>
      service.createAssessment(
        id: id,
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-7',
        rationale: 'Corroboration and contradiction were compared.',
        outcome: AnalystAssessmentOutcome.partiallySupports,
        evidenceReviewedIds: reviewed,
        supportingEvidenceIds: const ['evidence-1'],
        contradictingEvidenceIds: const ['evidence-2'],
        alternativeExplanations: const ['The activity may be benign.'],
        evidenceGaps: [
          EvidenceGap(
            description: 'No independent confirmation.',
            reason: 'Only two records were available for this review.',
          ),
        ],
      );

  test('appends traceable assessments without changing decisions or status',
      () async {
    final assessment = await createAssessment();

    expect(assessment.analystId, 'analyst-7');
    expect(assessment.evidenceReviewedIds, ['evidence-1', 'evidence-2']);
    expect(assessment.supportingEvidenceIds, ['evidence-1']);
    expect(assessment.contradictingEvidenceIds, ['evidence-2']);
    expect(
      await service.getByHypothesisId('hypothesis-1'),
      [assessment],
    );
    expect(await service.getById(assessment.id), same(assessment));
    expect(
      (await hypotheses.getById('hypothesis-1')).status,
      HypothesisStatus.candidate,
    );
    expect(
      () => assessment.evidenceReviewedIds.clear(),
      throwsUnsupportedError,
    );
    expect(await assessments.getByInvestigationId('investigation-1'), [
      assessment,
    ]);
    expect(
        await investigations.getById('investigation-1').then(
              (item) => item.status,
            ),
        InvestigationStatus.draft);
    expect(
      await InMemoryAnalystDecisionRepository(dataSource)
          .getHistoryForHypothesis('hypothesis-1'),
      hasLength(1),
    );
    await expectLater(
      service.getByHypothesisId('hypothesis-1').then(
            (history) => history.clear(),
          ),
      throwsUnsupportedError,
    );
  });

  test('preserves assessment history in deterministic timestamp order',
      () async {
    final first = await createAssessment(id: 'assessment-1');
    final second = await createAssessment(id: 'assessment-2');

    expect(
      (await service.getByHypothesisId('hypothesis-1')).map((item) => item.id),
      [first.id, second.id],
    );
    expect(
      await service.getByInvestigationId('investigation-1'),
      hasLength(2),
    );
    expect(await service.getByHypothesisId('hypothesis-2'), isEmpty);
  });

  test('duplicate assessment IDs fail without replacing prior history',
      () async {
    final first = await createAssessment();

    await expectLater(
      createAssessment(),
      throwsA(isA<DuplicateRecordException>()),
    );
    expect(await service.getById(first.id), same(first));
    expect(await service.getByHypothesisId('hypothesis-1'), [first]);
  });

  test('closed investigations reject assessment writes', () async {
    await investigations.create(
      _investigation('closed-investigation',
          status: InvestigationStatus.closed),
    );
    await hypotheses.add(
      _hypothesis('closed-hypothesis', 'closed-investigation'),
    );

    await expectLater(
      service.createAssessment(
        id: 'closed-assessment',
        investigationId: 'closed-investigation',
        hypothesisId: 'closed-hypothesis',
        analystId: 'analyst-7',
        rationale: 'Assessment is not allowed after closure.',
        outcome: AnalystAssessmentOutcome.inconclusive,
      ),
      throwsA(isA<InvestigationClosedException>()),
    );
    expect(
      await assessments.getByInvestigationId('closed-investigation'),
      isEmpty,
    );
  });

  test('rejects nonexistent hypotheses and cross-investigation assessments',
      () async {
    await expectLater(
      service.createAssessment(
        id: 'assessment-missing',
        investigationId: 'investigation-1',
        hypothesisId: 'missing-hypothesis',
        analystId: 'analyst-7',
        rationale: 'Evidence was reviewed against the stated claim.',
        outcome: AnalystAssessmentOutcome.inconclusive,
      ),
      throwsA(isA<RecordNotFoundException>()),
    );
    await expectLater(
      service.createAssessment(
        id: 'assessment-cross',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-2',
        analystId: 'analyst-7',
        rationale: 'Evidence was reviewed against the stated claim.',
        outcome: AnalystAssessmentOutcome.inconclusive,
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
    expect(await assessments.getByInvestigationId('investigation-1'), isEmpty);
  });

  test('rejects missing and cross-investigation evidence without a write',
      () async {
    await expectLater(
      createAssessment(
        id: 'assessment-missing-evidence',
        reviewed: const ['evidence-1', 'evidence-2', 'missing-evidence'],
      ),
      throwsA(isA<RecordNotFoundException>()),
    );
    await expectLater(
      createAssessment(
        id: 'assessment-cross-evidence',
        reviewed: const ['evidence-1', 'evidence-2', 'evidence-3'],
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );

    expect(await assessments.getByInvestigationId('investigation-1'), isEmpty);
    expect(
      (await hypotheses.getById('hypothesis-1')).status,
      HypothesisStatus.candidate,
    );
  });

  test('requires rationale and keeps support and contradiction separate',
      () async {
    await expectLater(
      service.createAssessment(
        id: 'assessment-short-rationale',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-7',
        rationale: 'No.',
        outcome: AnalystAssessmentOutcome.inconclusive,
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
    await expectLater(
      service.createAssessment(
        id: 'assessment-empty-rationale',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-7',
        rationale: '',
        outcome: AnalystAssessmentOutcome.inconclusive,
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
    await expectLater(
      service.createAssessment(
        id: 'assessment-duplicate-evidence',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-7',
        rationale: 'Repeated evidence identifiers are invalid.',
        outcome: AnalystAssessmentOutcome.inconclusive,
        evidenceReviewedIds: const ['evidence-1', 'evidence-1'],
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
    await expectLater(
      service.createAssessment(
        id: 'assessment-overlap',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-7',
        rationale: 'The same record cannot support and contradict.',
        outcome: AnalystAssessmentOutcome.inconclusive,
        evidenceReviewedIds: const ['evidence-1'],
        supportingEvidenceIds: const ['evidence-1'],
        contradictingEvidenceIds: const ['evidence-1'],
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
    expect(await assessments.getByInvestigationId('investigation-1'), isEmpty);
  });
}

Investigation _investigation(
  String id, {
  InvestigationStatus status = InvestigationStatus.draft,
}) =>
    Investigation(
      id: id,
      title: 'Assessment test case $id',
      description: 'Assessment test investigation.',
      status: status,
      priority: InvestigationPriority.medium,
      createdAt: _createdAt,
      updatedAt: _createdAt,
      relatedEntityIds: const [],
      relatedConnectionIds: const [],
    );

Evidence _evidence(String id, String investigationId) => Evidence(
      id: id,
      investigationId: investigationId,
      title: 'Assessment evidence $id',
      description: 'A test record.',
      evidenceType: EvidenceType.analystObservation,
      provenance: DataProvenance(
        origin: DataOrigin.analystCreated,
        source: EvidenceSource(description: 'Assessment test source'),
        authorId: 'analyst-7',
        recordedAt: _createdAt,
      ),
      collectedAt: _createdAt,
      reliability: EvidenceReliability.medium,
      reliabilityRationale: 'Recorded for repository tests.',
      dataClassification: DataClassification.internal,
    );

Hypothesis _hypothesis(String id, String investigationId) => Hypothesis(
      id: id,
      investigationId: investigationId,
      title: 'Assessment hypothesis $id',
      explanation: 'A test hypothesis, not a finding.',
      confidence: .3,
      confidenceExplanation: 'Uncalibrated test score.',
      status: HypothesisStatus.candidate,
      generatedAt: _createdAt,
      provenance: DataProvenance(
        origin: DataOrigin.analystCreated,
        source: EvidenceSource(description: 'Assessment test source'),
        authorId: 'analyst-7',
        recordedAt: _createdAt,
      ),
    );
