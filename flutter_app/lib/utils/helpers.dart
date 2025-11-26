import 'package:intl/intl.dart';
import 'constants.dart';

class Helpers {
  // Date/Time Formatting
  static String formatDate(DateTime date) {
    return DateFormat(AppConstants.dateFormat).format(date);
  }

  static String formatTime(DateTime time) {
    return DateFormat(AppConstants.timeFormat).format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat(AppConstants.dateTimeFormat).format(dateTime);
  }

  // Calculate minutes between two times
  static int minutesBetween(DateTime start, DateTime end) {
    return end.difference(start).inMinutes;
  }

  // Calculate hours between two times
  static double hoursBetween(DateTime start, DateTime end) {
    return minutesBetween(start, end) / 60.0;
  }

  // Get week boundaries (Sunday to Saturday)
  static Map<String, DateTime> getWeekBoundaries(DateTime date) {
    final int daysFromSunday = date.weekday % 7; // Sunday = 0
    final DateTime weekStart = DateTime(
      date.year,
      date.month,
      date.day - daysFromSunday,
    );
    final DateTime weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    return {
      'start': weekStart,
      'end': weekEnd,
    };
  }

  // Calculate break utilization percentage
  static double calculateBreakUtilization(int actualMinutes, int entitledMinutes) {
    if (entitledMinutes == 0) return 0.0;
    return (actualMinutes / entitledMinutes) * 100.0;
  }

  // Validate email
  static bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Validate phone number (simple)
  static bool isValidPhone(String phone) {
    final RegExp phoneRegex = RegExp(r'^\d{10,}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[^\d]'), ''));
  }

  // Generate week ID for collections
  static String generateWeekId(String userId, DateTime date) {
    final weekBounds = getWeekBoundaries(date);
    final year = weekBounds['start']!.year;
    final weekNumber = ((weekBounds['start']!.difference(
      DateTime(year, 1, 1)
    ).inDays) / 7).ceil();

    return '${userId}_${year}_W${weekNumber.toString().padLeft(2, '0')}';
  }
}
