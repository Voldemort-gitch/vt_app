import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/models/payroll_record_model.dart';
import '../../../features/attendance/widgets/attendance_stats_card.dart';
import '../../../features/payroll/utils/payslip_generator.dart';

class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen> {
  List<Map<String, dynamic>> _weekRecords = [];
  PayrollRecordModel? _latestPayroll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceStateProvider.notifier).loadTodayAttendance();
      _loadWeek();
      _loadLatestPayroll();
    });
  }

  Future<void> _loadLatestPayroll() async {
    try {
      final records = await SupabaseService.getMyPayrollRecords();
      if (records.isNotEmpty) _latestPayroll = records.first;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadWeek() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final records = await SupabaseService.getAttendanceHistory(
      employeeId: userId,
      startDate: DateTime.now().subtract(const Duration(days: 6)),
      endDate: DateTime.now(),
    );
    final weekData = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dayStr = DateFormat('EE').format(date).substring(0, 2);
      final match = records.where((r) =>
        r.attendanceDate.year == date.year &&
        r.attendanceDate.month == date.month &&
        r.attendanceDate.day == date.day,
      ).firstOrNull;
      weekData.add({
        'day': dayStr,
        'status': match?.status ?? 'absent',
        'hasData': match != null,
      });
    }
    if (mounted) setState(() => _weekRecords = weekData);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final attendanceState = ref.watch(attendanceStateProvider);

    ref.listen<AttendanceState>(attendanceStateProvider, (prev, next) {
      if (next.error != null) {
        ToastHelper.show(context, next.error!, isError: true);
        ref.read(attendanceStateProvider.notifier).clearMessages();
      }
      if (next.successMessage != null) {
        ToastHelper.show(context, next.successMessage!);
        ref.read(attendanceStateProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Time'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'history':
                  context.push('/employee/history');
                  break;
                case 'leave':
                  context.push('/employee/leave');
                  break;
                case 'salary':
                  context.push('/employee/salary');
                  break;
                case 'advance':
                  context.push('/employee/advance');
                  break;
                case 'profile':
                  context.push('/employee/profile');
                  break;
                case 'logout':
                  ref.read(authStateProvider.notifier).signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Attendance History'),
                ),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.event_busy),
                  title: Text('Leave Request'),
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('My Profile'),
                ),
              ),
              const PopupMenuItem(
                value: 'salary',
                child: ListTile(
                  leading: Icon(Icons.account_balance),
                  title: Text('My Salary'),
                ),
              ),
              const PopupMenuItem(
                value: 'advance',
                child: ListTile(
                  leading: Icon(Icons.request_page),
                  title: Text('Request Advance'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: attendanceState.isLoading
          ? Center(
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade800,
                highlightColor: Colors.grey.shade700,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200, height: 200,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 150, height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.08,
                  ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          authState.profile?.name ?? 'Employee',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ).animate(onPlay: (controller) => controller.repeat()).shimmer(
                          duration: 2000.ms,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${authState.profile?.employeeCode ?? ''}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 32),
                        if (!attendanceState.hasCheckedIn)
                        GestureDetector(
                          onTap: () => context.push('/employee/qr-scanner'),
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.qr_code_scanner,
                                size: 90,
                                color: Colors.white,
                              ),
                            ),
                          ).animate().fadeIn(duration: 600.ms).shimmer(
                            duration: 2000.ms,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      if (attendanceState.hasCheckedIn && !attendanceState.hasCheckedOut)
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.shade700.withValues(alpha: 0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle_outline,
                              size: 90,
                              color: Colors.white,
                            ),
                          ),
                        ).animate().scale(
                          duration: 400.ms,
                          curve: Curves.elasticOut,
                        ),
                      if (attendanceState.isDoneToday)
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.task_alt,
                              size: 90,
                              color: Colors.white,
                            ),
                          ),
                        ).animate().fadeIn(duration: 500.ms),
                      const SizedBox(height: 32),
                      if (attendanceState.todayAttendance?.checkIn != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 32),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _InfoRow(
                                      label: 'Check In',
                                      value: _formatTime(attendanceState.todayAttendance!.checkIn!),
                                    ),
                                    if (attendanceState.todayAttendance?.checkOut != null)
                                      _InfoRow(
                                        label: 'Check Out',
                                        value: _formatTime(attendanceState.todayAttendance!.checkOut!),
                                      ),
                                    if (attendanceState.todayAttendance?.workingMinutes != 0)
                                      _InfoRow(
                                        label: 'Working',
                                        value: '${attendanceState.todayAttendance!.workingMinutes ~/ 60}h ${attendanceState.todayAttendance!.workingMinutes % 60}m',
                                      ),
                                    _InfoRow(
                                      label: 'Status',
                                      value: _capitalize(attendanceState.todayAttendance?.status ?? ''),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ).animate().slideY(
                          begin: 0.3,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        ),
                      if (_weekRecords.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: _weekRecords.map((d) {
                                    final status = d['status'] as String;
                                    final hasData = d['hasData'] as bool;
                                    Color dotColor;
                                    if (!hasData) {
                                      dotColor = Colors.grey.shade700;
                                    } else if (status == 'late') {
                                      dotColor = Colors.orange;
                                    } else if (status == 'present') {
                                      dotColor = const Color(0xFF10B981);
                                    } else {
                                      dotColor = Colors.red.shade400;
                                    }
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 28, height: 28,
                                          decoration: BoxDecoration(
                                            color: dotColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              d['day'] as String,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const AttendanceStatsCard(),
                        const SizedBox(height: 24),
                        _buildQuickAccess(),
                        if (_latestPayroll != null) ...[
                          const SizedBox(height: 20),
                          _buildLatestPayslip(),
                        ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildQuickAccess() {
    final items = [
      _QaItem(Icons.history, 'History', const Color(0xFF3B82F6), '/employee/history'),
      _QaItem(Icons.event_busy, 'Leave', const Color(0xFFEA580C), '/employee/leave'),
      _QaItem(Icons.account_balance, 'Payroll', const Color(0xFF059669), '/employee/salary'),
      _QaItem(Icons.request_page, 'Advance', const Color(0xFFE11D48), '/employee/advance'),
      _QaItem(Icons.person, 'Profile', const Color(0xFF7C3AED), '/employee/profile'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text('QUICK ACCESS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) => _QaCard(item: item, onTap: () => context.push(item.route))).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestPayslip() {
    final r = _latestPayroll!;
    final month = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][r.month - 1];
    final nf = NumberFormat('#,##0.00', 'en_IN');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [const Color(0xFF059669).withValues(alpha: 0.15), const Color(0xFF047857).withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                Text('Payslip — $month ${r.year}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                const Spacer(),
                Text(r.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Pay', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                Text('₹${nf.format(r.finalSalary)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            if (r.isApproved || r.isPaid)
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download Payslip'),
                  onPressed: () async {
                    final name = SupabaseService.currentUser?.email ?? 'Employee';
                    try {
                      final pdf = await PayslipGenerator.generate(record: r, employeeName: name);
                      await Printing.sharePdf(bytes: pdf, filename: 'payslip_${month}_${r.year}.pdf');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class _QaItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _QaItem(this.icon, this.label, this.color, this.route);
}

class _QaCard extends StatelessWidget {
  final _QaItem item;
  final VoidCallback onTap;
  const _QaCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [item.color.withValues(alpha: 0.2), item.color.withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.color.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: item.color, size: 24),
            const SizedBox(height: 6),
            Text(item.label, style: TextStyle(color: item.color, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
