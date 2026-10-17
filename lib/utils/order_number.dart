/// Strips legacy `MMA-` prefixes from order numbers returned by the API.
String normalizeOrderNumber(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';

  const prefix = 'MMA-';
  if (value.length > prefix.length &&
      value.substring(0, prefix.length).toUpperCase() == prefix) {
    return value.substring(prefix.length);
  }

  return value;
}

String formatOrderDisplayNumber({
  required String orderNumber,
  required int id,
}) {
  final normalized = normalizeOrderNumber(orderNumber);
  return normalized.isNotEmpty ? '#$normalized' : 'Order #$id';
}
