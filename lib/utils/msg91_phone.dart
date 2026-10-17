/// Normalizes phone input for MSG91 (digits only, country code + number).
String toMsg91Mobile(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  if (digits.startsWith('0') && digits.length >= 11) {
    digits = digits.substring(1);
  }

  for (final cc in ['91', '92', '971', '44', '1']) {
    final dup = '$cc$cc';
    while (digits.startsWith(dup) && digits.length > cc.length + 8) {
      digits = cc + digits.substring(cc.length);
    }
  }

  return digits;
}

/// E.164 display form (`+` + digits).
String toDisplayE164(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return '+$digits';
}
