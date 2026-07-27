import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/models/payroll_record_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../features/attendance/widgets/attendance_stats_card.dart';
import '../../../features/payroll/utils/payslip_generator.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _pendingLeaves = 0;
  int _pendingAdvances = 0;

  int _payslipMonth = DateTime.now().month;
  int _payslipYear = DateTime.now().year;
  List<PayrollRecordModel> _payrolls = [];
  List<ProfileModel> _employees = [];
  bool _loadingPayslips = false;

  @override
  void initState() {
    super.initState();
    _refreshPendingCounts();
    _loadPayslipData();
  }

  Future<void> _refreshPendingCounts() async {
    await Future.wait([_loadPendingLeaves(), _loadPendingAdvances()]);
  }

  Future<void> _loadPendingLeaves() async {
    try {
      final requests = await SupabaseService.getAllLeaveRequests();
      final pending = requests.where((r) => r.isPending).length;
      if (mounted) setState(() => _pendingLeaves = pending);
    } catch (_) {}
  }

  Future<void> _loadPendingAdvances() async {
    try {
      final count = await SupabaseService.getPendingAdvancesCount();
      if (mounted) setState(() => _pendingAdvances = count);
    } catch (_) {}
  }

  Future<void> _loadPayslipData() async {
    setState(() => _loadingPayslips = true);
    try {
      _employees = await SupabaseService.getAllEmployees();
      _payrolls = await SupabaseService.getPayrollRecords(_payslipMonth, _payslipYear);
    } catch (_) {}
    if (mounted) setState(() => _loadingPayslips = false);
  }

  Future<void> _pickPayslipMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_payslipYear, _payslipMonth),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() { _payslipMonth = picked.month; _payslipYear = picked.year; });
      _loadPayslipData();
    }
  }

  String _mn(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    final cards = [
      const _CardData(Icons.people, 'Employees', 'Manage staff', [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
      const _CardData(Icons.fact_check, 'Attendance', 'View records', [Color(0xFF2563EB), Color(0xFF7C3AED)]),
      _CardData(Icons.event_busy, 'Leave Requests', _pendingLeaves > 0 ? '$_pendingLeaves pending' : 'Approve / Reject', const [Color(0xFFEA580C), Color(0xFFD97706)]),
      _CardData(Icons.request_page, 'Advance', _pendingAdvances > 0 ? '$_pendingAdvances pending' : 'Approve / Reject', const [Color(0xFFE11D48), Color(0xFFBE123C)]),
      const _CardData(Icons.account_balance, 'Payroll', 'Manage salaries', [Color(0xFF059669), Color(0xFF047857)]),
      const _CardData(Icons.assessment, 'Reports', 'Generate reports', [Color(0xFF7C3AED), Color(0xFFDB2777)]),
      const _CardData(Icons.settings, 'Settings', 'Company config', [Color(0xFF475569), Color(0xFF3B82F6)]),
      const _CardData(Icons.qr_code, 'QR Code', 'Generate office QR', [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') ref.read(authStateProvider.notifier).signOut();
              if (value == 'profile') context.push('/employee/profile');
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'info',
                enabled: false,
                child: Text(authState.profile?.name ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(leading: Icon(Icons.person), title: Text('My Profile')),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(leading: Icon(Icons.logout), title: Text('Sign Out')),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Welcome, ${authState.profile?.name ?? 'Admin'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.1,
              ),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final data = cards[index];
                  final routes = ['/admin/employees', '/admin/attendance', '/admin/leave', '/admin/advance', '/admin/payroll', '/admin/reports', '/admin/settings', '/admin/qr-code'];
                  return _GradientCard(
                    data: data,
                    index: index,
                    badge: (index == 2 && _pendingLeaves > 0) ? _pendingLeaves.toString() : (index == 3 && _pendingAdvances > 0) ? _pendingAdvances.toString() : null,
                    onTap: () async {
                      await context.push(routes[index]);
                      if (index == 2 || index == 3) _refreshPendingCounts();
                      if (index == 4 || index == 5) _loadPayslipData();
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              const AttendanceStatsCard(),
              const SizedBox(height: 24),
              _buildPayslipSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPayslipSection() {
    final nf = NumberFormat('#,##0.00', 'en_IN');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.download, color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 8),
            Text('PAYSLIPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade400, letterSpacing: 1)),
            const Spacer(),
            GestureDetector(
              onTap: _pickPayslipMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Text('${_mn(_payslipMonth)} $_payslipYear', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingPayslips)
          const Center(child: CircularProgressIndicator())
        else if (_payrolls.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Generate payroll first', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
          )
        else
          ..._employees.where((e) => _payrolls.any((p) => p.employeeId == e.id)).map((emp) {
            final payroll = _payrolls.firstWhere((p) => p.employeeId == emp.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(emp.name[0].toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                        Text('₹${nf.format(payroll.finalSalary)}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (payroll.isApproved || payroll.isPaid)
                    IconButton(
                      icon: const Icon(Icons.download, color: Color(0xFF3B82F6), size: 20),
                      tooltip: 'Download Payslip',
                      onPressed: () async {
                        try {
                          final pdf = await PayslipGenerator.generate(record: payroll, employeeName: emp.name, employeeCode: emp.employeeCode);
                          await Printing.sharePdf(bytes: pdf, filename: 'payslip_${_mn(_payslipMonth)}_$_payslipYear.pdf');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _CardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  const _CardData(this.icon, this.title, this.subtitle, this.gradient);
}

class _GradientCard extends StatelessWidget {
  final _CardData data;
  final int index;
  final String? badge;
  final VoidCallback onTap;

  const _GradientCard({required this.data, required this.index, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: data.gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: data.gradient.first.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(data.icon, size: 24, color: Colors.white),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(data.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 4),
              Text(data.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ),
        ),
      ).animate().slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOut).scale(
        begin: const Offset(0.95, 0.95),
        duration: 400.ms,
        delay: (index * 100).ms,
      ),
    );
  }
}
