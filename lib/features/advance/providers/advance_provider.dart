import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/models/advance_request_model.dart';
import '../../../shared/services/supabase_service.dart';

class AdvanceState {
  final List<AdvanceRequestModel> requests;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  AdvanceState({this.requests = const [], this.isLoading = false, this.error, this.successMessage});
}

class AdvanceNotifier extends Notifier<AdvanceState> {
  @override
  AdvanceState build() {
    ref.keepAlive();
    return AdvanceState();
  }

  Future<void> loadMyRequests() async {
    state = AdvanceState(requests: state.requests, isLoading: true);
    try {
      final requests = await SupabaseService.getMyAdvanceRequests()
          .timeout(const Duration(seconds: 15));
      state = AdvanceState(requests: requests);
    } catch (_) {
      state = AdvanceState(requests: state.requests, error: 'Failed to load requests');
    }
  }

  Future<void> loadAllRequests() async {
    state = AdvanceState(requests: state.requests, isLoading: true);
    try {
      final requests = await SupabaseService.getAllAdvanceRequests()
          .timeout(const Duration(seconds: 15));
      state = AdvanceState(requests: requests);
    } catch (_) {
      state = AdvanceState(requests: state.requests, error: 'Failed to load requests');
    }
  }

  Future<void> submitRequest(double amount, String reason, int month, int year) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      await SupabaseService.submitAdvanceRequest(
        employeeId: userId, amount: amount, reason: reason, month: month, year: year,
      );
      state = AdvanceState(requests: state.requests, successMessage: 'Advance requested');
      await loadMyRequests();
    } catch (e) {
      logAdvance.severe('Failed to submit advance', e);
      state = AdvanceState(error: 'Failed to submit request');
    }
  }

  Future<void> updateStatus(String id, String status) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      await SupabaseService.updateAdvanceStatus(id, status, userId);
      await loadAllRequests();
    } catch (e) { logAdvance.warning('Update status failed', e); }
  }
}

final advanceStateProvider = NotifierProvider<AdvanceNotifier, AdvanceState>(AdvanceNotifier.new);
