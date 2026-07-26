import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/company_settings_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/attendance_helper.dart';

class AttendanceState {
  final AttendanceModel? todayAttendance;
  final CompanySettingsModel? settings;
  final bool isLoading;
  final bool isProcessing;
  final String? error;
  final String? successMessage;

  AttendanceState({
    this.todayAttendance,
    this.settings,
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.successMessage,
  });

  AttendanceState copyWith({
    AttendanceModel? todayAttendance,
    CompanySettingsModel? settings,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    String? successMessage,
  }) {
    return AttendanceState(
      todayAttendance: todayAttendance ?? this.todayAttendance,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      successMessage: successMessage,
    );
  }

  bool get hasCheckedIn => todayAttendance?.hasCheckedIn ?? false;
  bool get hasCheckedOut => todayAttendance?.hasCheckedOut ?? false;
  bool get isDoneToday => todayAttendance?.isDoneToday ?? false;
}

class AttendanceNotifier extends Notifier<AttendanceState> {
  @override
  AttendanceState build() {
    return AttendanceState(isLoading: true);
  }

  Future<void> loadTodayAttendance() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final attendance = await SupabaseService.getTodayAttendance(userId);
      final settings = await SupabaseService.getCompanySettings();

      state = state.copyWith(
        todayAttendance: attendance,
        settings: settings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Session expired. Please sign in again.',
      );
    }
  }

  Future<void> checkIn() async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Could not get location. Please enable GPS.',
        );
        return;
      }

      if (LocationService.isLocationSpoofed(position)) {
        state = state.copyWith(
          isProcessing: false,
          error: 'GPS spoofing detected. Check-in denied.',
        );
        return;
      }

      final settings = state.settings;
      if (settings == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Company settings not loaded.',
        );
        return;
      }

      // TODO: Re-enable geofencing in production
      // final isWithin = LocationService.isWithinRadius(
      //   userLat: position.latitude,
      //   userLng: position.longitude,
      //   officeLat: settings.officeLatitude,
      //   officeLng: settings.officeLongitude,
      //   allowedRadius: settings.allowedRadius,
      // );
      // if (!isWithin) {
      //   state = state.copyWith(
      //     isProcessing: false,
      //     error: 'You are not within the office premises.',
      //   );
      //   return;
      // }

      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'User not authenticated.',
        );
        return;
      }

      final status = AttendanceHelper.determineStatus(
        checkInTime: DateTime.now(),
        officeStartTime: settings.officeStartTime,
        lateAfterMinutes: settings.lateAfterMinutes,
      );

      await SupabaseService.checkIn(
        employeeId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
        status: status,
      );

      final attendance = await SupabaseService.getTodayAttendance(userId);
      state = state.copyWith(
        todayAttendance: attendance,
        isProcessing: false,
        successMessage: status == 'late' ? 'Checked in (Late)' : 'Checked in successfully!',
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Session expired. Please sign in again.',
      );
    }
  }

  Future<void> checkOut() async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Could not get location. Please enable GPS.',
        );
        return;
      }

      if (LocationService.isLocationSpoofed(position)) {
        state = state.copyWith(
          isProcessing: false,
          error: 'GPS spoofing detected. Check-out denied.',
        );
        return;
      }

      final settings = state.settings;
      if (settings == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Company settings not loaded.',
        );
        return;
      }

      // TODO: Re-enable geofencing in production
      // final isWithin = LocationService.isWithinRadius(
      //   userLat: position.latitude,
      //   userLng: position.longitude,
      //   officeLat: settings.officeLatitude,
      //   officeLng: settings.officeLongitude,
      //   allowedRadius: settings.allowedRadius,
      // );
      // if (!isWithin) {
      //   state = state.copyWith(
      //     isProcessing: false,
      //     error: 'You are not within the office premises.',
      //   );
      //   return;
      // }

      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'User not authenticated.',
        );
        return;
      }

      final checkInTime = state.todayAttendance?.checkIn;
      if (checkInTime == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'No check-in record found.',
        );
        return;
      }

      final workingMinutes = AttendanceHelper.calculateWorkingMinutes(
        checkIn: checkInTime,
        checkOut: DateTime.now(),
      );

      await SupabaseService.checkOut(
        employeeId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
        workingMinutes: workingMinutes,
      );

      // Recalculate status server-side to prevent client-side tampering
      if (settings != null) {
        final correctStatus = AttendanceHelper.determineStatus(
          checkInTime: checkInTime,
          officeStartTime: settings.officeStartTime,
          lateAfterMinutes: settings.lateAfterMinutes,
        );
        final today = DateTime.now().toIso8601String().split('T')[0];
        await SupabaseService.client
            .from('attendance')
            .update({'status': correctStatus})
            .eq('employee_id', userId)
            .eq('attendance_date', today);
      }

      final attendance = await SupabaseService.getTodayAttendance(userId);
      state = state.copyWith(
        todayAttendance: attendance,
        isProcessing: false,
        successMessage: 'Checked out successfully! Working: ${AttendanceHelper.formatWorkingHours(workingMinutes)}',
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Session expired. Please sign in again.',
      );
    }
  }

  Future<void> autoCheckOut() async {
    state = state.copyWith(isProcessing: true);
    try {
      final checkInTime = state.todayAttendance?.checkIn;
      if (checkInTime == null) return;

      final uid = SupabaseService.currentUserId;
      if (uid == null) {
        state = state.copyWith(isProcessing: false, error: 'Session expired');
        return;
      }

      final workingMinutes = AttendanceHelper.calculateWorkingMinutes(
        checkIn: checkInTime,
        checkOut: DateTime.now(),
      );

      final today = DateTime.now().toIso8601String().split('T')[0];
      await SupabaseService.client
          .from('attendance')
          .update({
            'check_out': DateTime.now().toIso8601String(),
            'working_minutes': workingMinutes,
            'remarks': 'Auto check-out',
          })
          .eq('employee_id', uid)
          .eq('attendance_date', today);

      final attendance = await SupabaseService.getTodayAttendance(uid);
      state = state.copyWith(
        todayAttendance: attendance,
        isProcessing: false,
        successMessage: 'Auto checked out',
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: 'Auto check-out failed');
    }
  }

  void clearMessages() {
    state = state.copyWith();
  }
}

final attendanceStateProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(
  AttendanceNotifier.new,
);
