import '../../domain/models/evidence.dart';

abstract interface class EvidenceRepository {
  Future<void> add(Evidence evidence);

  Future<Evidence> getById(String id);

  Future<List<Evidence>> getByInvestigationId(String investigationId);

  Future<List<Evidence>> getAllForInvestigation(String investigationId);
}
