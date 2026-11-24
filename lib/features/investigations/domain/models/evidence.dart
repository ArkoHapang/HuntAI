import '../enums/investigation_enums.dart';
import 'data_provenance.dart';
import 'model_validation.dart';

class Evidence {
  Evidence({
    required String id,
    required String investigationId,
    required String title,
    required this.description,
    required this.evidenceType,
    required this.provenance,
    required DateTime collectedAt,
    required this.reliability,
    required String reliabilityRationale,
    required this.dataClassification,
    DateTime? observedAt,
    Iterable<String> relatedEntityIds = const [],
    Iterable<String> relatedConnectionIds = const [],
  })  : id = ModelValidation.requiredIdentifier(id, 'id'),
        investigationId = ModelValidation.requiredIdentifier(
            investigationId, 'investigationId'),
        title = ModelValidation.requiredText(title, 'title'),
        collectedAt = ModelValidation.utc(collectedAt),
        observedAt =
            observedAt == null ? null : ModelValidation.utc(observedAt),
        reliabilityRationale = ModelValidation.requiredText(
          reliabilityRationale,
          'reliabilityRationale',
        ),
        relatedEntityIds = ModelValidation.immutableUniqueIds(
          relatedEntityIds,
          'relatedEntityIds',
        ),
        relatedConnectionIds = ModelValidation.immutableUniqueIds(
          relatedConnectionIds,
          'relatedConnectionIds',
        ) {
    if (provenance.origin == DataOrigin.aiGenerated) {
      throw ArgumentError(
        'AI-generated hypotheses or content must not be stored as evidence.',
      );
    }
  }

  final String id;
  final String investigationId;
  final String title;
  final String description;
  final EvidenceType evidenceType;
  final DataProvenance provenance;
  final DateTime? observedAt;
  final DateTime collectedAt;
  final EvidenceReliability reliability;
  final String reliabilityRationale;
  final DataClassification dataClassification;
  final List<String> relatedEntityIds;
  final List<String> relatedConnectionIds;

  EvidenceSource get source => provenance.source;
}
