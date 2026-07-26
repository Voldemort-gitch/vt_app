import 'dart:ui';
import 'package:flutter/material.dart';

class SalarySummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const SalarySummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
