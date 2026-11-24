abstract final class ModelValidation {
  static String requiredIdentifier(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, 'must not be empty.');
    }
    return normalized;
  }

  static String requiredText(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, fieldName, 'must not be empty.');
    }
    return value;
  }

  static String? optionalIdentifier(String? value, String fieldName) {
    if (value == null) return null;
    return requiredIdentifier(value, fieldName);
  }

  static List<String> immutableUniqueIds(
    Iterable<String> values,
    String fieldName,
  ) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final id = requiredIdentifier(value, fieldName);
      if (!seen.add(id)) {
        throw ArgumentError.value(value, fieldName, 'must contain unique IDs.');
      }
      result.add(id);
    }
    return List<String>.unmodifiable(result);
  }

  static List<T> immutableUniqueItems<T>(
    Iterable<T> values,
    String fieldName,
    String Function(T) idOf,
  ) {
    final result = List<T>.of(values);
    final ids = <String>{};
    for (final item in result) {
      final id = requiredIdentifier(idOf(item), fieldName);
      if (!ids.add(id)) {
        throw ArgumentError.value(id, fieldName, 'must contain unique IDs.');
      }
    }
    return List<T>.unmodifiable(result);
  }

  static List<String> immutableRequiredTexts(
    Iterable<String> values,
    String fieldName,
  ) {
    final result = [
      for (final value in values) requiredText(value, fieldName),
    ];
    return List<String>.unmodifiable(result);
  }

  static DateTime utc(DateTime value) => value.toUtc();

  static Uri httpsUri(String value, String fieldName) {
    final normalized = requiredText(value, fieldName);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      throw ArgumentError.value(
        value,
        fieldName,
        'must be an absolute HTTPS URL.',
      );
    }
    return uri;
  }

  static void requireSubset(
    Iterable<String> references,
    Set<String> availableIds,
    String fieldName,
  ) {
    for (final reference in references) {
      if (!availableIds.contains(reference)) {
        throw ArgumentError.value(
          reference,
          fieldName,
          'does not refer to an available ID.',
        );
      }
    }
  }
}
