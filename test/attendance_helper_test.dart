import 'package:flutter_test/flutter_test.dart';
import 'package:vt_app/core/utils/attendance_helper.dart';

void main() {
  group('AttendanceHelper.checkIfLate', () {
    test('returns false when check-in is before late threshold', () {
      final checkIn = DateTime(2026, 7, 21, 9, 5);
      final result = AttendanceHelper.checkIfLate(
        checkInTime: checkIn,
        officeStartTime: '09:00',
        lateAfterMinutes: 15,
      );
      expect(result, false);
    });

    test('returns true when check-in is exactly at late threshold', () {
      final checkIn = DateTime(2026, 7, 21, 9, 16);
      final result = AttendanceHelper.checkIfLate(
        checkInTime: checkIn,
        officeStartTime: '09:00',
        lateAfterMinutes: 15,
      );
      expect(result, true);
    });

    test('returns true when check-in is after late threshold', () {
      final checkIn = DateTime(2026, 7, 21, 10, 0);
      final result = AttendanceHelper.checkIfLate(
        checkInTime: checkIn,
        officeStartTime: '09:00',
        lateAfterMinutes: 15,
      );
      expect(result, true);
    });

    test('returns false when check-in is exactly at start time', () {
      final checkIn = DateTime(2026, 7, 21, 9, 0);
      final result = AttendanceHelper.checkIfLate(
        checkInTime: checkIn,
        officeStartTime: '09:00',
        lateAfterMinutes: 15,
      );
      expect(result, false);
    });

    test('returns false when lateAfterMinutes is 0 and on time', () {
      final checkIn = DateTime(2026, 7, 21, 9, 0);
      final result = AttendanceHelper.checkIfLate(
        checkInTime: checkIn,
        officeStartTime: '09:00',
        lateAfterMinutes: 0,
      );
      expect(result, false);
    });
  });

  group('AttendanceHelper.calculateWorkingMinutes', () {
    test('calculates 8 hours correctly', () {
      final checkIn = DateTime(2026, 7, 21, 9, 0);
      final checkOut = DateTime(2026, 7, 21, 17, 0);
      final result = AttendanceHelper.calculateWorkingMinutes(
        checkIn: checkIn,
        checkOut: checkOut,
      );
      expect(result, 480);
    });

    test('calculates 4 hours 30 minutes correctly', () {
      final checkIn = DateTime(2026, 7, 21, 9, 0);
      final checkOut = DateTime(2026, 7, 21, 13, 30);
      final result = AttendanceHelper.calculateWorkingMinutes(
        checkIn: checkIn,
        checkOut: checkOut,
      );
      expect(result, 270);
    });

    test('returns 0 when check-in and check-out are same time', () {
      final time = DateTime(2026, 7, 21, 9, 0);
      final result = AttendanceHelper.calculateWorkingMinutes(
        checkIn: time,
        checkOut: time,
      );
      expect(result, 0);
    });

    test('handles cross-midnight correctly', () {
      final checkIn = DateTime(2026, 7, 21, 22, 0);
      final checkOut = DateTime(2026, 7, 22, 6, 0);
      final result = AttendanceHelper.calculateWorkingMinutes(
        checkIn: checkIn,
        checkOut: checkOut,
      );
      expect(result, 480);
    });
  });

  group('AttendanceHelper.formatWorkingHours', () {
    test('formats 0 minutes', () {
      expect(AttendanceHelper.formatWorkingHours(0), '0h 0m');
    });

    test('formats 60 minutes', () {
      expect(AttendanceHelper.formatWorkingHours(60), '1h 0m');
    });

    test('formats 90 minutes', () {
      expect(AttendanceHelper.formatWorkingHours(90), '1h 30m');
    });

    test('formats 480 minutes', () {
      expect(AttendanceHelper.formatWorkingHours(480), '8h 0m');
    });
  });

  group('AttendanceHelper.determineStatus', () {
    test('returns present when on time', () {
      final checkIn = DateTime(2026, 7, 21, 9, 0);
      final result = AttendanceHelper.determineStatus(
        checkInTime: checkIn,
        officeStartTime: '09:00',
        lateAfterMinutes: 15,
      );
      expect(result, 'present');
    });

    test('returns late when after threshold', () {
      final checkIn = DateTime(2026, 7, 21, 9, 20);
      final result = AttendanceHelper.determineStatus(
        checkInTime: checkIn,
        officeStartTime: '09:00',
        lateAfterMinutes: 15,
      );
      expect(result, 'late');
    });
  });
}
