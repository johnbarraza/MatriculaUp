// matriculaup_app/lib/utils/time_utils.dart

class TimeUtils {
  /// Converts a time string "HH:MM" to minutes since midnight.
  static int timeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;

    List<String> parts = timeStr.split(':');
    if (parts.length != 2) return 0;

    int hours = int.tryParse(parts[0]) ?? 0;
    int minutes = int.tryParse(parts[1]) ?? 0;
    return (hours * 60) + minutes;
  }

  /// Calculates the duration in minutes between two "HH:MM" strings.
  static int durationMinutes(String startStr, String endStr) {
    return timeToMinutes(endStr) - timeToMinutes(startStr);
  }

  /// Checks if two time intervals overlap.
  /// Overlap means one starts strictly before the other ends, and vice versa.
  static bool hasOverlap(
    String startA,
    String endA,
    String startB,
    String endB,
  ) {
    int sA = timeToMinutes(startA);
    int eA = timeToMinutes(endA);
    int sB = timeToMinutes(startB);
    int eB = timeToMinutes(endB);

    return sA < eB && sB < eA;
  }
}
