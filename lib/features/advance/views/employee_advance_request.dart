import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/supabase_service.dart';
import '../providers/advance_provider.dart';

class EmployeeAdvanceRequest extends ConsumerStatefulWidget {
  const EmployeeAdvanceRequest({super.key});

  @override
  ConsumerState<EmployeeAdvanceRequest> createState() => _EmployeeAdvanceRequestState();
}

class _EmployeeAdvanceRequestState extends ConsumerState<EmployeeAdvanceRequest> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(advanceStateProvider);
      if (state.requests.isEmpty && !state.isLoading) {
        ref.read(advanceStateProvider.notifier).loadMyRequests();
      }
    });
  }

  void _showRequestDialog() {
    final amountC = TextEditingController();
    final reasonC = TextEditingController();
    final now = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Request Advance', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountC, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Amount (₹)')),
            const SizedBox(height: 12),
            TextField(controller: reasonC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () async {
                final amount = double.tryParse(amountC.text);
                if (amount == null || amount <= 0) return;
                final userId = SupabaseService.currentUserId;
                if (userId == null) return;
                final salary = await SupabaseService.getLatestEmployeeSalary(userId);
                if (salary != null && amount > salary.monthlySalary * 0.5) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Maximum advance is 50% of monthly salary (₹${(salary.monthlySalary * 0.5).toStringAsFixed(0)})'),
                      backgroundColor: const Color(0xFFDC2626),
                    ));
                  }
                  return;
                }
                await ref.read(advanceStateProvider.notifier).submitRequest(
                  amount, reasonC.text, now.month, now.year,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final advanceState = ref.watch(advanceStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advance Requests')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        onPressed: _showRequestDialog,
        child: const Icon(Icons.add),
      ),
      body: advanceState.isLoading && advanceState.requests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : advanceState.error != null && advanceState.requests.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(advanceState.error!, style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.read(advanceStateProvider.notifier).loadMyRequests(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : advanceState.requests.isEmpty
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.request_page_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No advance requests', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: advanceState.requests.length,
                  itemBuilder: (context, i) {
                    final r = advanceState.requests[i];
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(r.status).withValues(alpha: 0.2),
                          child: Icon(_statusIcon(r.status), color: _statusColor(r.status)),
                        ),
                        title: Text('₹${r.amount.toStringAsFixed(0)} — ${r.reason ?? "No reason"}', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(r.createdAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(r.status).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(r.status.toUpperCase(), style: TextStyle(color: _statusColor(r.status), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return const Color(0xFF10B981);
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      default: return Icons.schedule;
    }
  }
}
