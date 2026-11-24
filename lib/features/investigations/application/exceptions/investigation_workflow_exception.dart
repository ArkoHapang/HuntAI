abstract class InvestigationWorkflowException implements Exception {
  const InvestigationWorkflowException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class InvalidWorkflowInputException extends InvestigationWorkflowException {
  const InvalidWorkflowInputException(super.message);
}

class InvestigationClosedException extends InvestigationWorkflowException {
  const InvestigationClosedException(String investigationId)
      : super('Investigation "$investigationId" is closed and read-only.');
}

class InvalidLifecycleTransitionException
    extends InvestigationWorkflowException {
  const InvalidLifecycleTransitionException({
    required String from,
    required String to,
  }) : super('Investigation cannot transition from "$from" to "$to".');
}

class InvalidHypothesisTransitionException
    extends InvestigationWorkflowException {
  const InvalidHypothesisTransitionException({
    required String from,
    required String to,
  }) : super('Hypothesis cannot transition from "$from" to "$to".');
}

class DuplicateGraphAssociationException
    extends InvestigationWorkflowException {
  const DuplicateGraphAssociationException({
    required String graphType,
    required String graphId,
  }) : super('$graphType "$graphId" is already associated.');
}

class UnknownGraphReferenceException extends InvestigationWorkflowException {
  const UnknownGraphReferenceException({
    required String graphType,
    required String graphId,
  }) : super('$graphType "$graphId" is not present in the graph catalog.');
}
