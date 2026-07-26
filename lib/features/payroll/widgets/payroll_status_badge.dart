import 'package:flutter/material.dart';

class PayrollStatusBadge extends StatelessWidget {
  final String status;
  const PayrollStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'draft': color = Colors.grey; break;
      case 'reviewed': color = Colors.blue; break;
      case 'approved': color = const Color(0xFF10B981); break;
      case 'paid': color = const Color(0xFF3B82F6); break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
