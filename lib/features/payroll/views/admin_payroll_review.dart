import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../shared/models/payroll_record_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../providers/payroll_provider.dart';
import '../utils/payslip_generator.dart';

class AdminPayrollReview extends ConsumerStatefulWidget {
  const AdminPayrollReview({super.key});

  @override
  ConsumerState<AdminPayrollReview> createState() => _AdminPayrollReviewState();
}

class _AdminPayrollReviewState extends ConsumerState<AdminPayrollReview> {
  PayrollRecordModel? _record;
  String? _name;
  String? _code;
  bool _downloading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extra != null) {
      _record = extra['record'] as PayrollRecordModel?;
      _name = extra['name'] as String?;
      _code = extra['code'] as String?;
    }
  }

  Future<void> _downloadPayslip() async {
    final r = _record;
    if (r == null) return;
    setState(() => _downloading = true);
    try {
      final pdfBytes = await PayslipGenerator.generate(record: r, employeeName: _name ?? 'Employee', employeeCode: _code);
      final month = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][r.month - 1];
      await Printing.sharePdf(bytes: pdfBytes, filename: 'payslip_${month}_${r.year}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.00', 'en_IN');
    final record = _record;

    return Scaffold(
      appBar: AppBar(title: Text(_name ?? 'Payroll Review')),
      body: record == null
          ? const Center(child: Text('No record data'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
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
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    (_name ?? '?')[0].toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 22),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                                      Text('Code: $_code', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(record.status).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _getStatusColor(record.status).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(record.status.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _getStatusColor(record.status))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _salaryRow('Basic Salary', '₹${nf.format(record.basicSalary)}'),
                            const Divider(color: Colors.white12),
                            _salaryRow('Leave Allowed', '${record.allowedLeave} days'),
                            _salaryRow('Leave Deduction', '- ₹${nf.format(record.deductionAmount)}', color: Colors.red.shade300),
                            _salaryRow('Advance Deduction', '- ₹${nf.format(record.advanceAmount)}', color: Colors.red.shade300),
                            const Divider(color: Colors.white12),
                            _salaryRow('Final Salary', '₹${nf.format(record.finalSalary)}', color: const Color(0xFF3B82F6), bold: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (record.isDraft || record.isReviewed)
                    Row(
                      children: [
                        if (record.isDraft)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              onPressed: () => ref.read(payrollStateProvider.notifier).updateStatus(record.id, 'reviewed').then((_) => context.pop()),
                              child: const Text('Mark Reviewed'),
                            ),
                          ),
                        if (record.isReviewed) ...[
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => ref.read(payrollStateProvider.notifier).updateStatus(record.id, 'draft').then((_) => context.pop()),
                              child: const Text('Send to Draft'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                              onPressed: () => ref.read(payrollStateProvider.notifier).updateStatus(record.id, 'approved').then((_) => context.pop()),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (record.isApproved)
                    Column(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                                SizedBox(width: 8),
                                Text('Payroll Approved', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _downloading ? null : _downloadPayslip,
                            icon: _downloading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.download),
                            label: Text(_downloading ? 'Generating...' : 'Download Payslip'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _salaryRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color ?? Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Color _getStatusColor(String s) {
    switch (s) {
      case 'draft': return Colors.grey;
      case 'reviewed': return Colors.blue;
      case 'approved': return const Color(0xFF10B981);
      case 'paid': return const Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }
}
