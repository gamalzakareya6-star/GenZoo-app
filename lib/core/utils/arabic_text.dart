/// Normalizes Arabic text for searching: removes diacritics and tatweel,
/// unifies alef forms, ya/alef-maqsura and ta-marbuta/ha, and drops
/// punctuation.
String normalizeArabic(String input) {
  var s = input.toLowerCase();
  s = s.replaceAll(RegExp(r'[ً-ٰٟـ]'), '');
  s = s.replaceAll(RegExp(r'[آأإٱ]'), 'ا');
  s = s.replaceAll('ى', 'ي').replaceAll('ة', 'ه');
  s = s.replaceAll(RegExp(r'[^ء-ي0-9a-z\s]'), ' ');
  return s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ');
}

/// Converts Arabic-Indic digits (and the Arabic decimal separator) to Latin
/// so numbers typed on an Arabic keyboard can be parsed.
String toLatinDigits(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final ch in input.split('')) {
    final i = arabic.indexOf(ch);
    if (i >= 0) {
      buffer.write(i);
    } else if (ch == '٫' || ch == '،') {
      buffer.write('.');
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// Parses a number typed by the user; returns null when it is not valid.
double? parseNumber(String input) {
  final cleaned = toLatinDigits(input).trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// 3.0 -> "3", 2.5 -> "2.5"
String formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}
