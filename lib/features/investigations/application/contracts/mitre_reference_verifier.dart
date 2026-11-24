import '../../domain/models/mitre_attack_reference.dart';
import '../models/mitre_reference_verification_result.dart';

abstract interface class MitreReferenceVerifier {
  Future<MitreReferenceVerificationResult> verify(
    MitreAttackReference reference,
  );
}

/// Default verifier: no bundled authoritative catalog or runtime network access.
class UnavailableMitreReferenceVerifier implements MitreReferenceVerifier {
  const UnavailableMitreReferenceVerifier();

  @override
  Future<MitreReferenceVerificationResult> verify(
    MitreAttackReference reference,
  ) async =>
      const MitreReferenceVerificationUnavailableResult(
        'No authoritative MITRE ATT&CK catalog is configured; runtime '
        'verification is disabled.',
      );
}
