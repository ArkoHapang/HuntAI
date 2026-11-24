import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/features/investigations/domain/enums/investigation_enums.dart';
import 'package:huntai/features/investigations/domain/models/analyst_decision.dart';
import 'package:huntai/features/investigations/domain/models/data_provenance.dart';
import 'package:huntai/features/investigations/domain/models/evidence.dart';
import 'package:huntai/features/investigations/domain/models/hypothesis.dart';
import 'package:huntai/features/investigations/domain/models/investigation.dart';
import 'package:huntai/features/investigations/domain/models/mitre_attack_reference.dart';
import 'package:huntai/features/investigations/domain/validation/investigation_reference_validator.dart';

final _createdAt = DateTime.utc(2026, 11, 19, 10);
final _laterAt = DateTime.utc(2026, 11, 19, 11);

Investigation _investigation({
  String id = 'investigation-1',
  String title = 'Sample investigation',
  DateTime? createdAt,
  DateTime? updatedAt,
  Iterable<String> entityIds = const ['entity-1'],
  Iterable<String> connectionIds = const ['connection-1'],
  Iterable<String> evidenceIds = const ['evidence-1'],
  Iterable<String> hypothesisIds = const ['hypothesis-1'],
}) {
  return Investigation(
    id: id,
    title: title,
    description: 'A domain model test.',
    status: InvestigationStatus.draft,
    priority: InvestigationPriority.medium,
    createdAt: createdAt ?? _createdAt,
    updatedAt: updatedAt ?? _laterAt,
    relatedEntityIds: entityIds,
    relatedConnectionIds: connectionIds,
    evidenceIds: evidenceIds,
    hypothesisIds: hypothesisIds,
  );
}

DataProvenance _analystProvenance({
  DataOrigin origin = DataOrigin.analystCreated,
  String? sourceIdentifier,
  String? authorId = 'analyst-1',
  DateTime? recordedAt,
}) {
  return DataProvenance(
    origin: origin,
    source: EvidenceSource(
      description: 'Analyst supplied source',
      identifier: sourceIdentifier,
    ),
    authorId: authorId,
    recordedAt: recordedAt ?? _createdAt,
  );
}

Evidence _evidence({
  String id = 'evidence-1',
  String investigationId = 'investigation-1',
  Iterable<String> entityIds = const ['entity-1'],
  Iterable<String> connectionIds = const ['connection-1'],
  DataProvenance? provenance,
  EvidenceReliability reliability = EvidenceReliability.unassessed,
  String reliabilityRationale = 'Not assessed.',
  DateTime? observedAt,
  DateTime? collectedAt,
}) {
  return Evidence(
    id: id,
    investigationId: investigationId,
    title: 'Sample evidence',
    description: 'A model test record.',
    evidenceType: EvidenceType.analystObservation,
    provenance: provenance ?? _analystProvenance(),
    observedAt: observedAt,
    collectedAt: collectedAt ?? _laterAt,
    relatedEntityIds: entityIds,
    relatedConnectionIds: connectionIds,
    reliability: reliability,
    reliabilityRationale: reliabilityRationale,
    dataClassification: DataClassification.internal,
  );
}

Hypothesis _hypothesis({
  String id = 'hypothesis-1',
  String investigationId = 'investigation-1',
  double confidence = .5,
  Iterable<String> supporting = const ['evidence-1'],
  Iterable<String> contradicting = const [],
  Iterable<String> entityIds = const ['entity-1'],
  Iterable<String> connectionIds = const ['connection-1'],
  DataProvenance? provenance,
  GenerationMetadata? generationMetadata,
  DateTime? generatedAt,
  DateTime? reviewedAt,
  Iterable<MitreAttackReference> mitreReferences = const [],
}) {
  return Hypothesis(
    id: id,
    investigationId: investigationId,
    title: 'Candidate explanation',
    explanation: 'A test-only explanation, not a finding.',
    supportingEvidenceIds: supporting,
    contradictingEvidenceIds: contradicting,
    relatedEntityIds: entityIds,
    relatedConnectionIds: connectionIds,
    confidence: confidence,
    confidenceExplanation: 'Uncalibrated test heuristic.',
    status: HypothesisStatus.candidate,
    generatedAt: generatedAt ?? _laterAt,
    reviewedAt: reviewedAt,
    alternativeExplanations: const ['Another possible explanation.'],
    evidenceGaps: [
      EvidenceGap(
        description: 'No independent corroboration.',
        reason: 'One source is insufficient.',
      ),
    ],
    mitreAttackReferences: mitreReferences,
    generationMetadata: generationMetadata,
    provenance: provenance ?? _analystProvenance(),
  );
}

void main() {
  group('Investigation', () {
    test('creates a valid investigation with typed notes', () {
      final investigation = Investigation(
        id: 'case-1',
        title: 'Case one',
        description: 'Description',
        status: InvestigationStatus.active,
        priority: InvestigationPriority.high,
        createdAt: _createdAt,
        updatedAt: _laterAt,
        analystNotes: [
          AnalystNote(
            id: 'note-1',
            authorId: 'analyst-1',
            text: 'Initial note.',
            timestamp: _createdAt,
          ),
        ],
      );

      expect(investigation.status, InvestigationStatus.active);
      expect(investigation.analystNotes.single.authorId, 'analyst-1');
    });

    test('rejects empty ID and title', () {
      expect(() => _investigation(id: ' '), throwsArgumentError);
      expect(() => _investigation(title: ' \t '), throwsArgumentError);
    });

    test('rejects updatedAt earlier than createdAt', () {
      expect(
        () => _investigation(createdAt: _laterAt, updatedAt: _createdAt),
        throwsArgumentError,
      );
    });

    test('exposes defensive unmodifiable collections', () {
      final input = ['entity-1'];
      final investigation = _investigation(entityIds: input);
      input.add('entity-2');

      expect(investigation.relatedEntityIds, ['entity-1']);
      expect(
        () => investigation.relatedEntityIds.add('entity-3'),
        throwsUnsupportedError,
      );
    });

    test('rejects duplicate IDs in collections', () {
      expect(
        () => _investigation(entityIds: ['entity-1', 'entity-1']),
        throwsArgumentError,
      );
    });
  });

  group('Evidence and provenance', () {
    test('creates valid evidence and exposes its provenance source', () {
      final evidence = _evidence();
      expect(evidence.source.description, 'Analyst supplied source');
      expect(evidence.reliability, EvidenceReliability.unassessed);
    });

    test('requires a source record for observed telemetry', () {
      expect(
        () => DataProvenance(
          origin: DataOrigin.observedTelemetry,
          source: EvidenceSource(description: 'Unknown source'),
          recordedAt: _createdAt,
        ),
        throwsArgumentError,
      );
      expect(
        DataProvenance(
          origin: DataOrigin.observedTelemetry,
          source: EvidenceSource(
            description: 'Sensor record',
            identifier: 'record-1',
          ),
          recordedAt: _createdAt,
        ).origin,
        DataOrigin.observedTelemetry,
      );
    });

    test('requires an author for analyst-created observations', () {
      expect(
        () => DataProvenance(
          origin: DataOrigin.analystCreated,
          source: EvidenceSource(description: 'Unknown source'),
          recordedAt: _createdAt,
        ),
        throwsArgumentError,
      );
    });

    test('requires and distinguishes AI generator provenance', () {
      final syntheticProvenance = DataProvenance(
        origin: DataOrigin.syntheticDemo,
        source: EvidenceSource(description: 'Synthetic demonstration fixture'),
        recordedAt: _createdAt,
      );
      expect(
        _evidence(provenance: syntheticProvenance).provenance.origin,
        DataOrigin.syntheticDemo,
      );

      expect(
        () => DataProvenance(
          origin: DataOrigin.aiGenerated,
          source: EvidenceSource(description: 'Local generator'),
          recordedAt: _createdAt,
        ),
        throwsArgumentError,
      );

      final aiProvenance = DataProvenance(
        origin: DataOrigin.aiGenerated,
        source: EvidenceSource(description: 'Local deterministic mock'),
        generatorName: 'Local mock',
        generatorVersion: 'test-v1',
        recordedAt: _createdAt,
      );
      expect(aiProvenance.origin, DataOrigin.aiGenerated);
      expect(aiProvenance.generatorVersion, 'test-v1');
      expect(
        () => _evidence(provenance: aiProvenance),
        throwsArgumentError,
      );
    });

    test('requires a reliability rationale including when unassessed', () {
      expect(
        () => _evidence(reliabilityRationale: '  '),
        throwsArgumentError,
      );
      expect(
        _evidence(
          reliability: EvidenceReliability.unassessed,
          reliabilityRationale: 'Not assessed yet.',
        ).reliabilityRationale,
        'Not assessed yet.',
      );
    });

    test('does not impose observedAt before collectedAt', () {
      final evidence = _evidence(
        observedAt: _laterAt,
        collectedAt: _createdAt,
      );
      expect(evidence.observedAt, _laterAt);
      expect(evidence.collectedAt, _createdAt);
    });
  });

  group('Hypothesis', () {
    test('creates a valid hypothesis and confidence boundaries are inclusive',
        () {
      expect(_hypothesis(confidence: 0).confidence, 0);
      expect(_hypothesis(confidence: 1).confidence, 1);
      expect(_hypothesis().evidenceGaps.single.reason, isNotEmpty);
    });

    test('rejects negative confidence', () {
      expect(() => _hypothesis(confidence: -.01), throwsArgumentError);
    });

    test('rejects confidence greater than one', () {
      expect(() => _hypothesis(confidence: 1.01), throwsArgumentError);
    });

    test('rejects NaN and infinite confidence', () {
      expect(() => _hypothesis(confidence: double.nan), throwsArgumentError);
      expect(
        () => _hypothesis(confidence: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => _hypothesis(confidence: double.negativeInfinity),
        throwsArgumentError,
      );
    });

    test('rejects overlapping supporting and contradicting evidence', () {
      expect(
        () => _hypothesis(
          supporting: const ['evidence-1'],
          contradicting: const ['evidence-1'],
        ),
        throwsArgumentError,
      );
    });

    test('checks evidence overlap without re-iterating input collections', () {
      expect(
        () => _hypothesis(
          supporting: _SingleUseIterable(['evidence-1']),
          contradicting: _SingleUseIterable(['evidence-1']),
        ),
        throwsArgumentError,
      );
      expect(
        () => _hypothesis(
          supporting: _SingleUseIterable(['evidence-1']),
          contradicting: _SingleUseIterable(['evidence-2']),
        ),
        returnsNormally,
      );
    });

    test('requires generation metadata for AI-generated hypotheses', () {
      final provenance = DataProvenance(
        origin: DataOrigin.aiGenerated,
        source: EvidenceSource(description: 'Local deterministic mock'),
        generatorName: 'Local mock',
        generatorVersion: 'test-v1',
        recordedAt: _laterAt,
      );
      expect(
        () => _hypothesis(provenance: provenance),
        throwsArgumentError,
      );
      expect(
        _hypothesis(
          provenance: provenance,
          generationMetadata: GenerationMetadata(
            method: 'Deterministic rules',
            ruleSetVersion: 'rules-v1',
          ),
        ).generationMetadata!.method,
        'Deterministic rules',
      );
    });

    test('keeps observed telemetry distinct from hypotheses', () {
      final observedProvenance = DataProvenance(
        origin: DataOrigin.observedTelemetry,
        source: EvidenceSource(
          description: 'Known sample record',
          identifier: 'record-1',
        ),
        recordedAt: _createdAt,
      );

      expect(
        () => _hypothesis(provenance: observedProvenance),
        throwsArgumentError,
      );
      expect(
        () => _hypothesis(
          generationMetadata: GenerationMetadata(
            method: 'Deterministic rules',
            ruleSetVersion: 'rules-v1',
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  test('builds a structurally valid, explicitly unverified ATT&CK reference',
      () {
    final reference = MitreAttackReference(
      techniqueId: 'caller-supplied-test-id',
      techniqueName: 'Test-only name',
      tactic: 'Test-only tactic',
      description: 'Test record; no official identifier is asserted.',
      referenceUrl: 'https://example.test/reference',
    );

    expect(reference.techniqueId, 'caller-supplied-test-id');
    expect(reference.verificationMetadata, isNull);
    expect(
      () => MitreAttackReference(
        techniqueId: 'opaque-id',
        techniqueName: 'Name',
        tactic: 'Tactic',
        description: 'Description',
        referenceUrl: 'http://example.test/reference',
      ),
      throwsArgumentError,
    );
  });

  test('hypothesis references are unique by technique ID', () {
    final reference = MitreAttackReference(
      techniqueId: 'T1059',
      techniqueName: 'Command and Scripting Interpreter',
      tactic: 'Execution',
      description: 'Test mapping; not evidence that the technique occurred.',
      referenceUrl: 'https://attack.mitre.org/techniques/T1059/',
    );

    expect(
      () => _hypothesis(mitreReferences: [reference, reference]),
      throwsArgumentError,
    );
    expect(_hypothesis(mitreReferences: [reference]).mitreAttackReferences,
        [reference]);
  });

  test('requires a meaningful analyst decision rationale', () {
    expect(
      () => AnalystDecision(
        id: 'decision-1',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decision: AnalystDecisionType.accept,
        rationale: '  ',
        analystId: 'analyst-1',
        decidedAt: _laterAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => AnalystDecision(
        id: 'decision-2',
        investigationId: 'investigation-1',
        hypothesisId: 'hypothesis-1',
        decision: AnalystDecisionType.accept,
        rationale: 'short',
        analystId: 'analyst-1',
        decidedAt: _laterAt,
      ),
      throwsArgumentError,
    );
  });

  test('normalizes model timestamps to UTC', () {
    final localTime = DateTime(2026, 11, 19, 12);
    final laterLocalTime = localTime.add(const Duration(minutes: 1));
    final investigation = _investigation(
      createdAt: localTime,
      updatedAt: laterLocalTime,
    );
    final provenance = _analystProvenance(recordedAt: localTime);
    final evidence = _evidence(
      provenance: provenance,
      observedAt: laterLocalTime,
      collectedAt: localTime,
    );
    final hypothesis = _hypothesis(
      generatedAt: localTime,
      reviewedAt: laterLocalTime,
    );
    final decision = AnalystDecision(
      id: 'decision-utc',
      investigationId: investigation.id,
      hypothesisId: 'hypothesis-1',
      decision: AnalystDecisionType.defer,
      rationale: 'UTC normalization check.',
      analystId: 'analyst-1',
      decidedAt: localTime,
    );
    final verification = MitreVerificationMetadata(
      verifiedBy: 'reviewer-1',
      verifiedAt: localTime,
    );

    expect(investigation.createdAt.isUtc, isTrue);
    expect(investigation.updatedAt.isUtc, isTrue);
    expect(provenance.recordedAt.isUtc, isTrue);
    expect(evidence.observedAt!.isUtc, isTrue);
    expect(evidence.collectedAt.isUtc, isTrue);
    expect(hypothesis.generatedAt.isUtc, isTrue);
    expect(hypothesis.reviewedAt!.isUtc, isTrue);
    expect(decision.decidedAt.isUtc, isTrue);
    expect(verification.verifiedAt.isUtc, isTrue);
  });

  group('Investigation reference validation', () {
    test('accepts references within one investigation', () {
      final investigation = _investigation();
      final evidence = _evidence();
      final hypothesis = _hypothesis();

      expect(
        () => InvestigationReferenceValidator.validateSnapshot(
          investigation: investigation,
          availableEntityIds: const ['entity-1'],
          availableConnectionIds: const ['connection-1'],
          evidence: [evidence],
          hypotheses: [hypothesis],
        ),
        returnsNormally,
      );

      final decision = AnalystDecision(
        id: 'decision-1',
        investigationId: investigation.id,
        hypothesisId: hypothesis.id,
        decision: AnalystDecisionType.defer,
        rationale: 'Await additional evidence.',
        analystId: 'analyst-1',
        decidedAt: _laterAt,
      );
      expect(
        () => InvestigationReferenceValidator.validateDecision(
          investigation: investigation,
          hypothesis: hypothesis,
          decision: decision,
        ),
        returnsNormally,
      );
    });

    test('rejects cross-investigation evidence and missing graph references',
        () {
      expect(
        () => InvestigationReferenceValidator.validateSnapshot(
          investigation: _investigation(),
          availableEntityIds: const [],
          availableConnectionIds: const ['connection-1'],
          evidence: [_evidence()],
          hypotheses: [_hypothesis()],
        ),
        throwsArgumentError,
      );

      expect(
        () => InvestigationReferenceValidator.validateSnapshot(
          investigation: _investigation(),
          availableEntityIds: const ['entity-1'],
          availableConnectionIds: const ['connection-1'],
          evidence: [_evidence(investigationId: 'another-investigation')],
          hypotheses: [_hypothesis()],
        ),
        throwsArgumentError,
      );
    });
  });
}

class _SingleUseIterable extends IterableBase<String> {
  _SingleUseIterable(this._values);

  final List<String> _values;
  bool _iterated = false;

  @override
  Iterator<String> get iterator {
    if (_iterated) throw StateError('This iterable can only be read once.');
    _iterated = true;
    return _values.iterator;
  }
}
