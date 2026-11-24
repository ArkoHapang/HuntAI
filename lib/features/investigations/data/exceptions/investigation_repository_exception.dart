abstract class InvestigationRepositoryException implements Exception {
  const InvestigationRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class DuplicateRecordException extends InvestigationRepositoryException {
  const DuplicateRecordException({
    required String recordType,
    required String recordId,
  }) : super('$recordType "$recordId" already exists.');
}

class RecordNotFoundException extends InvestigationRepositoryException {
  const RecordNotFoundException({
    required String recordType,
    required String recordId,
  }) : super('$recordType "$recordId" was not found.');
}

class InvalidRelationshipException extends InvestigationRepositoryException {
  const InvalidRelationshipException(super.message);
}

class UnsafeDeletionException extends InvestigationRepositoryException {
  const UnsafeDeletionException(super.message);
}

class InvalidUpdateException extends InvestigationRepositoryException {
  const InvalidUpdateException(super.message);
}

class InconsistentRepositoryStateException
    extends InvestigationRepositoryException {
  const InconsistentRepositoryStateException(super.message);
}
