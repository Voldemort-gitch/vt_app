import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/services/supabase_service.dart';

class EmployeeHistoryScreen extends StatefulWidget {
  const EmployeeHistoryScreen({super.key});

  @override
  State<EmployeeHistoryScreen> createState() => _EmployeeHistoryScreenState();
}

class _EmployeeHistoryScreenState extends State<EmployeeHistoryScreen> {
  List<AttendanceModel> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    final records = await SupabaseService.getAttendanceHistory(
      employeeId: userId,
    );
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, EEEE');

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      Text('No attendance records yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
                      const SizedBox(height: 8),
                      Text('Your check-in history will appear here', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getStatusColor(record.status).withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                          ),
                          border: Border.all(color: _getStatusColor(record.status).withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(record.status).withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: _getStatusColor(record.status).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_getStatusIcon(record.status), color: _getStatusColor(record.status), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateFormat.format(record.attendanceDate),
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                  Text('In: ${_fmt(record.checkIn)}',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                  if (record.checkOut != null)
                                    Text('Out: ${_fmt(record.checkOut!)}',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(record.status).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _getStatusColor(record.status).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(record.status.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(record.status))),
                                ),
                                if (record.workingMinutes > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('${record.workingMinutes ~/ 60}h ${record.workingMinutes % 60}m',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),
                    );
                  },
                ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF10B981);
      case 'late': return Colors.orange;
      case 'absent': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present': return Icons.check_circle;
      case 'late': return Icons.warning;
      case 'absent': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }
}
