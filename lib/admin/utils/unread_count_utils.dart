import 'dart:collection';

/// Normalize an unread count field coming from Firestore into a
/// `Map<String, int>` with safe integer values.
///
/// The source value can be:
/// - `null`
/// - a primitive `num` applying to the default participant key
/// - a `Map` whose values are strings or numbers
/// - any other type, which will be treated as empty
///
/// All non-numeric entries are coerced to `0`. Negative values are clamped
/// to `0` as well to keep UI assumptions consistent.
Map<String, int> normalizeUnreadCount(dynamic raw, {String? defaultKey}) {
  if (raw == null) {
    return const {};
  }

  if (raw is Map) {
    final result = <String, int>{};
    raw.forEach((key, value) {
      final stringKey = '$key'.trim();
      if (stringKey.isEmpty) return;
      result[stringKey] = _coerceToNonNegativeInt(value);
    });
    return UnmodifiableMapView(result);
  }

  if (defaultKey != null && defaultKey.isNotEmpty) {
    return UnmodifiableMapView({defaultKey: _coerceToNonNegativeInt(raw)});
  }

  return const {};
}

int _coerceToNonNegativeInt(dynamic value) {
  if (value == null) return 0;

  if (value is int) {
    return value < 0 ? 0 : value;
  }

  if (value is num) {
    final coerced = value.toInt();
    return coerced < 0 ? 0 : coerced;
  }

  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 0) {
      return parsed;
    }
  }

  return 0;
}
