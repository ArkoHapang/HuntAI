import '../../data/exceptions/investigation_repository_exception.dart';
import '../../data/repositories/hypothesis_repository.dart';
import '../../data/repositories/investigation_repository.dart';
import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/mitre_attack_reference.dart';
import '../contracts/mitre_reference_verifier.dart';
import '../exceptions/investigation_workflow_exception.dart';
import '../models/mitre_reference_verification_result.dart';

class MitreReferenceWorkflowService {
  MitreReferenceWorkflowService({
    required HypothesisRepository hypothesisRepository,
    required InvestigationRepository investigationRepository,
    MitreReferenceVerifier verifier = const UnavailableMitreReferenceVerifier(),
    DateTime Function()? clock,
  })  : _hypotheses = hypothesisRepository,
        _investigations = investigationRepository,
        _verifier = verifier,
        _clock = clock ?? DateTime.now;

  static final RegExp _techniqueIdPattern =
      RegExp(r'^T[0-9]{4}(?:\.[0-9]{3})?$');

  final HypothesisRepository _hypotheses;
  final InvestigationRepository _investigations;
  final MitreReferenceVerifier _verifier;
  final DateTime Function() _clock;

  Future<Hypothesis> addProposedReference({
    required String hypothesisId,
    required String analystId,
    required MitreAttackReference reference,
  }) async {
    _validateTechniqueId(reference.techniqueId);
    if (reference.verificationMetadata != null ||
        reference.proposedBy != null ||
        reference.proposedAt != null) {
      throw const InvalidWorkflowInputException(
        'New mappings must be unverified; proposal identity and time are '
        'assigned by the workflow.',
      );
    }
    final hypothesis = await _getOpenHypothesis(hypothesisId);
    final proposed = _copyReference(
      reference,
      proposedBy: analystId,
      proposedAt: _clock().toUtc(),
    );
    return _hypotheses.addMitreAttackReference(
      hypothesisId: hypothesis.id,
      reference: proposed,
    );
  }

  Future<List<MitreAttackReference>> getReferencesForHypothesis(
    String hypothesisId,
  ) async {
    final hypothesis = await _hypotheses.getById(hypothesisId);
    return List<MitreAttackReference>.unmodifiable(
      hypothesis.mitreAttackReferences,
    );
  }

  Future<Hypothesis> removeProposedReference({
    required String hypothesisId,
    required String analystId,
    required String techniqueId,
  }) async {
    _validateTechniqueId(techniqueId);
    final hypothesis = await _getOpenHypothesis(hypothesisId);
    final matching = hypothesis.mitreAttackReferences
        .where((item) => item.techniqueId == techniqueId);
    if (matching.isEmpty) {
      throw RecordNotFoundException(
        recordType: 'MITRE ATT&CK reference',
        recordId: techniqueId,
      );
    }
    if (!matching.first.isProposed || matching.first.proposedBy != analystId) {
      throw const InvalidWorkflowInputException(
        'Only the proposing analyst may remove an unverified mapping.',
      );
    }
    return _hypotheses.removeProposedMitreAttackReference(
      hypothesisId: hypothesisId,
      techniqueId: techniqueId,
    );
  }

  Future<MitreReferenceVerificationResult> verifyReference({
    required String hypothesisId,
    required String analystId,
    required String techniqueId,
  }) async {
    _validateTechniqueId(techniqueId);
    final hypothesis = await _getOpenHypothesis(hypothesisId);
    final matches = hypothesis.mitreAttackReferences
        .where((item) => item.techniqueId == techniqueId);
    if (matches.isEmpty) {
      throw RecordNotFoundException(
        recordType: 'MITRE ATT&CK reference',
        recordId: techniqueId,
      );
    }
    final proposed = matches.first;
    if (!proposed.isProposed || proposed.proposedBy != analystId) {
      throw const InvalidWorkflowInputException(
        'Only the proposing analyst may request verification of an unverified '
        'mapping.',
      );
    }

    final result = await _verifier.verify(proposed);
    if (result is! MitreReferenceVerifiedResult) return result;

    final verified = result.reference;
    if (verified.techniqueId != proposed.techniqueId ||
        verified.techniqueName != proposed.techniqueName) {
      return const MitreReferenceMismatchResult(
        'The verifier returned a different technique ID or name.',
      );
    }
    final metadata = verified.verificationMetadata;
    if (metadata == null ||
        metadata.sourceUrl == null ||
        !_isOfficialAttackUrl(metadata.sourceUrl!) ||
        !_isOfficialAttackUrl(verified.referenceUrl)) {
      return const MitreReferenceUnverifiedResult(
        'The verifier did not provide an official MITRE ATT&CK source URL '
        'and verification metadata.',
      );
    }
    if (metadata.catalogVersion != null &&
        verified.catalogVersion != null &&
        metadata.catalogVersion != verified.catalogVersion) {
      return const MitreReferenceUnverifiedResult(
        'The verifier returned conflicting ATT&CK catalog versions.',
      );
    }
    if (metadata.verifiedAt.isBefore(proposed.proposedAt!) ||
        metadata.verifiedAt.isAfter(_clock().toUtc())) {
      return const MitreReferenceUnverifiedResult(
        'The verifier returned a check time outside the proposal and workflow '
        'time bounds.',
      );
    }

    final persisted = MitreAttackReference(
      techniqueId: verified.techniqueId,
      techniqueName: verified.techniqueName,
      tactic: verified.tactic,
      description: verified.description,
      referenceUrl: verified.referenceUrl,
      catalogVersion: metadata.catalogVersion ?? verified.catalogVersion,
      proposedBy: proposed.proposedBy,
      proposedAt: proposed.proposedAt,
      verificationMetadata: metadata,
    );
    await _hypotheses.applyVerifiedMitreAttackReference(
      hypothesisId: hypothesisId,
      reference: persisted,
    );
    return MitreReferenceVerifiedResult(persisted);
  }

  void _validateTechniqueId(String techniqueId) {
    if (!_techniqueIdPattern.hasMatch(techniqueId)) {
      throw InvalidWorkflowInputException(
        'Technique ID "$techniqueId" is malformed.',
      );
    }
  }

  Future<Hypothesis> _getOpenHypothesis(String hypothesisId) async {
    final hypothesis = await _hypotheses.getById(hypothesisId);
    final investigation =
        await _investigations.getById(hypothesis.investigationId);
    if (investigation.status == InvestigationStatus.closed) {
      throw InvestigationClosedException(investigation.id);
    }
    return hypothesis;
  }

  bool _isOfficialAttackUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == 'attack.mitre.org';
  }

  MitreAttackReference _copyReference(
    MitreAttackReference reference, {
    required String proposedBy,
    required DateTime proposedAt,
  }) {
    try {
      return MitreAttackReference(
        techniqueId: reference.techniqueId,
        techniqueName: reference.techniqueName,
        tactic: reference.tactic,
        description: reference.description,
        referenceUrl: reference.referenceUrl,
        catalogVersion: reference.catalogVersion,
        proposedBy: proposedBy,
        proposedAt: proposedAt,
      );
    } on ArgumentError catch (error) {
      throw InvalidWorkflowInputException(error.message.toString());
    }
  }
}
