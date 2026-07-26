import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/attendance_helper.dart';

class QrResult {
  final String companyId;
  final double lat;
  final double lng;

  QrResult({
    required this.companyId,
    required this.lat,
    required this.lng,
  });

  static QrResult? fromJson(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return QrResult(
        companyId: data['co'] as String,
        lat: (data['la'] as num).toDouble(),
        lng: (data['lo'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

class QrScanState {
  final bool isScanning;
  final bool isProcessing;
  final String? error;
  final String? successMessage;
  final bool cameraReady;

  QrScanState({
    this.isScanning = false,
    this.isProcessing = false,
    this.error,
    this.successMessage,
    this.cameraReady = false,
  });
}

class QrScanNotifier extends Notifier<QrScanState> {
  @override
  QrScanState build() {
    return QrScanState();
  }

  Future<String?> processScan(String qrData) async {
    state = QrScanState(isScanning: true, isProcessing: true);

    final qr = QrResult.fromJson(qrData);
    if (qr == null) {
      state = QrScanState(error: 'Invalid QR code format');
      return null;
    }

    final settings = await SupabaseService.getCompanySettings();
    if (qr.companyId != 'vt_office') {
      state = QrScanState(error: 'This QR code is not for this office');
      return null;
    }

    state = QrScanState(isScanning: true, isProcessing: true);

    final position = await LocationService.getCurrentLocation();
    if (position == null) {
      state = QrScanState(error: 'Could not get GPS location');
      return null;
    }

    if (LocationService.isLocationSpoofed(position)) {
      state = QrScanState(error: 'GPS spoofing detected. Check-in denied.');
      return null;
    }

    final coordsConfigured =
        settings.officeLatitude != 0.0 || settings.officeLongitude != 0.0;
    if (coordsConfigured) {
      final isWithin = LocationService.isWithinRadius(
        userLat: position.latitude,
        userLng: position.longitude,
        officeLat: settings.officeLatitude,
        officeLng: settings.officeLongitude,
        allowedRadius: settings.allowedRadius,
      );
      if (!isWithin) {
        state = QrScanState(
          error: 'Not at office location. Please scan the QR at the office.',
        );
        return null;
      }
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      state = QrScanState(error: 'User not authenticated');
      return null;
    }

    final status = AttendanceHelper.determineStatus(
      checkInTime: DateTime.now(),
      officeStartTime: settings.officeStartTime,
      lateAfterMinutes: settings.lateAfterMinutes,
    );

    try {
      await SupabaseService.checkIn(
        employeeId: userId,
        latitude: qr.lat,
        longitude: qr.lng,
        status: status,
      );
      state = QrScanState(
        successMessage: status == 'late'
            ? 'Checked in (Late)'
            : 'Checked in successfully!',
      );
      return status;
    } catch (e) {
      state = QrScanState(error: 'Check-in failed. Please try again.');
      return null;
    }
  }

  void reset() {
    state = QrScanState();
  }
}

final qrScanProvider =
    NotifierProvider<QrScanNotifier, QrScanState>(QrScanNotifier.new);
