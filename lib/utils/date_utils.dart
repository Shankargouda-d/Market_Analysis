import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Small helpers so date/time formatting is identical everywhere
/// (form fields, list tiles, Sheets payload).
class AppDateUtils {
  AppDateUtils._();

  static String formatDate(DateTime dt) => DateFormat('dd-MM-yyyy').format(dt);

  static String formatTime(DateTime dt) => DateFormat('hh:mm a').format(dt);

  static String formatDateTime(DateTime dt) =>
      '${formatDate(dt)}  ${formatTime(dt)}';

  /// Merges a date-only DateTime with a TimeOfDay into one DateTime.
  static DateTime combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Checks if two dates fall on the exact same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// True if the given date is today.
  static bool isToday(DateTime dt) => isSameDay(dt, DateTime.now());

  /// True if the given date was yesterday.
  static bool isYesterday(DateTime dt) =>
      isSameDay(dt, DateTime.now().subtract(const Duration(days: 1)));

  /// Formats date to YYYY-MM-DD.
  static String toIsoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Formats date to "05 Oct 2026".
  static String formatDisplayDate(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(dt);

  /// Formats date to "Monday, 05 Oct 2026".
  static String formatFullDate(DateTime dt) =>
      DateFormat('EEEE, dd MMM yyyy').format(dt);
}
