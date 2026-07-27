import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/leave_request_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/services/supabase_service.dart';

class AdminLeaveCalendarScreen extends ConsumerStatefulWidget {
  const AdminLeaveCalendarScreen({super.key});

  @override
  ConsumerState<AdminLeaveCalendarScreen> createState() => _AdminLeaveCalendarScreenState();
}

class _AdminLeaveCalendarScreenState extends ConsumerState<AdminLeaveCalendarScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  List<LeaveRequestModel> _requests = [];
  List<ProfileModel> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _requests = await SupabaseService.getAllLeaveRequests();
      _employees = await SupabaseService.getAllEmployees();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  String _empName(String id) => _employees.where((e) => e.id == id).firstOrNull?.name ?? id;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final firstWeekday = DateTime(_year, _month, 1).weekday % 7;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy').format(DateTime(_year, _month))),
        actions: [
          IconButton(icon: const Icon(Icons.arrow_left), onPressed: () {
            setState(() { if (_month == 1) { _month = 12; _year--; } else { _month--; } });
          }),
          IconButton(icon: const Icon(Icons.arrow_right), onPressed: () {
            setState(() { if (_month == 12) { _month = 1; _year++; } else { _month++; } });
          }),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Calendar grid
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      // Day headers
                      Row(children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map((d) => Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white12)),
                          ),
                          child: Text(d, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                        ),
                      )).toList()),
                      // Day cells
                      for (int row = 0; row < ((firstWeekday + daysInMonth + 6) ~/ 7); row++)
                        Row(children: [
                          for (int col = 0; col < 7; col++)
                            Expanded(
                              child: _buildDayCell(row * 7 + col - firstWeekday + 1, daysInMonth),
                            ),
                        ]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('LEGEND', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                _legendItem(Colors.green, 'Approved leave'),
                _legendItem(Colors.orange, 'Pending leave'),
              ],
            ),
    );
  }

  Widget _buildDayCell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return Container(height: 50);
    final dateStr = '$_year-${_month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final dayRequests = _requests.where((r) =>
        r.status == 'approved' &&
        (r.fromDate.isBefore(DateTime.parse(dateStr).add(const Duration(days: 1))) && r.toDate.isAfter(DateTime.parse(dateStr).subtract(const Duration(days: 1))))).toList();
    final pendingDay = _requests.where((r) =>
        r.status == 'pending' &&
        (r.fromDate.isBefore(DateTime.parse(dateStr).add(const Duration(days: 1))) && r.toDate.isAfter(DateTime.parse(dateStr).subtract(const Duration(days: 1))))).toList();

    final isToday = day == DateTime.now().day && _month == DateTime.now().month && _year == DateTime.now().year;

    return GestureDetector(
      onTap: dayRequests.isNotEmpty || pendingDay.isNotEmpty
          ? () => _showDayDetail(dateStr, dayRequests, pendingDay)
          : null,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          color: isToday ? const Color(0xFF3B82F6).withValues(alpha: 0.15) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day', style: TextStyle(fontSize: 12, color: isToday ? const Color(0xFF3B82F6) : Colors.white70, fontWeight: isToday ? FontWeight.bold : null)),
            if (dayRequests.isNotEmpty)
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 2), decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            if (pendingDay.isNotEmpty)
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 2), decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }

  void _showDayDetail(String dateStr, List<LeaveRequestModel> approved, List<LeaveRequestModel> pending) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (approved.isNotEmpty) ...[
              Text('On Leave', style: TextStyle(color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final r in approved)
                Text('• ${_empName(r.employeeId)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Pending', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final r in pending)
                Text('• ${_empName(r.employeeId)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}
