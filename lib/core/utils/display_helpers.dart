/// Turns a date into the format used by the database: 2026-10-09.
String formatDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Turns a date into a friendly heading such as 9th October 2026.
String formatFriendlyDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final suffix = _ordinalSuffix(date.day);
  return '${date.day}$suffix ${months[date.month - 1]} ${date.year}';
}

/// Formats a clock time using either 24-hour or 12-hour display.
String formatClockTime(DateTime time, {required bool use24Hour}) {
  final minute = time.minute.toString().padLeft(2, '0');
  if (use24Hour) {
    final hour = time.hour.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final period = time.hour < 12 ? 'am' : 'pm';
  return '$hour:$minute $period';
}

/// Returns the emoji used for a saved mood, or null for no mood.
String? moodEmoji(String mood) {
  const emojis = {
    'Great': '😄',
    'Happy': '😊',
    'Calm': '😌',
    'Tired': '😴',
    'Sad': '😔',
    'Stressed': '😣',
  };
  return emojis[mood];
}

String _ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  if (day % 10 == 1) return 'st';
  if (day % 10 == 2) return 'nd';
  if (day % 10 == 3) return 'rd';
  return 'th';
}
