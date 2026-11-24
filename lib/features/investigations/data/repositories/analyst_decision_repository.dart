import '../../domain/models/analyst_decision.dart';
import '../../domain/models/hypothesis.dart';

abstract interface class AnalystDecisionRepository {
  /// Appends a decision; no update or delete operation is exposed.
  Future<void> append(AnalystDecision decision);

  /// Atomically appends a decision and stores its matching reviewed hypothesis.
  ///
  /// Implementations must not report success unless both records are committed.
  Future<void> appendReview({
    required AnalystDecision decision,
    required Hypothesis updatedHypothesis,
  });

  Future<List<AnalystDecision>> getHistoryForHypothesis(String hypothesisId);

  Future<List<AnalystDecision>> getHistoryForInvestigation(
    String investigationId,
  );

  /// Returns the last appended decision, or null when no decision exists.
  Future<AnalystDecision?> getLatestForHypothesis(String hypothesisId);
}
