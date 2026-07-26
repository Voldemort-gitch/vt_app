import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/services/supabase_service.dart';

class AdminEmployeeCrudScreen extends StatefulWidget {
  const AdminEmployeeCrudScreen({super.key});

  @override
  State<AdminEmployeeCrudScreen> createState() => _AdminEmployeeCrudScreenState();
}

class _AdminEmployeeCrudScreenState extends State<AdminEmployeeCrudScreen> {
  List<ProfileModel> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final employees = await SupabaseService.getAllEmployees();
    if (mounted) setState(() { _employees = employees; _isLoading = false; });
  }

  void _showAddEmployeeDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Employee', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Create user in Supabase Dashboard first:\n'
                      'Authentication → Users → Add User\n'
                      'Set email + password. Then add details here.',
                      style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name'), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and email required')));
                return;
              }
              try {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Create "${emailController.text.trim()}" in Supabase Auth first'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Create user in Supabase Dashboard first'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(ProfileModel employee) {
    final nameController = TextEditingController(text: employee.name);
    final phoneController = TextEditingController(text: employee.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Edit ${employee.name}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name'), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.updateEmployee(userId: employee.id, updates: {'name': nameController.text.trim(), 'phone': phoneController.text.trim()});
              if (context.mounted) Navigator.pop(context);
              _loadEmployees();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _resetPin(ProfileModel employee) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Reset PIN for ${employee.name}', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: pinController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'New PIN', hintText: 'Enter 6-digit PIN'),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length < 6) return;
              final result = await SupabaseService.setEmployeePin(
                userId: employee.id,
                pin: pin,
              );
              final success = result['success'] == true;
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'PIN reset to $pin' : result['error']?.toString() ?? 'Failed to reset PIN'),
                    backgroundColor: success ? const Color(0xFF3B82F6) : const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _deactivateEmployee(ProfileModel employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Deactivate Employee', style: TextStyle(color: Colors.white)),
        content: Text('Deactivate ${employee.name}?', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await SupabaseService.deactivateEmployee(employee.id);
              if (context.mounted) Navigator.pop(context);
              _loadEmployees();
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        onPressed: _showAddEmployeeDialog,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
              : _employees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text('No employees found', style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
                          const SizedBox(height: 8),
                          Text('Add employees using the + button', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final emp = _employees[index];
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
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
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
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                      Text(
                                        '${emp.employeeCode}  •  ${emp.phone ?? 'No phone'}',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  color: const Color(0xFF1E293B),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditDialog(emp);
                                    } else if (value == 'resetpin') {
                                      _resetPin(emp);
                                    } else if (value == 'deactivate') {
                                      _deactivateEmployee(emp);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                                    const PopupMenuItem(value: 'resetpin', child: Text('Reset PIN', style: TextStyle(color: Color(0xFF3B82F6)))),
                                    const PopupMenuItem(value: 'deactivate', child: Text('Deactivate', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ],
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
