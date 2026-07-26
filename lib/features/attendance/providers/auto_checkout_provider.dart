import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_provider.dart';

class AutoCheckoutNotifier extends Notifier<void> {
  Timer? _timer;

  void start(AttendanceState state, String officeEndTime) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.hasCheckedIn && !state.hasCheckedOut) {
        final now = TimeOfDay.now();
        final parts = officeEndTime.split(':');
        final endHour = int.parse(parts[0]);
        final endMin = int.parse(parts[1]);

        if (now.hour > endHour || (now.hour == endHour && now.minute >= endMin)) {
          ref.read(attendanceStateProvider.notifier).autoCheckOut();
          _timer?.cancel();
        }
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void build() {}
}

final autoCheckoutProvider =
    NotifierProvider<AutoCheckoutNotifier, void>(AutoCheckoutNotifier.new);
