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
}
