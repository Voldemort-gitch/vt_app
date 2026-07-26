import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/leave_request_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/services/supabase_service.dart';

class AdminLeaveApprovalScreen extends ConsumerStatefulWidget {
  const AdminLeaveApprovalScreen({super.key});

  @override
  ConsumerState<AdminLeaveApprovalScreen> createState() => _AdminLeaveApprovalScreenState();
}

class _AdminLeaveApprovalScreenState extends ConsumerState<AdminLeaveApprovalScreen> {
  List<LeaveRequestModel> _requests = [];
  List<ProfileModel> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final requests = await SupabaseService.getAllLeaveRequests();
    final employees = await SupabaseService.getAllEmployees();
    if (mounted) setState(() { _requests = requests; _employees = employees; _isLoading = false; });
  }

  String _getEmployeeName(String employeeId) {
    final emp = _employees.where((e) => e.id == employeeId).firstOrNull;
    return emp?.name ?? 'Unknown';
  }

  Future<void> _updateStatus(int leaveId, String status, LeaveRequestModel req) async {
    final adminId = SupabaseService.currentUserId;
    if (adminId == null) return;
    if (status == 'approved') {
      final hasExisting = await SupabaseService.hasApprovedLeaveInMonth(
        month: req.fromDate.month, year: req.fromDate.year,
        excludeEmployeeId: req.employeeId,
      );
      if (hasExisting) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Another employee already has approved leave this month. Only one employee per month allowed.'),
            backgroundColor: Color(0xFFDC2626),
          ));
        }
        return;
      }
    }
    await SupabaseService.updateLeaveStatus(leaveId: leaveId, status: status, adminId: adminId);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      Text('No leave requests', style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
                      const SizedBox(height: 8),
                      Text('Pending leave requests will appear here', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getEmployeeName(req.employeeId)[0].toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_getEmployeeName(req.employeeId), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                          Text(
                                            '${DateFormat('dd MMM').format(req.fromDate)} - ${DateFormat('dd MMM yyyy').format(req.toDate)}',
                                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(req.reason, style: TextStyle(color: Colors.grey.shade300, fontSize: 14)),
                                const SizedBox(height: 16),
                                if (req.isPending)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          onPressed: () => _updateStatus(req.id, 'rejected', req),
                                          child: const Text('Reject'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                                          onPressed: () => _updateStatus(req.id, 'approved', req),
                                          child: const Text('Approve'),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(req.status).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      req.status.toUpperCase(),
                                      style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(req.status)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFF3B82F6);
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }
}
