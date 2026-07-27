import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/logger.dart';

class QrResult {
  final String companyId;

  QrResult({required this.companyId});

  static QrResult? fromJson(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final co = data['co'] as String?;
      if (co == null) return null;
      return QrResult(companyId: co);
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

    final position = await LocationService.getCurrentLocation();
    if (position == null) {
      state = QrScanState(error: 'Could not get GPS location');
      return null;
    }

    if (LocationService.isLocationSpoofed(position)) {
      state = QrScanState(error: 'GPS spoofing detected. Check-in denied.');
      return null;
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      state = QrScanState(error: 'User not authenticated');
      return null;
    }

    try {
      final result = await SupabaseService.checkIn(
        employeeId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
        companyId: qr.companyId,
      );

      if (result['success'] != true) {
        state = QrScanState(error: result['error']?.toString() ?? 'Check-in failed.');
        return null;
      }

      final msg = result['message'] as String? ?? 'Checked in successfully!';
      state = QrScanState(successMessage: msg);
      return result['status'] as String? ?? 'present';
    } catch (e) {
      logAttendance.warning('QR check-in failed', e);
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
