import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/models/payroll_record_model.dart';
import '../../../shared/services/supabase_service.dart';

class PayrollState {
  final List<PayrollRecordModel> records;
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final int? generatedCount;

  PayrollState({
    this.records = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.generatedCount,
  });
}

class PayrollNotifier extends Notifier<PayrollState> {
  @override
  PayrollState build() => PayrollState();

  Future<void> loadPayroll(int month, int year) async {
    state = PayrollState(isLoading: true);
    try {
      final records = await SupabaseService.getPayrollRecords(month, year);
      state = PayrollState(records: records);
    } catch (e) {
      logPayroll.warning('Failed to load payroll', e);
      state = PayrollState(error: 'Failed to load payroll');
    }
  }

  Future<void> generatePayroll(int month, int year) async {
    state = PayrollState(isLoading: true);
    try {
      final result = await SupabaseService.generatePayroll(month, year);
      if (result['success'] == true) {
        state = PayrollState(
          successMessage: 'Generated ${result['generated']} payroll records',
          generatedCount: result['generated'] as int?,
        );
        await loadPayroll(month, year);
      } else {
        state = PayrollState(error: result['error']?.toString() ?? 'Generation failed');
      }
    } catch (e) {
      logPayroll.severe('Payroll generation failed', e);
      state = PayrollState(error: 'Failed to generate payroll');
    }
  }

  Future<void> updateStatus(String recordId, String status) async {
    try {
      await SupabaseService.updatePayrollStatus(recordId, status);
      state = PayrollState(
        records: state.records.map((r) {
          if (r.id == recordId) {
            return PayrollRecordModel(
              id: r.id, employeeId: r.employeeId,
              month: r.month, year: r.year,
              basicSalary: r.basicSalary, dailySalary: r.dailySalary,
              allowedLeave: r.allowedLeave, usedLeave: r.usedLeave,
              extraLeave: r.extraLeave, deductionAmount: r.deductionAmount,
              advanceAmount: r.advanceAmount, grossSalary: r.grossSalary,
              finalSalary: r.finalSalary, status: status,
              generatedBy: r.generatedBy, createdAt: r.createdAt,
            );
          }
          return r;
        }).toList(),
        successMessage: 'Payroll $status successfully',
      );
    } catch (e) {
      logPayroll.warning('Payroll status update failed', e);
      state = PayrollState(error: 'Failed to update status', records: state.records);
    }
  }

  void clearMessages() {
    state = PayrollState(records: state.records);
  }
}

final payrollStateProvider = NotifierProvider<PayrollNotifier, PayrollState>(PayrollNotifier.new);
