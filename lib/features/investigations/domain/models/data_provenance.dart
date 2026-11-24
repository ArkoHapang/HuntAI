import '../enums/investigation_enums.dart';
import 'model_validation.dart';

class EvidenceSource {
  EvidenceSource({
    required String description,
    String? identifier,
  })  : description = ModelValidation.requiredText(description, 'description'),
        identifier =
            ModelValidation.optionalIdentifier(identifier, 'identifier');

  final String description;
  final String? identifier;
}

class DataProvenance {
  DataProvenance({
    required this.origin,
    required this.source,
    required DateTime recordedAt,
    String? authorId,
    String? generatorName,
    String? generatorVersion,
  })  : recordedAt = ModelValidation.utc(recordedAt),
        authorId = ModelValidation.optionalIdentifier(authorId, 'authorId'),
        generatorName = _optionalText(generatorName, 'generatorName'),
        generatorVersion = _optionalText(generatorVersion, 'generatorVersion') {
    if (origin == DataOrigin.observedTelemetry && source.identifier == null) {
      throw ArgumentError.value(
        source.identifier,
        'source.identifier',
        'is required for observed telemetry.',
      );
    }
    if (origin == DataOrigin.analystCreated && authorId == null) {
      throw ArgumentError.value(
        authorId,
        'authorId',
        'is required for analyst-created data.',
      );
    }
    if ((this.generatorName == null) != (this.generatorVersion == null)) {
      throw ArgumentError(
        'generatorName and generatorVersion must be supplied together.',
      );
    }
    if (origin == DataOrigin.aiGenerated &&
        (this.generatorName == null || this.generatorVersion == null)) {
      throw ArgumentError(
        'generatorName and generatorVersion are required for AI-generated '
        'data.',
      );
    }
    if (origin != DataOrigin.aiGenerated && this.generatorName != null) {
      throw ArgumentError(
        'Generator metadata is only valid for AI-generated data.',
      );
    }
  }

  final DataOrigin origin;
  final EvidenceSource source;
  final String? authorId;
  final DateTime recordedAt;
  final String? generatorName;
  final String? generatorVersion;

  static String? _optionalText(String? value, String fieldName) {
    if (value == null) return null;
    return ModelValidation.requiredText(value, fieldName);
  }
}
