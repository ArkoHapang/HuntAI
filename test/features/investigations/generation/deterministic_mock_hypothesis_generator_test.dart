import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/features/investigations/application/services/investigation_workflow_service.dart';
import 'package:huntai/features/investigations/data/datasources/in_memory_investigation_data_source.dart';
import 'package:huntai/features/investigations/data/repositories/analyst_decision_repository.dart';
import 'package:huntai/features/investigations/data/repositories/evidence_repository.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_assessment_repository.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_repository.dart';
import 'package:huntai/features/investigations/data/repositories/in_memory_investigation_repositories.dart';
import 'package:huntai/features/investigations/data/repositories/investigation_repository.dart';
import 'package:huntai/features/investigations/domain/enums/investigation_enums.dart';
import 'package:huntai/features/investigations/domain/models/data_provenance.dart';
import 'package:huntai/features/investigations/domain/models/evidence.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis.dart';
import 'package:huntai/features/investigations/generation/contracts/hypothesis_generator.dart';
import 'package:huntai/features/investigations/generation/models/hypothesis_generation_configuration.dart';
import 'package:huntai/features/investigations/generation/models/hypothesis_generation_request.dart';
import 'package:huntai/features/investigations/generation/models/hypothesis_generation_result.dart';
import 'package:huntai/features/investigations/generation/providers/deterministic_mock_hypothesis_generator.dart';
import 'package:huntai/features/investigations/generation/services/hypothesis_generation_service.dart';

final _time = DateTime.utc(2026, 11, 19, 16);

void main() {
  late InMemoryInvestigationDataSource dataSource;
  late InvestigationRepository investigations;
  late EvidenceRepository evidence;
  late HypothesisRepository hypotheses;
  late AnalystDecisionRepository decisions;
  late AnalystAssessmentRepository assessments;
  late InvestigationWorkflowService workflow;

  setUp(() {
    dataSource = InMemoryInvestigationDataSource(
      availableEntityIds: const ['entity-1', 'entity-2'],
      availableConnectionIds: const ['connection-1'],
      clock: () => _time,
    );
    investigations = InMemoryInvestigationRepository(dataSource);
    evidence = InMemoryEvidenceRepository(dataSource);
    hypotheses = InMemoryHypothesisRepository(dataSource);
    decisions = InMemoryAnalystDecisionRepository(dataSource);
    assessments = InMemoryAnalystAssessmentRepository(dataSource);
    workflow = InvestigationWorkflowService(
      investigationRepository: investigations,
      evidenceRepository: evidence,
      hypothesisRepository: hypotheses,
      analystDecisionRepository: decisions,
      assessmentRepository: assessments,
      graphCatalog: dataSource,
      clock: () => _time,
    );
  });

  Future<void> createInvestigation({
    String id = 'investigation-1',
    Iterable<String> entityIds = const ['entity-1'],
    Iterable<String> connectionIds = const [],
  }) async {
    await workflow.createInvestigation(
      id: id,
      title: 'Generation test $id',
      description: 'Mock generator test context.',
      relatedEntityIds: entityIds,
      relatedConnectionIds: connectionIds,
    );
  }

  Future<void> addEvidence(Evidence item) => workflow.addEvidence(item);

  group('deterministic mock generator', () {
    test('identical input produces stable hypothesis values and IDs', () async {
      final generator =
          DeterministicMockHypothesisGenerator(clock: () => _time);
      final request = _request(evidence: [_evidence(id: 'evidence-1')]);

      final first =
          (await generator.generate(request)) as HypothesesGeneratedResult;
      final second =
          (await generator.generate(request)) as HypothesesGeneratedResult;

      expect(second.hypotheses.single.id, first.hypotheses.single.id);
      expect(second.hypotheses.single.title, first.hypotheses.single.title);
      expect(
        second.hypotheses.single.confidence,
        first.hypotheses.single.confidence,
      );
      expect(
        second.hypotheses.single.explanation,
        first.hypotheses.single.explanation,
      );
    });

    test('uses injected clock and ID generation strategy', () async {
      final generator = DeterministicMockHypothesisGenerator(
        clock: () => _time.add(const Duration(hours: 1)),
        idGenerator: _FixedIdGenerator('injected-hypothesis-id'),
      );
      final result = await generator.generate(
        _request(evidence: [_evidence(id: 'evidence-1')]),
      ) as HypothesesGeneratedResult;

      expect(result.hypotheses.single.id, 'injected-hypothesis-id');
      expect(
        result.hypotheses.single.generatedAt,
        _time.add(const Duration(hours: 1)),
      );
    });

    test('sets mock name, version, provenance, metadata, and candidate status',
        () async {
      final generator =
          DeterministicMockHypothesisGenerator(clock: () => _time);
      final result = await generator.generate(
        _request(evidence: [_evidence(id: 'evidence-1')]),
      ) as HypothesesGeneratedResult;
      final hypothesis = result.hypotheses.single;

      expect(
          generator.name, DeterministicMockHypothesisGenerator.generatorName);
      expect(generator.version,
          DeterministicMockHypothesisGenerator.generatorVersion);
      expect(hypothesis.provenance.origin, DataOrigin.aiGenerated);
      expect(hypothesis.provenance.generatorName, generator.name);
      expect(hypothesis.provenance.generatorVersion, generator.version);
      expect(hypothesis.provenance.recordedAt, hypothesis.generatedAt);
      expect(
        hypothesis.generationMetadata!.method,
        'explicit-evidence-cue-shared-graph-reference',
      );
      expect(
        hypothesis.generationMetadata!.ruleSetVersion,
        generator.version,
      );
      expect(hypothesis.status, HypothesisStatus.candidate);
      expect(hypothesis.reviewedAt, isNull);
    });

    test('returns resolved support and contradiction refs separately',
        () async {
      final supporting = _evidence(id: 'support-1');
      final contradicting = _evidence(
        id: 'contra-1',
        evidenceType: EvidenceType.analystObservation,
      );
      final result = await DeterministicMockHypothesisGenerator(
        clock: () => _time,
      ).generate(
        _request(
          evidence: [supporting, contradicting],
          supportingIds: const ['support-1'],
          contradictingIds: const ['contra-1'],
        ),
      ) as HypothesesGeneratedResult;
      final hypothesis = result.hypotheses.single;

      expect(hypothesis.supportingEvidenceIds, ['support-1']);
      expect(hypothesis.contradictingEvidenceIds, ['contra-1']);
      expect(
        hypothesis.supportingEvidenceIds.toSet().intersection(
              hypothesis.contradictingEvidenceIds.toSet(),
            ),
        isEmpty,
      );
    });

    test('contradicting evidence reduces score and is named in rationale',
        () async {
      final support = _evidence(id: 'support');
      final contradiction = _evidence(
        id: 'contradiction',
        evidenceType: EvidenceType.analystObservation,
      );
      final generator =
          DeterministicMockHypothesisGenerator(clock: () => _time);
      final supportOnly = await generator.generate(
        _request(evidence: [support], supportingIds: const ['support']),
      ) as HypothesesGeneratedResult;
      final withContradiction = await generator.generate(
        _request(
          evidence: [support, contradiction],
          supportingIds: const ['support'],
          contradictingIds: const ['contradiction'],
        ),
      ) as HypothesesGeneratedResult;

      expect(
        withContradiction.hypotheses.single.confidence,
        lessThan(supportOnly.hypotheses.single.confidence),
      );
      expect(
        withContradiction.hypotheses.single.confidenceExplanation,
        contains('1 distinct contradicting record'),
      );
    });

    test('duplicate evidence copies do not increase support or score',
        () async {
      final item = _evidence(id: 'evidence-1');
      final generator =
          DeterministicMockHypothesisGenerator(clock: () => _time);
      final single = await generator.generate(
        _request(evidence: [item], supportingIds: const ['evidence-1']),
      ) as HypothesesGeneratedResult;
      final duplicated = await generator.generate(
        _request(
          evidence: [item, item],
          supportingIds: const ['evidence-1', 'evidence-1'],
        ),
      ) as HypothesesGeneratedResult;

      expect(
          duplicated.hypotheses.single.supportingEvidenceIds, ['evidence-1']);
      expect(
        duplicated.hypotheses.single.confidence,
        single.hypotheses.single.confidence,
      );
    });

    test('rejects conflicting duplicate evidence IDs', () async {
      final first = _evidence(id: 'evidence-1');
      final conflicting = Evidence(
        id: first.id,
        investigationId: first.investigationId,
        title: 'Conflicting copy',
        description: first.description,
        evidenceType: first.evidenceType,
        provenance: first.provenance,
        collectedAt: first.collectedAt,
        reliability: first.reliability,
        reliabilityRationale: first.reliabilityRationale,
        dataClassification: first.dataClassification,
        relatedEntityIds: first.relatedEntityIds,
      );
      final result = await DeterministicMockHypothesisGenerator(
        clock: () => _time,
      ).generate(
        _request(evidence: [first, conflicting]),
      );

      expect(result, isA<InvalidEvidenceReferencesResult>());
    });

    test('returns explicit insufficient-evidence and no-rule outcomes',
        () async {
      final generator =
          DeterministicMockHypothesisGenerator(clock: () => _time);
      final insufficient = await generator.generate(
        _request(evidence: const [], supportingIds: const []),
      );
      final noRule = await generator.generate(
        _request(
          evidence: [
            _evidence(id: 'unlinked', entityIds: const []),
          ],
          supportingIds: const ['unlinked'],
        ),
      );

      expect(insufficient, isA<InsufficientEvidenceResult>());
      expect(noRule, isA<NoApplicableGenerationRulesResult>());
    });

    test('preserves alternative explanations and evidence gaps', () async {
      final result = await DeterministicMockHypothesisGenerator(
        clock: () => _time,
      ).generate(
        _request(evidence: [_evidence(id: 'evidence-1')]),
      ) as HypothesesGeneratedResult;
      final hypothesis = result.hypotheses.single;

      expect(hypothesis.alternativeExplanations, isNotEmpty);
      expect(hypothesis.evidenceGaps, isNotEmpty);
    });

    test('rejects cross-investigation, unknown-evidence, and graph references',
        () async {
      final generator =
          DeterministicMockHypothesisGenerator(clock: () => _time);
      final crossInvestigation = await generator.generate(
        _request(
          evidence: [
            _evidence(
              id: 'foreign',
              investigationId: 'investigation-2',
            ),
          ],
        ),
      );
      final unknownEvidence = await generator.generate(
        _request(
          evidence: [_evidence(id: 'evidence-1')],
          supportingIds: const ['missing-evidence'],
        ),
      );
      final unknownGraph = await generator.generate(
        _request(
          evidence: [
            _evidence(id: 'unknown-graph', entityIds: const ['entity-2']),
          ],
          entityIds: const ['entity-1'],
        ),
      );

      expect(crossInvestigation, isA<InvalidEvidenceReferencesResult>());
      expect(unknownEvidence, isA<InvalidEvidenceReferencesResult>());
      expect(unknownGraph, isA<InvalidEvidenceReferencesResult>());
    });

    test('returns valid confidence values and never claims probability',
        () async {
      final result = await DeterministicMockHypothesisGenerator(
        clock: () => _time,
      ).generate(
        _request(evidence: [_evidence(id: 'evidence-1')]),
      ) as HypothesesGeneratedResult;
      final hypothesis = result.hypotheses.single;

      expect(hypothesis.confidence, inInclusiveRange(0, 1));
      expect(hypothesis.confidence.isFinite, isTrue);
      expect(hypothesis.confidenceExplanation,
          contains('not a calibrated probability'));
    });
  });

  group('generation orchestration', () {
    test('persists generated candidates without creating evidence', () async {
      await createInvestigation();
      await addEvidence(_evidence(id: 'evidence-1'));
      final generator =
          DeterministicMockHypothesisGenerator(clock: () => _time);
      final service = HypothesisGenerationService(
        workflowService: workflow,
        generator: generator,
      );
      final run = await service.generateForInvestigation(
        investigationId: 'investigation-1',
        configuration: _configuration(supportingIds: const ['evidence-1']),
      );

      expect(run.result, isA<HypothesesGeneratedResult>());
      expect(run.newlyPersisted, hasLength(1));
      expect(run.newlyPersisted.single.status, HypothesisStatus.candidate);
      expect(
          run.newlyPersisted.single.provenance.origin, DataOrigin.aiGenerated);
      expect(dataSource.evidence, hasLength(1));
      expect(
        dataSource.evidence.values.single.provenance.origin,
        DataOrigin.syntheticDemo,
      );
      expect(dataSource.hypotheses, hasLength(1));
      expect(dataSource.decisions, isEmpty);
    });

    test('repeated generation reports existing hypotheses without duplicates',
        () async {
      await createInvestigation();
      await addEvidence(_evidence(id: 'evidence-1'));
      final service = HypothesisGenerationService(
        workflowService: workflow,
        generator: DeterministicMockHypothesisGenerator(clock: () => _time),
      );
      final configuration = _configuration(supportingIds: const ['evidence-1']);
      final first = await service.generateForInvestigation(
        investigationId: 'investigation-1',
        configuration: configuration,
      );
      final second = await service.generateForInvestigation(
        investigationId: 'investigation-1',
        configuration: configuration,
      );

      expect(first.newlyPersisted, hasLength(1));
      expect(second.newlyPersisted, isEmpty);
      expect(second.alreadyPresent, hasLength(1));
      expect(dataSource.hypotheses, hasLength(1));
    });

    test('content deduplication survives changed timestamps and injected IDs',
        () async {
      await createInvestigation();
      await addEvidence(_evidence(id: 'evidence-1'));
      var generatedAt = _time;
      final service = HypothesisGenerationService(
        workflowService: workflow,
        generator: DeterministicMockHypothesisGenerator(
          clock: () => generatedAt,
          idGenerator: _IncrementingIdGenerator(),
        ),
      );
      final configuration = _configuration(supportingIds: const ['evidence-1']);
      final first = await service.generateForInvestigation(
        investigationId: 'investigation-1',
        configuration: configuration,
      );
      generatedAt = generatedAt.add(const Duration(hours: 1));
      final second = await service.generateForInvestigation(
        investigationId: 'investigation-1',
        configuration: configuration,
      );

      expect(
        (first.result as HypothesesGeneratedResult).hypotheses.single.id,
        isNot(
          (second.result as HypothesesGeneratedResult).hypotheses.single.id,
        ),
      );
      expect(second.newlyPersisted, isEmpty);
      expect(second.alreadyPresent, hasLength(1));
      expect(dataSource.hypotheses, hasLength(1));
    });

    test('invalid generated output is rejected before any batch write',
        () async {
      await createInvestigation();
      await addEvidence(_evidence(id: 'evidence-1'));
      final valid = _generatedHypothesis(id: 'valid-generated');
      final invalid = _generatedHypothesis(
        id: 'invalid-generated',
        status: HypothesisStatus.acceptedForInvestigation,
      );
      final service = HypothesisGenerationService(
        workflowService: workflow,
        generator: _FixedResultGenerator(
          HypothesesGeneratedResult([valid, invalid]),
        ),
      );

      final run = await service.generateForInvestigation(
        investigationId: 'investigation-1',
        configuration: _configuration(supportingIds: const ['evidence-1']),
      );

      expect(run.result, isA<InvalidGeneratedHypothesesResult>());
      expect(dataSource.hypotheses, isEmpty);
      expect(
        (await workflow.getInvestigation('investigation-1')).hypothesisIds,
        isEmpty,
      );
    });

    test('rejects generated graph references absent from the request context',
        () async {
      await createInvestigation();
      await addEvidence(_evidence(id: 'evidence-1'));
      final service = HypothesisGenerationService(
        workflowService: workflow,
        generator: _FixedResultGenerator(
          HypothesesGeneratedResult([
            _generatedHypothesis(
              id: 'unknown-graph-generated',
              entityIds: const ['entity-2'],
            ),
          ]),
        ),
      );

      final run = await service.generateForInvestigation(
        investigationId: 'investigation-1',
        configuration: _configuration(supportingIds: const ['evidence-1']),
      );

      expect(run.result, isA<InvalidEvidenceReferencesResult>());
      expect(dataSource.hypotheses, isEmpty);
    });

    test('valid empty outcomes are preserved and do not write hypotheses',
        () async {
      await createInvestigation();
      final service = HypothesisGenerationService(
        workflowService: workflow,
        generator: DeterministicMockHypothesisGenerator(clock: () => _time),
      );
      final run = await service.generateForInvestigation(
        investigationId: 'investigation-1',
      );

      expect(run.result, isA<InsufficientEvidenceResult>());
      expect(run.newlyPersisted, isEmpty);
      expect(dataSource.hypotheses, isEmpty);
    });

    test('invalid investigation context is distinct from generation failure',
        () async {
      final missing = HypothesisGenerationService(
        workflowService: workflow,
        generator: DeterministicMockHypothesisGenerator(clock: () => _time),
      );
      final missingRun = await missing.generateForInvestigation(
        investigationId: 'missing-investigation',
      );
      await createInvestigation();
      final failed = HypothesisGenerationService(
        workflowService: workflow,
        generator: _FixedResultGenerator(
          const GenerationFailureResult('Injected mock failure.'),
        ),
      );
      final failedRun = await failed.generateForInvestigation(
        investigationId: 'investigation-1',
      );

      expect(missingRun.result, isA<InvalidGenerationContextResult>());
      expect(failedRun.result, isA<GenerationFailureResult>());
    });

    test('preserves prior analyst decisions and reviewed hypotheses', () async {
      await createInvestigation();
      await addEvidence(_evidence(id: 'evidence-1'));
      final analystHypothesis = Hypothesis(
        id: 'analyst-hypothesis',
        investigationId: 'investigation-1',
        title: 'Analyst proposal',
        explanation: 'An analyst-authored hypothesis.',
        confidence: .3,
        confidenceExplanation: 'Uncalibrated analyst estimate.',
        status: HypothesisStatus.candidate,
        generatedAt: _time,
        provenance: DataProvenance(
          origin: DataOrigin.analystCreated,
          source: EvidenceSource(description: 'Analyst input'),
          authorId: 'analyst-1',
          recordedAt: _time,
        ),
      );
      await workflow.addHypotheses(
        investigationId: 'investigation-1',
        hypotheses: [analystHypothesis],
      );
      await workflow.startHypothesisReview(
        investigationId: 'investigation-1',
        hypothesisId: analystHypothesis.id,
      );
      final decision = await workflow.acceptHypothesis(
        investigationId: 'investigation-1',
        hypothesisId: analystHypothesis.id,
        decisionId: 'analyst-decision-1',
        analystId: 'analyst-1',
        rationale: 'Continue investigating.',
      );
      final service = HypothesisGenerationService(
        workflowService: workflow,
        generator: DeterministicMockHypothesisGenerator(clock: () => _time),
      );

      final run = await service.generateForInvestigation(
        investigationId: 'investigation-1',
        configuration: _configuration(supportingIds: const ['evidence-1']),
      );

      expect(run.newlyPersisted, hasLength(1));
      expect(
        (await workflow.getDecisionHistoryForHypothesis(
          analystHypothesis.id,
        ))
            .single,
        same(decision),
      );
      expect(
        (await hypotheses.getById(analystHypothesis.id)).status,
        HypothesisStatus.acceptedForInvestigation,
      );
      expect(dataSource.decisions, hasLength(1));
    });
  });
}

HypothesisGenerationRequest _request({
  required Iterable<Evidence> evidence,
  String investigationId = 'investigation-1',
  Iterable<String> entityIds = const ['entity-1'],
  Iterable<String> connectionIds = const [],
  Iterable<String> supportingIds = const ['evidence-1'],
  Iterable<String> contradictingIds = const [],
}) =>
    HypothesisGenerationRequest(
      investigationId: investigationId,
      evidence: evidence,
      existingHypotheses: const [],
      associatedEntityIds: entityIds,
      associatedConnectionIds: connectionIds,
      configuration: _configuration(
        supportingIds: supportingIds,
        contradictingIds: contradictingIds,
      ),
    );

HypothesisGenerationConfiguration _configuration({
  Iterable<String> supportingIds = const [],
  Iterable<String> contradictingIds = const [],
  int minimumSupportingEvidence = 1,
  int maximumHypotheses = 3,
}) =>
    HypothesisGenerationConfiguration(
      evidenceCues: [
        for (final id in supportingIds)
          EvidenceGenerationCue(
            evidenceId: id,
            polarity: EvidenceCuePolarity.supporting,
          ),
        for (final id in contradictingIds)
          EvidenceGenerationCue(
            evidenceId: id,
            polarity: EvidenceCuePolarity.contradicting,
          ),
      ],
      minimumSupportingEvidence: minimumSupportingEvidence,
      maximumHypotheses: maximumHypotheses,
    );

Evidence _evidence({
  required String id,
  String investigationId = 'investigation-1',
  EvidenceType evidenceType = EvidenceType.alert,
  Iterable<String> entityIds = const ['entity-1'],
  Iterable<String> connectionIds = const [],
  EvidenceReliability reliability = EvidenceReliability.high,
  DateTime? observedAt,
}) =>
    Evidence(
      id: id,
      investigationId: investigationId,
      title: 'Evidence $id',
      description: 'Supplied test record $id.',
      evidenceType: evidenceType,
      provenance: DataProvenance(
        origin: DataOrigin.syntheticDemo,
        source:
            EvidenceSource(description: 'Explicitly synthetic test fixture'),
        recordedAt: _time,
      ),
      collectedAt: _time,
      observedAt: observedAt,
      reliability: reliability,
      reliabilityRationale: 'Fixture reliability supplied for testing.',
      dataClassification: DataClassification.internal,
      relatedEntityIds: entityIds,
      relatedConnectionIds: connectionIds,
    );

Hypothesis _generatedHypothesis({
  required String id,
  HypothesisStatus status = HypothesisStatus.candidate,
  Iterable<String> entityIds = const ['entity-1'],
}) =>
    Hypothesis(
      id: id,
      investigationId: 'investigation-1',
      title: 'Mock-generated test hypothesis',
      explanation: 'A generated candidate tied to supplied evidence.',
      supportingEvidenceIds: const ['evidence-1'],
      confidence: .5,
      confidenceExplanation: 'Mock test score; not a probability.',
      status: status,
      generatedAt: _time,
      provenance: DataProvenance(
        origin: DataOrigin.aiGenerated,
        source: EvidenceSource(description: 'Mock test generator'),
        recordedAt: _time,
        generatorName: DeterministicMockHypothesisGenerator.generatorName,
        generatorVersion: DeterministicMockHypothesisGenerator.generatorVersion,
      ),
      generationMetadata: GenerationMetadata(
        method: 'test',
        ruleSetVersion: DeterministicMockHypothesisGenerator.generatorVersion,
      ),
      relatedEntityIds: entityIds,
    );

class _FixedIdGenerator implements HypothesisIdGenerator {
  _FixedIdGenerator(this.id);

  final String id;

  @override
  String generate({
    required String investigationId,
    required String generationKey,
  }) =>
      id;
}

class _IncrementingIdGenerator implements HypothesisIdGenerator {
  var _nextId = 0;

  @override
  String generate({
    required String investigationId,
    required String generationKey,
  }) =>
      'injected-id-${_nextId++}';
}

class _FixedResultGenerator implements HypothesisGenerator {
  _FixedResultGenerator(this.result);

  final HypothesisGenerationResult result;

  @override
  String get name => DeterministicMockHypothesisGenerator.generatorName;

  @override
  String get version => DeterministicMockHypothesisGenerator.generatorVersion;

  @override
  Future<HypothesisGenerationResult> generate(
    HypothesisGenerationRequest request,
  ) async =>
      result;
}
