import '../../domain/models/mitre_attack_reference.dart';

sealed class MitreReferenceVerificationResult {
  const MitreReferenceVerificationResult();
}

final class MitreReferenceVerifiedResult
    extends MitreReferenceVerificationResult {
  const MitreReferenceVerifiedResult(this.reference);

  final MitreAttackReference reference;
}

final class MitreReferenceNotFoundResult
    extends MitreReferenceVerificationResult {
  const MitreReferenceNotFoundResult(this.message);

  final String message;
}

final class MitreReferenceMismatchResult
    extends MitreReferenceVerificationResult {
  const MitreReferenceMismatchResult(this.message);

  final String message;
}

final class MitreReferenceDeprecatedResult
    extends MitreReferenceVerificationResult {
  const MitreReferenceDeprecatedResult(this.message);

  final String message;
}

final class MitreReferenceUnverifiedResult
    extends MitreReferenceVerificationResult {
  const MitreReferenceUnverifiedResult(this.message);

  final String message;
}

final class MitreReferenceVerificationUnavailableResult
    extends MitreReferenceVerificationResult {
  const MitreReferenceVerificationUnavailableResult(this.message);

  final String message;
}
