import '../enums/investigation_enums.dart';

abstract final class HypothesisStatusTransitionPolicy {
  static const Map<HypothesisStatus, Set<HypothesisStatus>> _allowed = {
    HypothesisStatus.candidate: {HypothesisStatus.underReview},
    HypothesisStatus.underReview: {
      HypothesisStatus.acceptedForInvestigation,
      HypothesisStatus.rejected,
      HypothesisStatus.deferred,
      HypothesisStatus.inconclusive,
      HypothesisStatus.superseded,
    },
    HypothesisStatus.deferred: {HypothesisStatus.underReview},
    HypothesisStatus.acceptedForInvestigation: {
      HypothesisStatus.underReview,
      HypothesisStatus.superseded,
    },
    HypothesisStatus.rejected: {
      HypothesisStatus.underReview,
      HypothesisStatus.superseded,
    },
    HypothesisStatus.inconclusive: {
      HypothesisStatus.underReview,
      HypothesisStatus.superseded,
    },
    HypothesisStatus.superseded: {},
  };

  static bool allows(HypothesisStatus from, HypothesisStatus to) =>
      _allowed[from]!.contains(to);

  static HypothesisStatus statusForDecision(AnalystDecisionType decision) =>
      switch (decision) {
        AnalystDecisionType.accept => HypothesisStatus.acceptedForInvestigation,
        AnalystDecisionType.reject => HypothesisStatus.rejected,
        AnalystDecisionType.defer => HypothesisStatus.deferred,
        AnalystDecisionType.inconclusive => HypothesisStatus.inconclusive,
      };
}
