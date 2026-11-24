import '../../domain/enums/investigation_enums.dart';
import '../../domain/models/investigation.dart';

abstract interface class InvestigationRepository {
  Future<void> create(Investigation investigation);

  Future<Investigation> getById(String id);

  Future<List<Investigation>> getAll();

  Future<List<Investigation>> getByStatus(InvestigationStatus status);

  Future<List<Investigation>> getByPriority(InvestigationPriority priority);

  /// Updates metadata and may append references or notes, but cannot remove
  /// existing references or rewrite existing analyst notes.
  Future<Investigation> update(Investigation investigation);

  /// Deletes only when no evidence, hypotheses, or decisions remain.
  Future<void> deleteById(String id);
}
