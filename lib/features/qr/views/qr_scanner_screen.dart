import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/qr_provider.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../../core/utils/toast_helper.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  MobileScannerController? _scannerController;
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _hasScanned = true;
    HapticFeedback.vibrate();
    ref.read(qrScanProvider.notifier).processScan(barcode.rawValue!);
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(qrScanProvider);

    ref.listen<QrScanState>(qrScanProvider, (prev, next) {
      if (next.successMessage != null) {
        ref.read(attendanceStateProvider.notifier).loadTodayAttendance();
        ToastHelper.show(context, next.successMessage!);
        context.pop();
      }
      if (next.error != null && next.error != prev?.error) {
        ToastHelper.show(context, next.error!, isError: true);
        _hasScanned = false;
        ref.read(qrScanProvider.notifier).reset();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR to Check In'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () {
              _scannerController?.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController ??
                MobileScannerController(
                  detectionSpeed: DetectionSpeed.noDuplicates,
                ),
            onDetect: _onDetect,
          ),
          if (scanState.isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF3B82F6),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Verifying...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
                          Positioned(
                            bottom: 80,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.qr_code_scanner, size: 20, color: Colors.white.withValues(alpha: 0.6)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Align QR code within the frame',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
        ],
      ),
    );
  }
}
