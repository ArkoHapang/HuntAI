import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/hypothesis.dart';
import '../../domain/models/mitre_attack_reference.dart';

abstract interface class HypothesisRepository {
  Future<void> add(Hypothesis hypothesis);

  /// Adds one investigation's batch as one validated operation; implementations
  /// must not partially persist it when any record is invalid.
  Future<void> addAll(Iterable<Hypothesis> hypotheses);

  Future<Hypothesis> getById(String id);

  Future<List<Hypothesis>> getByInvestigationId(String investigationId);

  Future<Hypothesis> updateReviewStatus({
    required String hypothesisId,
    required HypothesisStatus status,
    required DateTime reviewedAt,
  });

  Future<Hypothesis> addMitreAttackReference({
    required String hypothesisId,
    required MitreAttackReference reference,
  });

  Future<Hypothesis> removeProposedMitreAttackReference({
    required String hypothesisId,
    required String techniqueId,
  });

  Future<Hypothesis> applyVerifiedMitreAttackReference({
    required String hypothesisId,
    required MitreAttackReference reference,
  });
}
