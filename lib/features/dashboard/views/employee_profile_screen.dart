import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/supabase_service.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/biometric_provider.dart';
import '../../authentication/providers/biometric_enabled_provider.dart';

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  ConsumerState<EmployeeProfileScreen> createState() =>
      _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bankController;
  late TextEditingController _accountController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authStateProvider).profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _bankController = TextEditingController(text: profile?.bankName ?? '');
    _accountController = TextEditingController(text: profile?.accountNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };
      if (_bankController.text.trim().isNotEmpty) updates['bank_name'] = _bankController.text.trim();
      if (_accountController.text.trim().isNotEmpty) updates['account_number'] = _accountController.text.trim();

      await SupabaseService.updateProfile(userId: userId, updates: updates);

      await ref.read(authStateProvider.notifier).refreshProfile();
      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Color(0xFF3B82F6)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save profile. Try again.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profile = authState.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(color: Colors.white)),
            )
          else
            IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true)),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), width: 2),
                    ),
                    child: const Icon(Icons.person, size: 50, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: _isEditing,
                          decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outlined)),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: profile.employeeCode,
                          enabled: false,
                          decoration: const InputDecoration(labelText: 'Employee Code', prefixIcon: Icon(Icons.badge_outlined)),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          enabled: _isEditing,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bankController,
                          enabled: _isEditing,
                          decoration: const InputDecoration(labelText: 'Bank Name', prefixIcon: Icon(Icons.account_balance_outlined)),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _accountController,
                          enabled: _isEditing,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Account Number', prefixIcon: Icon(Icons.numbers_outlined)),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: profile.role.toUpperCase(),
                          enabled: false,
                          decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.admin_panel_settings_outlined)),
                        ),
                        if (authState.biometricAvailable) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.fingerprint, color: const Color(0xFF3B82F6), size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Fingerprint Login', style: TextStyle(color: Colors.white, fontSize: 14)),
                                      Text('Use fingerprint to unlock app', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: authState.biometricEnabled,
                                  activeThumbColor: const Color(0xFF3B82F6),
                                  onChanged: (v) async {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool('biometric_enabled', v);
                                    ref.read(authStateProvider.notifier).signInStateUpdate(
                                      biometricEnabled: v,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
