import 'package:intl/intl.dart';

/// Formats an ISO 8601 date string to "MMM d, yyyy" (e.g. "Jan 5, 2025").
/// Returns empty string on null/invalid input.
String formatIsoDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';
  try {
    return DateFormat('MMM d, yyyy').format(DateTime.parse(isoDate));
  } catch (_) {
    return '';
  }
}

/// Formats a DateTime to a chat date separator label.
/// Returns "Today", "Yesterday", or "MMM d" as appropriate.
String formatChatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMM d').format(date);
}
