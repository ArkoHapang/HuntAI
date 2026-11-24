import '../enums/investigation_enums.dart';
import 'model_validation.dart';

/// Immutable review event. A later decision should be appended, not overwrite it.
class AnalystDecision {
  AnalystDecision({
    required String id,
    required String investigationId,
    required String hypothesisId,
    required this.decision,
    required String rationale,
    required String analystId,
    required DateTime decidedAt,
  })  : id = ModelValidation.requiredIdentifier(id, 'id'),
        investigationId = ModelValidation.requiredIdentifier(
            investigationId, 'investigationId'),
        hypothesisId =
            ModelValidation.requiredIdentifier(hypothesisId, 'hypothesisId'),
        rationale = _meaningfulRationale(rationale),
        analystId = ModelValidation.requiredIdentifier(analystId, 'analystId'),
        decidedAt = ModelValidation.utc(decidedAt);

  final String id;
  final String investigationId;
  final String hypothesisId;
  final AnalystDecisionType decision;
  final String rationale;
  final String analystId;
  final DateTime decidedAt;

  static String _meaningfulRationale(String value) {
    final rationale = ModelValidation.requiredText(value, 'rationale');
    if (rationale.trim().length < 8) {
      throw ArgumentError.value(
        value,
        'rationale',
        'must contain at least 8 non-whitespace characters.',
      );
    }
    return rationale;
  }
}
