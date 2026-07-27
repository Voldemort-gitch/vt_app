import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/models/employee_salary_model.dart';
import '../../../shared/models/salary_component_model.dart';

class AdminSalaryConfig extends ConsumerStatefulWidget {
  const AdminSalaryConfig({super.key});
  @override
  ConsumerState<AdminSalaryConfig> createState() => _AdminSalaryConfigState();
}

class _AdminSalaryConfigState extends ConsumerState<AdminSalaryConfig> {
  List<ProfileModel> _employees = [];
  final Map<String, EmployeeSalaryModel?> _salaries = {};
  final Map<String, SalaryComponentModel?> _components = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _employees = await SupabaseService.getAllEmployees();
      for (final e in _employees) {
        _salaries[e.id] = await SupabaseService.getLatestEmployeeSalary(e.id);
        _components[e.id] = await SupabaseService.getSalaryComponents(e.id);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showDialog(ProfileModel emp) {
    final sal = _salaries[emp.id];
    final comp = _components[emp.id];

    final salaryC = TextEditingController(text: sal?.monthlySalary.toString() ?? '');
    final daysC = TextEditingController(text: (sal?.workingDays ?? 30).toString());
    final leavesC = TextEditingController(text: (sal?.allowedLeaves ?? 4).toString());
    final basicPctC = TextEditingController(text: (comp?.basicPct ?? 45).toString());
    final hraPctC = TextEditingController(text: (comp?.hraPct ?? 17).toString());
    final conveyPctC = TextEditingController(text: (comp?.conveyancePct ?? 3).toString());
    final medicalPctC = TextEditingController(text: (comp?.medicalPct ?? 2).toString());
    final specialPctC = TextEditingController(text: (comp?.specialPct ?? 33).toString());
    final healthC = TextEditingController(text: (comp?.healthInsurance ?? 0).toString());
    final profTaxC = TextEditingController(text: (comp?.professionalTax ?? 200).toString());
    final tdsC = TextEditingController(text: (comp?.tds ?? 0).toString());
    DateTime? _effectiveDate = sal?.effectiveFrom;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Salary: ${emp.name}', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionTitle('Basic Salary'),
              TextField(controller: salaryC, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Monthly Salary (₹)')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: daysC, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Working Days'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: leavesC, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Leaves/Month'))),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('Salary Components (%)'),
              Row(
                children: [
                  _pctField(basicPctC, 'Basic'),
                  _pctField(hraPctC, 'HRA'),
                  _pctField(conveyPctC, 'Convy'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _pctField(medicalPctC, 'Medical'),
                  _pctField(specialPctC, 'Special'),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('Fixed Deductions (₹)'),
              Row(
                children: [
                  _dedField(healthC, 'Health'),
                  _dedField(profTaxC, 'Prof Tax'),
                  _dedField(tdsC, 'TDS'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () async {
              try {
                await SupabaseService.setEmployeeSalary(
                  employeeId: emp.id,
                  monthlySalary: double.tryParse(salaryC.text) ?? 0,
                  workingDays: int.tryParse(daysC.text) ?? 30,
                  allowedLeaves: int.tryParse(leavesC.text) ?? 4,
                  effectiveFrom: _effectiveDate ?? DateTime.now(),
                );
                await SupabaseService.setSalaryComponents(
                  employeeId: emp.id,
                  basicPct: double.tryParse(basicPctC.text) ?? 45,
                  hraPct: double.tryParse(hraPctC.text) ?? 17,
                  conveyancePct: double.tryParse(conveyPctC.text) ?? 3,
                  medicalPct: double.tryParse(medicalPctC.text) ?? 2,
                  specialPct: double.tryParse(specialPctC.text) ?? 33,
                  healthInsurance: double.tryParse(healthC.text) ?? 0,
                  professionalTax: double.tryParse(profTaxC.text) ?? 200,
                  tds: double.tryParse(tdsC.text) ?? 0,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Salary saved'), backgroundColor: Color(0xFF3B82F6)),
                );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
                );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _pctField(TextEditingController c, String label) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(controller: c, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11))),
    ),
  );

  Widget _dedField(TextEditingController c, String label) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(controller: c, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11))),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Configuration')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _employees.length,
              itemBuilder: (context, i) {
                final emp = _employees[i];
                final sal = _salaries[emp.id];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: InkWell(
                          onTap: () => _showDialog(emp),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(emp.name[0].toUpperCase(), textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                    Text(emp.employeeCode, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text(
                                sal != null ? '₹${sal.monthlySalary.toStringAsFixed(0)}' : '—',
                                style: TextStyle(fontWeight: FontWeight.bold, color: sal != null ? const Color(0xFF10B981) : Colors.grey.shade500),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit, color: Colors.grey, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
