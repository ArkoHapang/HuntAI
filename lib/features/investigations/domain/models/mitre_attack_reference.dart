import 'model_validation.dart';

class MitreVerificationMetadata {
  MitreVerificationMetadata({
    required String verifiedBy,
    required DateTime verifiedAt,
    String? catalogVersion,
    String? sourceUrl,
  })  : verifiedBy =
            ModelValidation.requiredIdentifier(verifiedBy, 'verifiedBy'),
        verifiedAt = ModelValidation.utc(verifiedAt),
        catalogVersion = _optionalText(catalogVersion, 'catalogVersion'),
        sourceUrl = sourceUrl == null
            ? null
            : ModelValidation.httpsUri(sourceUrl, 'sourceUrl').toString();

  final String verifiedBy;
  final DateTime verifiedAt;
  final String? catalogVersion;
  final String? sourceUrl;

  static String? _optionalText(String? value, String fieldName) {
    if (value == null) return null;
    return ModelValidation.requiredText(value, fieldName);
  }
}

class MitreAttackReference {
  MitreAttackReference({
    required String techniqueId,
    required String techniqueName,
    required String tactic,
    required String description,
    required String referenceUrl,
    String? catalogVersion,
    String? proposedBy,
    DateTime? proposedAt,
    this.verificationMetadata,
  })  : techniqueId =
            ModelValidation.requiredIdentifier(techniqueId, 'techniqueId'),
        techniqueName =
            ModelValidation.requiredText(techniqueName, 'techniqueName'),
        tactic = ModelValidation.requiredText(tactic, 'tactic'),
        description = ModelValidation.requiredText(description, 'description'),
        referenceUrl =
            ModelValidation.httpsUri(referenceUrl, 'referenceUrl').toString(),
        catalogVersion = _optionalText(catalogVersion, 'catalogVersion'),
        proposedBy = proposedBy == null
            ? null
            : ModelValidation.requiredIdentifier(proposedBy, 'proposedBy'),
        proposedAt =
            proposedAt == null ? null : ModelValidation.utc(proposedAt) {
    if ((this.proposedBy == null) != (this.proposedAt == null)) {
      throw ArgumentError(
        'proposedBy and proposedAt must either both be set or both be null.',
      );
    }
  }

  final String techniqueId;
  final String techniqueName;
  final String tactic;
  final String description;
  final String referenceUrl;
  final String? catalogVersion;
  final String? proposedBy;
  final DateTime? proposedAt;
  final MitreVerificationMetadata? verificationMetadata;

  bool get isProposed => proposedBy != null && verificationMetadata == null;

  bool get isVerified => verificationMetadata != null;

  static String? _optionalText(String? value, String fieldName) {
    if (value == null) return null;
    return ModelValidation.requiredText(value, fieldName);
  }
}
