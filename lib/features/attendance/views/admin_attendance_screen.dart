import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/services/supabase_service.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  List<AttendanceModel> _records = [];
  List<ProfileModel> _employees = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final records = await SupabaseService.getAllAttendance(
        startDate: startOfDay,
        endDate: today,
      );
      final employees = await SupabaseService.getAllEmployees();

      setState(() {
        _records = records;
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _getEmployeeName(String employeeId) {
    final emp = _employees.where((e) => e.id == employeeId).firstOrNull;
    return emp?.name ?? 'Unknown';
  }

  String _getEmployeeCode(String employeeId) {
    final emp = _employees.where((e) => e.id == employeeId).firstOrNull;
    return emp?.employeeCode ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Attendance")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading data', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : _records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fact_check_outlined, size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text('No attendance records today', style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
                          const SizedBox(height: 8),
                          Text('Employees have not checked in yet', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        return _AttendanceCard(
                          name: _getEmployeeName(record.employeeId),
                          code: _getEmployeeCode(record.employeeId),
                          status: record.status,
                          checkIn: record.checkIn,
                          checkOut: record.checkOut,
                          workingMinutes: record.workingMinutes,
                        );
                      },
                    ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final String name;
  final String code;
  final String status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int workingMinutes;

  const _AttendanceCard({
    required this.name,
    required this.code,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.workingMinutes = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _statusColor().withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: _statusColor().withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: _statusColor().withValues(alpha: 0.15),
              blurRadius: 12,
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
                color: _statusColor().withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person, color: _statusColor(), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name ($code)', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    checkIn != null ? 'In: ${_fmt(checkIn!)}' : 'Not checked in',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor().withValues(alpha: 0.3)),
                  ),
                  child: Text(status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor())),
                ),
                if (workingMinutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${workingMinutes ~/ 60}h ${workingMinutes % 60}m',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),
    );
  }

  Color _statusColor() {
    switch (status) {
      case 'present': return const Color(0xFF10B981);
      case 'late': return Colors.orange;
      case 'absent': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
