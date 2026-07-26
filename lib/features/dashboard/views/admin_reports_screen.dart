import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/payroll_record_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../payroll/utils/payslip_generator.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  List<ProfileModel> _employees = [];
  List<AttendanceModel> _attendance = [];
  List<PayrollRecordModel> _payrolls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadData();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await SupabaseService.getAllEmployees();
      if (mounted) setState(() => _employees = employees);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final startDate = '$_year-${_month.toString().padLeft(2, '0')}-01';
      final endDate = '$_year-${_month.toString().padLeft(2, '0')}-31';
      final attendance = await SupabaseService.getAllAttendance(
        startDate: DateTime.parse(startDate),
        endDate: DateTime.parse(endDate),
      );
      final payrolls = await SupabaseService.getPayrollRecords(_month, _year);
      if (mounted) {
        setState(() {
          _attendance = attendance;
          _payrolls = payrolls;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() { _month = picked.month; _year = picked.year; });
      _loadData();
    }
  }

  String _mn(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  Map<String, int> _attendanceSummary(String employeeId) {
    final empRecords = _attendance.where((a) => a.employeeId == employeeId);
    int present = 0, late = 0, absent = 0, onLeave = 0;
    for (final r in empRecords) {
      switch (r.status) {
        case 'present': present++; break;
        case 'late': late++; break;
        case 'on_leave': onLeave++; break;
        default: absent++;
      }
    }
    return {'present': present, 'late': late, 'absent': absent, 'on_leave': onLeave};
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.00', 'en_IN');

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          GestureDetector(
            onTap: _pickMonth,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Tap month to change', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _employees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assessment_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            Text('No data', style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _employees.length,
                        itemBuilder: (context, i) {
                          final emp = _employees[i];
                          final summary = _attendanceSummary(emp.id);
                          final payroll = _payrolls.where((p) => p.employeeId == emp.id).firstOrNull;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
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
                                            width: 40, height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              emp.name[0].toUpperCase(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 18),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                                Text('Code: ${emp.employeeCode}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          if (payroll != null && (payroll.isApproved || payroll.isPaid))
                                            IconButton(
                                              icon: const Icon(Icons.download, color: Color(0xFF3B82F6), size: 20),
                                              tooltip: 'Download Payslip',
                                              onPressed: () async {
                                                try {
                                                  final pdf = await PayslipGenerator.generate(record: payroll, employeeName: emp.name, employeeCode: emp.employeeCode, attendanceSummary: summary);
                                                  await Printing.sharePdf(bytes: pdf, filename: 'payslip_${_mn(_month)}_$_year.pdf');
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                                  }
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _statChip(Icons.check_circle, '${summary['present']} Present', const Color(0xFF10B981)),
                                          _statChip(Icons.warning, '${summary['late']} Late', Colors.orange),
                                          _statChip(Icons.cancel, '${summary['absent']} Absent', Colors.red),
                                          _statChip(Icons.event, '${summary['on_leave']} Leave', Colors.blue),
                                        ],
                                      ),
                                      if (payroll != null) ...[
                                        const SizedBox(height: 12),
                                        const Divider(color: Colors.white12),
                                        const SizedBox(height: 8),
                                        _payrollRow('Basic Salary', '₹${nf.format(payroll.basicSalary)}'),
                                        _payrollRow('Leave Allowed', '${payroll.allowedLeave} days'),
                                        _payrollRow('Leave Deduction', '- ₹${nf.format(payroll.deductionAmount)}', Colors.red.shade300),
                                        _payrollRow('Advance Deduction', '- ₹${nf.format(payroll.advanceAmount)}', Colors.red.shade300),
                                        _payrollRow('Final Salary', '₹${nf.format(payroll.finalSalary)}', const Color(0xFF3B82F6), true),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _payrollRow(String label, String value, [Color? color, bool bold = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.white, fontSize: 13,
          )),
        ],
      ),
    );
  }
}
