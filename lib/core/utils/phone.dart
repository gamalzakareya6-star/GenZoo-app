/// Egyptian mobile numbers: 01[0125]xxxxxxxx, with or without +20 / 0020.
String normalizePhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  d = _arabicDigits(d);
  if (d.startsWith('+20')) d = '0${d.substring(3)}';
  if (d.startsWith('0020')) d = '0${d.substring(4)}';
  if (d.startsWith('20') && d.length == 12) d = '0${d.substring(2)}';
  return d;
}

String _arabicDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = ar.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

bool isValidPhone(String raw) => RegExp(r'^01[0125]\d{8}$').hasMatch(normalizePhone(raw));

/// "+20" international form for WhatsApp links.
String intlPhone(String raw) {
  final n = normalizePhone(raw);
  return n.startsWith('0') ? '20${n.substring(1)}' : n;
}
