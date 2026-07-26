import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/leave_request_model.dart';
import '../../../shared/services/supabase_service.dart';

class EmployeeLeaveRequestScreen extends StatefulWidget {
  const EmployeeLeaveRequestScreen({super.key});

  @override
  State<EmployeeLeaveRequestScreen> createState() => _EmployeeLeaveRequestScreenState();
}

class _EmployeeLeaveRequestScreenState extends State<EmployeeLeaveRequestScreen> {
  List<LeaveRequestModel> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final requests = await SupabaseService.getMyLeaveRequests(userId);
    if (mounted) setState(() { _requests = requests; _isLoading = false; });
  }

  void _showSubmitDialog() {
    DateTime? fromDate;
    DateTime? toDate;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Submit Leave Request', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF3B82F6)),
                  title: Text(fromDate != null ? DateFormat('dd MMM yyyy').format(fromDate!) : 'From Date', style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => fromDate = picked);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF3B82F6)),
                  title: Text(toDate != null ? DateFormat('dd MMM yyyy').format(toDate!) : 'To Date', style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fromDate ?? DateTime.now(),
                      firstDate: fromDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => toDate = picked);
                  },
                ),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (fromDate == null || toDate == null || reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  return;
                }
                final userId = SupabaseService.currentUserId;
                if (userId == null) return;
                final month = fromDate!.month;
                final year = fromDate!.year;
                final hasExisting = await SupabaseService.hasApprovedLeaveInMonth(
                  month: month, year: year, excludeEmployeeId: userId,
                );
                if (hasExisting) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Another employee already has approved leave this month. Only one employee per month allowed.'),
                      backgroundColor: Color(0xFFDC2626),
                    ));
                  }
                  return;
                }
                await SupabaseService.submitLeaveRequest(
                  employeeId: userId, fromDate: fromDate!, toDate: toDate!, reason: reasonController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
                _loadRequests();
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        onPressed: _showSubmitDialog,
        child: const Icon(Icons.add),
      ),
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
                      Text('Tap + to submit a leave request', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(req.status).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_getStatusIcon(req.status), color: _getStatusColor(req.status), size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${DateFormat('dd MMM').format(req.fromDate)} - ${DateFormat('dd MMM').format(req.toDate)}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(req.reason, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(req.status).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    req.status.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(req.status)),
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      default: return Icons.schedule;
    }
  }
}
