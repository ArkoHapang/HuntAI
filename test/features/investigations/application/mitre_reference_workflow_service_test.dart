import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/features/investigations/application/contracts/mitre_reference_verifier.dart';
import 'package:huntai/features/investigations/application/exceptions/investigation_workflow_exception.dart';
import 'package:huntai/features/investigations/application/models/mitre_reference_verification_result.dart';
import 'package:huntai/features/investigations/application/services/mitre_reference_workflow_service.dart';
import 'package:huntai/features/investigations/data/datasources/in_memory_investigation_data_source.dart';
import 'package:huntai/features/investigations/data/exceptions/investigation_repository_exception.dart';
import 'package:huntai/features/investigations/data/repositories/hypothesis_repository.dart';
import 'package:huntai/features/investigations/data/repositories/in_memory_investigation_repositories.dart';
import 'package:huntai/features/investigations/data/repositories/investigation_repository.dart';
import 'package:huntai/features/investigations/data/repositories/evidence_repository.dart';
import 'package:huntai/features/investigations/domain/enums/investigation_enums.dart';
import 'package:huntai/features/investigations/domain/models/analyst_decision.dart';
import 'package:huntai/features/investigations/domain/models/data_provenance.dart';
import 'package:huntai/features/investigations/domain/models/evidence.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis.dart';
import 'package:huntai/features/investigations/domain/models/investigation.dart';
import 'package:huntai/features/investigations/domain/models/mitre_attack_reference.dart';

final _createdAt = DateTime.utc(2026, 11, 19, 10);
const _officialSource = 'https://attack.mitre.org/techniques/T1059/';

void main() {
  late InMemoryInvestigationDataSource dataSource;
  late InvestigationRepository investigations;
  late EvidenceRepository evidence;
  late HypothesisRepository hypotheses;
  late _FakeVerifier verifier;
  late MitreReferenceWorkflowService service;

  setUp(() async {
    dataSource = InMemoryInvestigationDataSource(clock: () => _createdAt);
    investigations = InMemoryInvestigationRepository(dataSource);
    evidence = InMemoryEvidenceRepository(dataSource);
    hypotheses = InMemoryHypothesisRepository(dataSource);
    verifier =
        _FakeVerifier(const MitreReferenceUnverifiedResult('Not checked.'));
    service = MitreReferenceWorkflowService(
      hypothesisRepository: hypotheses,
      investigationRepository: investigations,
      verifier: verifier,
      clock: () => _createdAt,
    );

    await investigations.create(_investigation());
    await evidence.add(_evidence());
    await hypotheses.add(_hypothesis());
    await InMemoryAnalystDecisionRepository(dataSource).append(
      AnalystDecision(
        id: 'decision-1',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decision: AnalystDecisionType.defer,
        rationale: 'Historical decision remains independent.',
        analystId: 'analyst-1',
        decidedAt: _createdAt,
      ),
    );
  });

  test('adds and retrieves analyst-proposed, unverified references', () async {
    final hypothesis = await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    final reference =
        (await service.getReferencesForHypothesis('hypothesis-1')).single;

    expect(hypothesis.mitreAttackReferences, [reference]);
    expect(reference.isProposed, isTrue);
    expect(reference.isVerified, isFalse);
    expect(reference.proposedBy, 'analyst-2');
    expect(reference.proposedAt, _createdAt);
    expect(reference.verificationMetadata, isNull);
    expect(
      (await InMemoryAnalystDecisionRepository(dataSource)
              .getHistoryForHypothesis('hypothesis-1'))
          .single
          .id,
      'decision-1',
    );
    expect(
      (await hypotheses.getById('hypothesis-1')).status,
      HypothesisStatus.candidate,
    );
  });

  test('rejects duplicate and malformed technique identifiers', () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    await expectLater(
      service.addProposedReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-2',
        reference: _t1059(),
      ),
      throwsA(isA<DuplicateRecordException>()),
    );
    await expectLater(
      service.addProposedReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-2',
        reference: _t1059(techniqueId: 'not-an-attack-id'),
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
    expect(
      (await service.getReferencesForHypothesis('hypothesis-1'))
          .map((item) => item.techniqueId),
      ['T1059'],
    );
  });

  test('only the proposing analyst may remove or verify a mapping', () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );

    await expectLater(
      service.removeProposedReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-3',
        techniqueId: 'T1059',
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
    await expectLater(
      service.verifyReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-3',
        techniqueId: 'T1059',
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
    expect(
      (await service.getReferencesForHypothesis('hypothesis-1'))
          .single
          .isProposed,
      isTrue,
    );
  });

  test('preserves existing references when adding another proposal', () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _powerShell(),
    );

    expect(
      (await service.getReferencesForHypothesis('hypothesis-1'))
          .map((item) => item.techniqueId),
      ['T1059', 'T1059.001'],
    );
  });

  test('stores verified metadata only when the verifier returns grounded data',
      () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    verifier.result = MitreReferenceVerifiedResult(_verifiedT1059());

    final result = await service.verifyReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      techniqueId: 'T1059',
    );
    final stored =
        (await service.getReferencesForHypothesis('hypothesis-1')).single;

    expect(result, isA<MitreReferenceVerifiedResult>());
    expect(stored.isVerified, isTrue);
    expect(stored.proposedBy, 'analyst-2');
    expect(stored.proposedAt, _createdAt);
    expect(stored.catalogVersion, 'ATT&CK v20 / T1059 v2.7');
    expect(stored.verificationMetadata?.sourceUrl, _officialSource);
    expect(
      (await hypotheses.getById('hypothesis-1')).status,
      HypothesisStatus.candidate,
    );
  });

  test('does not store mismatched or ungrounded verification claims', () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    verifier.result = MitreReferenceVerifiedResult(
      _verifiedT1059(techniqueName: 'A different name'),
    );
    expect(
      await service.verifyReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-2',
        techniqueId: 'T1059',
      ),
      isA<MitreReferenceMismatchResult>(),
    );

    verifier.result = MitreReferenceVerifiedResult(
      _verifiedT1059(
        metadataSourceUrl: 'https://example.test/unofficial',
      ),
    );
    expect(
      await service.verifyReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-2',
        techniqueId: 'T1059',
      ),
      isA<MitreReferenceUnverifiedResult>(),
    );
    final stored =
        (await service.getReferencesForHypothesis('hypothesis-1')).single;
    expect(stored.isProposed, isTrue);
    expect(stored.verificationMetadata, isNull);
  });

  test('preserves proposed mappings for negative verification results',
      () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    for (final result in <MitreReferenceVerificationResult>[
      const MitreReferenceNotFoundResult('Not found.'),
      const MitreReferenceMismatchResult('Metadata does not match.'),
      const MitreReferenceDeprecatedResult('Reference is deprecated.'),
      const MitreReferenceUnverifiedResult('Not independently checked.'),
      const MitreReferenceVerificationUnavailableResult('Catalog unavailable.'),
    ]) {
      verifier.result = result;
      expect(
        await service.verifyReference(
          hypothesisId: 'hypothesis-1',
          analystId: 'analyst-2',
          techniqueId: 'T1059',
        ),
        same(result),
      );
      expect(
        (await service.getReferencesForHypothesis('hypothesis-1'))
            .single
            .isProposed,
        isTrue,
      );
    }
  });

  test('default verifier explicitly reports unavailable and makes no write',
      () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    final defaultService = MitreReferenceWorkflowService(
      hypothesisRepository: hypotheses,
      investigationRepository: investigations,
    );

    expect(
      await defaultService.verifyReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-2',
        techniqueId: 'T1059',
      ),
      isA<MitreReferenceVerificationUnavailableResult>(),
    );
    expect(
      (await service.getReferencesForHypothesis('hypothesis-1'))
          .single
          .isProposed,
      isTrue,
    );
  });

  test('propagates verifier failures and leaves the proposal unchanged',
      () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    verifier.error = StateError('verification provider failed');

    await expectLater(
      service.verifyReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-2',
        techniqueId: 'T1059',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      (await service.getReferencesForHypothesis('hypothesis-1'))
          .single
          .isProposed,
      isTrue,
    );
  });

  test('closed investigations reject mapping changes', () async {
    await investigations.create(
      _investigation(
        id: 'closed-investigation',
        status: InvestigationStatus.closed,
      ),
    );
    await hypotheses.add(
      _hypothesis(
        id: 'closed-hypothesis',
        investigationId: 'closed-investigation',
        supportingEvidenceIds: const [],
      ),
    );

    await expectLater(
      service.addProposedReference(
        hypothesisId: 'closed-hypothesis',
        analystId: 'analyst-2',
        reference: _t1059(),
      ),
      throwsA(isA<InvestigationClosedException>()),
    );
    expect(
      (await hypotheses.getById('closed-hypothesis')).mitreAttackReferences,
      isEmpty,
    );
  });

  test('removes only proposed mappings and rejects invalid verification data',
      () async {
    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    await service.removeProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      techniqueId: 'T1059',
    );
    expect(await service.getReferencesForHypothesis('hypothesis-1'), isEmpty);

    await service.addProposedReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      reference: _t1059(),
    );
    verifier.result = MitreReferenceVerifiedResult(_verifiedT1059());
    await service.verifyReference(
      hypothesisId: 'hypothesis-1',
      analystId: 'analyst-2',
      techniqueId: 'T1059',
    );
    await expectLater(
      service.removeProposedReference(
        hypothesisId: 'hypothesis-1',
        analystId: 'analyst-2',
        techniqueId: 'T1059',
      ),
      throwsA(isA<InvalidWorkflowInputException>()),
    );
  });

  test('rejects non-HTTPS reference URLs at the domain boundary', () {
    expect(
      () => _t1059(referenceUrl: 'http://attack.mitre.org/techniques/T1059/'),
      throwsArgumentError,
    );
  });
}

class _FakeVerifier implements MitreReferenceVerifier {
  _FakeVerifier(this.result);

  MitreReferenceVerificationResult result;
  Object? error;

  @override
  Future<MitreReferenceVerificationResult> verify(
    MitreAttackReference reference,
  ) async {
    final error = this.error;
    if (error != null) throw error;
    return result;
  }
}

MitreAttackReference _t1059({
  String techniqueId = 'T1059',
  String techniqueName = 'Command and Scripting Interpreter',
  String referenceUrl = 'https://attack.mitre.org/techniques/T1059/',
}) =>
    MitreAttackReference(
      techniqueId: techniqueId,
      techniqueName: techniqueName,
      tactic: 'Execution',
      description: 'Adversaries may abuse command and script interpreters.',
      referenceUrl: referenceUrl,
    );

MitreAttackReference _powerShell() => MitreAttackReference(
      techniqueId: 'T1059.001',
      techniqueName: 'PowerShell',
      tactic: 'Execution',
      description: 'Official ATT&CK sub-technique test fixture.',
      referenceUrl: 'https://attack.mitre.org/techniques/T1059/001/',
    );

MitreAttackReference _verifiedT1059({
  String techniqueName = 'Command and Scripting Interpreter',
  String metadataSourceUrl = _officialSource,
}) =>
    MitreAttackReference(
      techniqueId: 'T1059',
      techniqueName: techniqueName,
      tactic: 'Execution',
      description: 'Adversaries may abuse command and script interpreters.',
      referenceUrl: _officialSource,
      catalogVersion: 'ATT&CK v20 / T1059 v2.7',
      verificationMetadata: MitreVerificationMetadata(
        verifiedBy: 'test-provider',
        verifiedAt: _createdAt,
        catalogVersion: 'ATT&CK v20 / T1059 v2.7',
        sourceUrl: metadataSourceUrl,
      ),
    );

Investigation _investigation({
  String id = 'investigation-1',
  InvestigationStatus status = InvestigationStatus.draft,
}) =>
    Investigation(
      id: id,
      title: 'MITRE test case',
      description: 'Mapping workflow test.',
      status: status,
      priority: InvestigationPriority.medium,
      createdAt: _createdAt,
      updatedAt: _createdAt,
      relatedEntityIds: const [],
      relatedConnectionIds: const [],
    );

Evidence _evidence() => Evidence(
      id: 'evidence-1',
      investigationId: 'investigation-1',
      title: 'Mapping test evidence',
      description: 'A test record.',
      evidenceType: EvidenceType.analystObservation,
      provenance: DataProvenance(
        origin: DataOrigin.analystCreated,
        source: EvidenceSource(description: 'Mapping test source'),
        authorId: 'analyst-1',
        recordedAt: _createdAt,
      ),
      collectedAt: _createdAt,
      reliability: EvidenceReliability.medium,
      reliabilityRationale: 'Recorded for repository tests.',
      dataClassification: DataClassification.internal,
    );

Hypothesis _hypothesis({
  String id = 'hypothesis-1',
  String investigationId = 'investigation-1',
  Iterable<String> supportingEvidenceIds = const ['evidence-1'],
}) =>
    Hypothesis(
      id: id,
      investigationId: investigationId,
      title: 'Mapping test hypothesis',
      explanation: 'A test hypothesis, not a finding.',
      supportingEvidenceIds: supportingEvidenceIds,
      confidence: .3,
      confidenceExplanation: 'Uncalibrated test score.',
      status: HypothesisStatus.candidate,
      generatedAt: _createdAt,
      provenance: DataProvenance(
        origin: DataOrigin.analystCreated,
        source: EvidenceSource(description: 'Mapping test source'),
        authorId: 'analyst-1',
        recordedAt: _createdAt,
      ),
    );
