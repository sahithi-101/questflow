// Small date helpers so Phase 1 needs no extra packages.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'
];

String weekdayLong(DateTime d) => _weekdays[d.weekday - 1];
String weekdayShort(DateTime d) => weekdayLong(d).substring(0, 3);
String monthLong(int month) => _months[month - 1];
String monthShort(int month) => _months[month - 1].substring(0, 3);

/// 12-hour clock, e.g. "4:30 pm".
String clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'am' : 'pm'}';
}

/// "Today", "Tomorrow", "Yesterday" or "Thu 29 Oct".
String dayLabel(DateTime d, DateTime now) {
  final diff = dateOnly(d).difference(dateOnly(now)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${weekdayShort(d)} ${d.day} ${monthShort(d.month)}';
}

/// "1–8 Oct 2026", "28 Sep – 4 Oct 2026" or "30 Dec 2026 – 2 Jan 2027".
String dateRangeLabel(DateTime a, DateTime b) {
  final s = '${a.day} ${monthShort(a.month)}';
  final e = '${b.day} ${monthShort(b.month)}';
  if (a.year == b.year) {
    return a.month == b.month ? '$s – $e ${a.year}' : '$s – $e ${a.year}';
  }
  return '$s ${a.year} – $e ${b.year}';
}
