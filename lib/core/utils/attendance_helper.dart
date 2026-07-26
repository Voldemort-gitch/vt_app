class AttendanceHelper {
  AttendanceHelper._();

  static bool checkIfLate({
    required DateTime checkInTime,
    required String officeStartTime,
    required int lateAfterMinutes,
  }) {
    final parts = officeStartTime.split(':');
    final int startHour = int.parse(parts[0]);
    final int startMinute = int.parse(parts[1]);

    final DateTime threshold = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      startHour,
      startMinute + lateAfterMinutes,
    );

    return checkInTime.isAfter(threshold);
  }

  static int calculateWorkingMinutes({
    required DateTime checkIn,
    required DateTime checkOut,
  }) {
    return checkOut.difference(checkIn).inMinutes;
  }

  static String determineStatus({
    required DateTime checkInTime,
    required String officeStartTime,
    required int lateAfterMinutes,
  }) {
    if (checkIfLate(
      checkInTime: checkInTime,
      officeStartTime: officeStartTime,
      lateAfterMinutes: lateAfterMinutes,
    )) {
      return 'late';
    }
    return 'present';
  }

  static String formatWorkingHours(int minutes) {
    final int hours = minutes ~/ 60;
    final int mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}
