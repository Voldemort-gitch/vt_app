import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart' as logging;

final logAuth = logging.Logger('auth');
final logAttendance = logging.Logger('attendance');
final logLeave = logging.Logger('leave');
final logAdvance = logging.Logger('advance');
final logPayroll = logging.Logger('payroll');
final logPayslip = logging.Logger('payslip');
final logProfile = logging.Logger('profile');
final logBiometric = logging.Logger('biometric');
final logNetwork = logging.Logger('network');
final logSystem = logging.Logger('system');

void initLogging() {
  logging.hierarchicalLoggingEnabled = true;
  logging.Logger.root.level = logging.Level.ALL;
  logging.Logger.root.onRecord.listen((record) {
    if (kReleaseMode && record.level.value < logging.Level.WARNING.value) return;
    // ignore: avoid_print
    print('${record.level.name} [${record.loggerName}] ${record.message}');
  });
}
