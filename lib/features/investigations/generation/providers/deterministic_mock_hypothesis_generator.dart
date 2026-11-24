import 'dart:math' as math;

import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/evidence.dart';
import '../../domain/models/hypothesis.dart';
import '../contracts/hypothesis_generator.dart';
import '../exceptions/hypothesis_generation_exception.dart';
import '../models/hypothesis_generation_configuration.dart';
import '../models/hypothesis_generation_request.dart';
import '../models/hypothesis_generation_result.dart';
import '../services/hypothesis_generation_validation.dart';

class StableMockHypothesisIdGenerator implements HypothesisIdGenerator {
  @override
  String generate({
    required String investigationId,
    required String generationKey,
  }) =>
      'mock-${Uri.encodeComponent(investigationId)}-'
      '${Uri.encodeComponent(generationKey)}';
}

class DeterministicMockHypothesisGenerator implements HypothesisGenerator {
  DeterministicMockHypothesisGenerator({
    DateTime Function()? clock,
    HypothesisIdGenerator? idGenerator,
  })  : _clock = clock ?? DateTime.now,
        _idGenerator = idGenerator ?? StableMockHypothesisIdGenerator();

  static const generatorName = 'HuntAI deterministic mock generator';
  static const generatorVersion = '1';

  final DateTime Function() _clock;
  final HypothesisIdGenerator _idGenerator;

  @override
  String get name => generatorName;

  @override
  String get version => generatorVersion;

  @override
  Future<HypothesisGenerationResult> generate(
    HypothesisGenerationRequest request,
  ) async {
    late final ValidatedHypothesisGenerationRequest context;
    try {
      context = HypothesisGenerationValidation.validateRequest(request);
    } on InvalidGenerationContextException catch (error) {
      return InvalidGenerationContextResult(error.message);
    } on InvalidEvidenceReferencesException catch (error) {
      return InvalidEvidenceReferencesResult(error.message);
    }

    final evidenceById = context.evidenceById;
    if (evidenceById.isEmpty) {
      return InsufficientEvidenceResult(
        message: 'No evidence was supplied for hypothesis generation.',
        evidenceGaps: [
          EvidenceGap(
            description: 'Investigation evidence is unavailable.',
            reason: 'At least one evidence record is required.',
          ),
        ],
      );
    }

    final supportingCount = context.cuePolarityByEvidenceId.values
        .where((polarity) => polarity == EvidenceCuePolarity.supporting)
        .length;
    if (supportingCount < request.configuration.minimumSupportingEvidence) {
      return InsufficientEvidenceResult(
        message:
            'There are not enough distinct, explicitly supporting records.',
        evidenceGaps: [
          EvidenceGap(
            description: 'Insufficient explicitly supporting evidence.',
            reason: 'The mock generator requires '
                '${request.configuration.minimumSupportingEvidence} distinct '
                'supporting record(s).',
          ),
        ],
      );
    }

    final groups = <String, _EvidenceGroup>{};
    for (final entry in context.cuePolarityByEvidenceId.entries) {
      final item = evidenceById[entry.key]!;
      for (final entityId in item.relatedEntityIds) {
        groups
            .putIfAbsent(
                'entity:$entityId', () => _EvidenceGroup.entity(entityId))
            .add(entry.key, entry.value);
      }
      for (final connectionId in item.relatedConnectionIds) {
        groups
            .putIfAbsent(
              'connection:$connectionId',
              () => _EvidenceGroup.connection(connectionId),
            )
            .add(entry.key, entry.value);
      }
    }

    final applicableGroups = groups.entries
        .where(
          (entry) =>
              entry.value.supportingEvidenceIds.length >=
              request.configuration.minimumSupportingEvidence,
        )
        .toList()
      ..sort((first, second) => first.key.compareTo(second.key));
    if (applicableGroups.isEmpty) {
      return const NoApplicableGenerationRulesResult(
        'No supplied graph reference has enough explicitly supporting evidence.',
      );
    }

    final hypotheses = <Hypothesis>[];
    for (final entry in applicableGroups.take(
      request.configuration.maximumHypotheses,
    )) {
      final group = entry.value;
      final supportingIds = group.supportingEvidenceIds.toList()..sort();
      final contradictingIds = group.contradictingEvidenceIds.toList()..sort();
      final encodedSupportingIds =
          supportingIds.map(Uri.encodeComponent).join(',');
      final encodedContradictingIds =
          contradictingIds.map(Uri.encodeComponent).join(',');
      final generationKey = [
        Uri.encodeComponent(entry.key),
        'support',
        encodedSupportingIds,
        'contradict',
        encodedContradictingIds,
      ].join('|');
      final generatedAt = _clock().toUtc();
      final score = _score(
        supportingIds.map((id) => evidenceById[id]!).toList(growable: false),
        contradictingIds,
      );
      if (!score.isFinite || score < 0 || score > 1) {
        return const GenerationFailureResult(
          'The deterministic scoring rubric produced an invalid confidence.',
        );
      }
      final hypothesisId = _idGenerator.generate(
        investigationId: request.investigationId,
        generationKey: generationKey,
      );
      try {
        hypotheses.add(
          Hypothesis(
            id: hypothesisId,
            investigationId: request.investigationId,
            title: 'Related evidence requires analyst review',
            explanation: 'The mock rule grouped the explicitly designated '
                'evidence records by their supplied ${group.graphType} '
                'reference "${group.graphId}". This association is a lead '
                'for review, not evidence of malicious activity or proof of '
                'compromise.',
            supportingEvidenceIds: supportingIds,
            contradictingEvidenceIds: contradictingIds,
            relatedEntityIds:
                group.entityId == null ? const [] : [group.entityId!],
            relatedConnectionIds:
                group.connectionId == null ? const [] : [group.connectionId!],
            confidence: score,
            confidenceExplanation: _confidenceExplanation(
              score: score,
              supportCount: supportingIds.length,
              contradictingCount: contradictingIds.length,
            ),
            status: HypothesisStatus.candidate,
            generatedAt: generatedAt,
            provenance: DataProvenance(
              origin: DataOrigin.aiGenerated,
              source: EvidenceSource(
                description:
                    'Deterministic mock generator; no external inference',
              ),
              recordedAt: generatedAt,
              generatorName: name,
              generatorVersion: version,
            ),
            alternativeExplanations: [
              'The records may be expected or unrelated activity; verify their '
                  'source context before drawing conclusions.',
            ],
            evidenceGaps: [
              EvidenceGap(
                description: 'Validate record context and time window.',
                reason: 'The mock rule uses supplied evidence cues and graph '
                    'associations only; it does not establish causality.',
                suggestedSource: 'Analyst review of source context',
              ),
            ],
            generationMetadata: GenerationMetadata(
              method: 'explicit-evidence-cue-shared-graph-reference',
              ruleSetVersion: version,
            ),
          ),
        );
      } on ArgumentError catch (error) {
        return GenerationFailureResult(
          'The mock provider produced an invalid hypothesis: '
          '${error.message}.',
        );
      }
    }
    if (hypotheses.map((item) => item.id).toSet().length != hypotheses.length) {
      return const GenerationFailureResult(
        'The configured ID generator returned duplicate hypothesis IDs.',
      );
    }
    return HypothesesGeneratedResult(hypotheses);
  }

  double _score(
    List<Evidence> supportingEvidence,
    List<String> contradictoryIds,
  ) {
    final distinctTypes =
        supportingEvidence.map((item) => item.evidenceType).toSet().length;
    final reliabilityMean = supportingEvidence
            .map((item) => switch (item.reliability) {
                  EvidenceReliability.unassessed => 0,
                  EvidenceReliability.low => 1,
                  EvidenceReliability.medium => 2,
                  EvidenceReliability.high => 3,
                })
            .reduce((first, second) => first + second) /
        (supportingEvidence.length * 3);
    final temporalContextPenalty =
        supportingEvidence.any((item) => item.observedAt != null) ? 0.0 : 0.05;
    return (0.40 +
            math.min(supportingEvidence.length, 3) * 0.10 +
            math.min(math.max(distinctTypes - 1, 0), 2) * 0.05 +
            reliabilityMean * 0.05 -
            math.min(contradictoryIds.length, 3) * 0.10 -
            temporalContextPenalty)
        .toDouble();
  }

  String _confidenceExplanation({
    required double score,
    required int supportCount,
    required int contradictingCount,
  }) =>
      'Deterministic mock heuristic score ${score.toStringAsFixed(2)}: '
      '$supportCount distinct supporting record(s), '
      '$contradictingCount distinct contradicting record(s), plus bounded '
      'evidence-type diversity and reliability adjustments. Missing observed '
      'times reduce the score. This is not a calibrated probability.';
}

class _EvidenceGroup {
  _EvidenceGroup.entity(String id)
      : graphType = 'graph entity',
        graphId = id,
        entityId = id,
        connectionId = null;

  _EvidenceGroup.connection(String id)
      : graphType = 'graph connection',
        graphId = id,
        entityId = null,
        connectionId = id;

  final String graphType;
  final String graphId;
  final String? entityId;
  final String? connectionId;
  final Set<String> supportingEvidenceIds = {};
  final Set<String> contradictingEvidenceIds = {};

  void add(String evidenceId, EvidenceCuePolarity polarity) {
    switch (polarity) {
      case EvidenceCuePolarity.supporting:
        supportingEvidenceIds.add(evidenceId);
      case EvidenceCuePolarity.contradicting:
        contradictingEvidenceIds.add(evidenceId);
    }
  }
}
