import '../enums/investigation_enums.dart';
import 'model_validation.dart';

class AnalystNote {
  AnalystNote({
    required String id,
    required String authorId,
    required String text,
    required DateTime timestamp,
  })  : id = ModelValidation.requiredIdentifier(id, 'id'),
        authorId = ModelValidation.requiredIdentifier(authorId, 'authorId'),
        text = ModelValidation.requiredText(text, 'text'),
        timestamp = ModelValidation.utc(timestamp);

  final String id;
  final String authorId;
  final String text;
  final DateTime timestamp;
}

class Investigation {
  Investigation({
    required String id,
    required String title,
    required this.description,
    required this.status,
    required this.priority,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? assignedAnalystId,
    Iterable<String> relatedEntityIds = const [],
    Iterable<String> relatedConnectionIds = const [],
    Iterable<String> evidenceIds = const [],
    Iterable<String> hypothesisIds = const [],
    Iterable<AnalystNote> analystNotes = const [],
  })  : id = ModelValidation.requiredIdentifier(id, 'id'),
        title = ModelValidation.requiredText(title, 'title'),
        createdAt = ModelValidation.utc(createdAt),
        updatedAt = ModelValidation.utc(updatedAt),
        assignedAnalystId = ModelValidation.optionalIdentifier(
          assignedAnalystId,
          'assignedAnalystId',
        ),
        relatedEntityIds = ModelValidation.immutableUniqueIds(
          relatedEntityIds,
          'relatedEntityIds',
        ),
        relatedConnectionIds = ModelValidation.immutableUniqueIds(
          relatedConnectionIds,
          'relatedConnectionIds',
        ),
        evidenceIds =
            ModelValidation.immutableUniqueIds(evidenceIds, 'evidenceIds'),
        hypothesisIds =
            ModelValidation.immutableUniqueIds(hypothesisIds, 'hypothesisIds'),
        analystNotes = ModelValidation.immutableUniqueItems(
          analystNotes,
          'analystNotes',
          (note) => note.id,
        ) {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'must not be earlier than createdAt.',
      );
    }
  }

  final String id;
  final String title;
  final String description;
  final InvestigationStatus status;
  final InvestigationPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedAnalystId;
  final List<String> relatedEntityIds;
  final List<String> relatedConnectionIds;
  final List<String> evidenceIds;
  final List<String> hypothesisIds;
  final List<AnalystNote> analystNotes;
}
