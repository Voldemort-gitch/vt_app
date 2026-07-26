import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../shared/services/supabase_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _companyNameController;
  late TextEditingController _officeLatController;
  late TextEditingController _officeLngController;
  late TextEditingController _allowedRadiusController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _lateAfterController;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SupabaseService.getCompanySettings();
    setState(() {
      _companyNameController = TextEditingController(text: settings.companyName);
      _officeLatController = TextEditingController(text: settings.officeLatitude.toString());
      _officeLngController = TextEditingController(text: settings.officeLongitude.toString());
      _allowedRadiusController = TextEditingController(text: settings.allowedRadius.toString());
      _startTimeController = TextEditingController(text: settings.officeStartTime);
      _endTimeController = TextEditingController(text: settings.officeEndTime);
      _lateAfterController = TextEditingController(text: settings.lateAfterMinutes.toString());
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.updateCompanySettings(updates: {
        'company_name': _companyNameController.text.trim(),
        'office_latitude': double.tryParse(_officeLatController.text) ?? 0.0,
        'office_longitude': double.tryParse(_officeLngController.text) ?? 0.0,
        'allowed_radius': double.tryParse(_allowedRadiusController.text) ?? 100.0,
        'office_start_time': _startTimeController.text.trim(),
        'office_end_time': _endTimeController.text.trim(),
        'late_after_minutes': int.tryParse(_lateAfterController.text) ?? 15,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved'), backgroundColor: Color(0xFF3B82F6)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save settings. Try again.'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildSections(),
              ),
            ),
    );
  }

  List<Widget> _buildSections() {
    return [
      _sectionHeader('Company'),
      const SizedBox(height: 12),
      _glassCard([
        TextField(
          controller: _companyNameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Company Name', prefixIcon: Icon(Icons.business, size: 20)),
        ),
      ]),
      const SizedBox(height: 28),
      _sectionHeader('Office Location (GPS)'),
      const SizedBox(height: 12),
      _glassCard([
        Row(
          children: [
            Expanded(child: TextField(
              controller: _officeLatController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Latitude', prefixIcon: Icon(Icons.location_on, size: 20)),
              keyboardType: TextInputType.number,
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _officeLngController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Longitude', prefixIcon: Icon(Icons.location_on, size: 20)),
              keyboardType: TextInputType.number,
            )),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _allowedRadiusController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Allowed Radius (meters)', prefixIcon: Icon(Icons.radar, size: 20)),
          keyboardType: TextInputType.number,
        ),
      ]),
      const SizedBox(height: 28),
      _sectionHeader('Office Hours'),
      const SizedBox(height: 12),
      _glassCard([
        Row(
          children: [
            Expanded(child: TextField(
              controller: _startTimeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Start Time (HH:mm)', prefixIcon: Icon(Icons.access_time, size: 20)),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _endTimeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'End Time (HH:mm)', prefixIcon: Icon(Icons.access_time_filled, size: 20)),
            )),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lateAfterController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Late After (minutes)', prefixIcon: Icon(Icons.timer, size: 20)),
          keyboardType: TextInputType.number,
        ),
      ]),
    ];
  }

  Widget _sectionHeader(String text) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white));
  }

  Widget _glassCard(List<Widget> children) {
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
          child: Column(children: children),
        ),
      ),
    );
  }
}
