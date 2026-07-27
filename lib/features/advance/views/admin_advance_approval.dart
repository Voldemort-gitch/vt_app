import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/supabase_service.dart';
import '../providers/advance_provider.dart';

class AdminAdvanceApproval extends ConsumerStatefulWidget {
  const AdminAdvanceApproval({super.key});

  @override
  ConsumerState<AdminAdvanceApproval> createState() => _AdminAdvanceApprovalState();
}

class _AdminAdvanceApprovalState extends ConsumerState<AdminAdvanceApproval> {
  Map<String, String> _names = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(advanceStateProvider);
      if (state.requests.isEmpty && !state.isLoading) {
        ref.read(advanceStateProvider.notifier).loadAllRequests();
      }
      _loadEmployees();
    });
  }

  Future<void> _loadEmployees() async {
    final emps = await SupabaseService.getAllEmployees();
    final map = <String, String>{};
    for (final e in emps) { map[e.id] = e.name; }
    if (mounted) setState(() => _names = map);
  }

  @override
  Widget build(BuildContext context) {
    final advanceState = ref.watch(advanceStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advance Requests')),
      body: advanceState.isLoading && advanceState.requests.isEmpty
          ? const Center(child: CircularProgressIndicator())
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _statusColor(r.status).withValues(alpha: 0.2),
                                  child: Icon(_statusIcon(r.status), color: _statusColor(r.status)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_names[r.employeeId] ?? 'Employee',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      Text(DateFormat('dd MMM yyyy').format(r.createdAt),
                                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(r.status).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(r.status.toUpperCase(), style: TextStyle(color: _statusColor(r.status), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('₹${r.amount.toStringAsFixed(0)} — ${r.reason ?? "No reason"}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                            if (r.status == 'pending') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      onPressed: () => ref.read(advanceStateProvider.notifier).updateStatus(r.id, 'rejected'),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                                      onPressed: () => ref.read(advanceStateProvider.notifier).updateStatus(r.id, 'approved'),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
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
