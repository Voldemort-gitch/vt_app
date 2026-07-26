import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/models/payroll_record_model.dart';
import '../../../shared/models/profile_model.dart';
import '../widgets/payroll_status_badge.dart';

class AdminPayrollDashboard extends StatefulWidget {
  const AdminPayrollDashboard({super.key});
  @override
  State<AdminPayrollDashboard> createState() => _AdminPayrollDashboardState();
}

class _AdminPayrollDashboardState extends State<AdminPayrollDashboard> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  List<PayrollRecordModel> _records = [];
  Map<String, String> _employeeNames = {};
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    try {
      final records = await SupabaseService.getPayrollRecords(_month, _year);
      if (mounted && records.isNotEmpty) {
        setState(() => _records = records);
        _loadNames(records);
      }
    } catch (_) {}
  }

  Future<void> _loadNames(List<PayrollRecordModel> records) async {
    try {
      final employees = await SupabaseService.getAllEmployees();
      final map = <String, String>{};
      for (final e in employees) {
        map[e.id] = e.name;
      }
      for (final r in records) {
        if (!map.containsKey(r.employeeId)) {
          map[r.employeeId] = 'Employee';
        }
      }
      if (mounted) setState(() => _employeeNames = map);
    } catch (_) {}
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final result = await SupabaseService.generatePayroll(_month, _year);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['success'] == true
              ? '✅ Generated ${result['generated']} records'
              : '❌ ${result['error'] ?? 'Failed'}'),
          backgroundColor: result['success'] == true ? const Color(0xFF3B82F6) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ));
        if (result['success'] == true) {
          final records = await SupabaseService.getPayrollRecords(_month, _year);
          if (mounted) {
            setState(() => _records = records);
            _loadNames(records);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _generating = false);
  }

  String _mn(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/admin/payroll/salary')),
        ],
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(_year, _month),
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (picked != null) {
                setState(() { _month = picked.month; _year = picked.year; });
              }
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, color: const Color(0xFF3B82F6), size: 20),
                  const SizedBox(width: 10),
                  Text('${_mn(_month)} $_year', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _generating ? null : _generate,
                child: _generating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Generate Payroll', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text('No payroll records', style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
                        const SizedBox(height: 8),
                        Text('Select month and tap Generate', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _records.length,
                    itemBuilder: (_, i) {
                      final r = _records[i];
                      final empName = _employeeNames[r.employeeId] ?? 'Employee ${i + 1}';
                      return Card(
                        color: const Color(0xFF334155),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                            child: const Icon(Icons.person, color: Color(0xFF3B82F6)),
                          ),
                          title: Text(empName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text('₹${r.finalSalary.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade400)),
                          trailing: PayrollStatusBadge(status: r.status),
                          onTap: () async {
                            await context.push('/admin/payroll/review/${r.id}', extra: {
                              'record': r, 'name': empName, 'code': '',
                            });
                            _loadExisting();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
