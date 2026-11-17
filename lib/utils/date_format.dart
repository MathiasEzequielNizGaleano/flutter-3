// Fechas en el formato corto que usa la app ("Hoy 09:12", "12 sep 14:02").

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "Hoy 09:12", "Ayer 18:30", "12 sep 14:02" o "12 sep 2025 14:02".
String formatEventTime(DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  final hm = '${_two(time.hour)}:${_two(time.minute)}';
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Hoy $hm';
  if (day == DateTime(now.year, now.month, now.day - 1)) return 'Ayer $hm';
  return '${formatShortDate(time, now: now)} $hm';
}

/// "12 sep" si es de este año, "12 sep 2025" si no.
String formatShortDate(DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  final date = '${time.day} ${_months[time.month - 1]}';
  return time.year == now.year ? date : '$date ${time.year}';
}

/// "14 mar 1998": fecha completa, siempre con el año.
String formatLongDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// Fecha sin hora guardada como texto "2018-05-20" (así no cambia de día
/// por la zona horaria).
String toIsoDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// Lee "2018-05-20". Devuelve `null` si el texto no es una fecha.
DateTime? parseIsoDate(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final date = DateTime(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
  // Rechaza fechas imposibles como 2023-02-31.
  return toIsoDate(date) == value ? date : null;
}

/// Años cumplidos a [now].
int ageOn(DateTime birth, {DateTime? now}) {
  now ??= DateTime.now();
  var age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age--;
  }
  return age;
}
