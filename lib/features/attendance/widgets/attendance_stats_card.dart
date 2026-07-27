import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../shared/services/supabase_service.dart';

class AttendanceStatsCard extends StatefulWidget {
  const AttendanceStatsCard({super.key});

  @override
  State<AttendanceStatsCard> createState() => _AttendanceStatsCardState();
}

class _AttendanceStatsCardState extends State<AttendanceStatsCard> {
  int _present = 0;
  int _absent = 0;
  int _onLeave = 0;
  int _total = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final employees = await SupabaseService.getAllEmployees();
      _total = employees.length;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final records = await SupabaseService.getAllAttendance(
        startDate: startOfDay,
        endDate: today,
      );

      int present = 0, onLeave = 0;
      for (final r in records) {
        if (r.status == 'present' || r.status == 'late') present++;
        if (r.status == 'on_leave') onLeave++;
      }

      if (mounted) {
        setState(() {
          _present = present;
          _onLeave = onLeave;
          _absent = _total - present - onLeave;
          if (_absent < 0) _absent = 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))),
      );
    }

    final presentPct = _total > 0 ? (_present / _total * 100).toStringAsFixed(1) : '0';
    final absentPct = _total > 0 ? (_absent / _total * 100).toStringAsFixed(1) : '0';
    final leavePct = _total > 0 ? (_onLeave / _total * 100).toStringAsFixed(1) : '0';

    return ClipRRect(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart, size: 18, color: Color(0xFF3B82F6)),
                  SizedBox(width: 8),
                  Text(
                    'Attendance Statistics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: _buildSections(),
                          startDegreeOffset: -90,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legendItem(const Color(0xFF14B8A6), 'Present', _present, presentPct),
                        const SizedBox(height: 12),
                        _legendItem(const Color(0xFFEF4444), 'Absent', _absent, absentPct),
                        const SizedBox(height: 12),
                        _legendItem(const Color(0xFF3B82F6), 'Leave', _onLeave, leavePct),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Total Employees: $_total',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    final total = _present + _absent + _onLeave;
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade700,
          value: 100,
          title: 'No Data',
          titleStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          radius: 40,
        ),
      ];
    }
    return [
      PieChartSectionData(
        color: const Color(0xFF14B8A6),
        value: _present.toDouble(),
        title: '$_present',
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 45,
      ),
      if (_absent > 0)
        PieChartSectionData(
          color: const Color(0xFFEF4444),
          value: _absent.toDouble(),
          title: '$_absent',
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          radius: 45,
        ),
      if (_onLeave > 0)
        PieChartSectionData(
          color: const Color(0xFF3B82F6),
          value: _onLeave.toDouble(),
          title: '$_onLeave',
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          radius: 45,
        ),
    ];
  }

  Widget _legendItem(Color color, String label, int count, String pct) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$label  $count  ($pct%)', style: TextStyle(color: Colors.grey.shade300, fontSize: 13)),
      ],
    );
  }
}
