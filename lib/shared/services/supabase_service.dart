import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/attendance_model.dart';
import '../models/company_settings_model.dart';
import '../models/leave_request_model.dart';
import '../models/employee_salary_model.dart';
import '../models/payroll_record_model.dart';
import '../models/salary_component_model.dart';
import '../models/advance_request_model.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;

  // Auth
  static User? get currentUser => _client.auth.currentUser;
  static String? get currentUserId => _client.auth.currentUser?.id;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static Future<String?> getEmailByEmployeeCode(String code) async {
    try {
      final result = await _client.functions.invoke('manage-pin', body: {
        'action': 'get-email',
        'code': code,
      });
      final raw = result.data;
      final data = (raw is String) ? jsonDecode(raw) as Map<String, dynamic> : raw as Map<String, dynamic>;
      return data['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> setEmployeePin({
    required String userId,
    required String pin,
  }) async {
    try {
      final adminId = currentUserId;
      if (adminId == null) return {'success': false, 'error': 'Not authenticated'};
      final result = await _client.functions.invoke('manage-pin', body: {
        'action': 'set-pin',
        'admin_id': adminId,
        'target_user_id': userId,
        'pin': pin,
      });
      final raw = result.data;
      if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
      if (raw is Map) return raw as Map<String, dynamic>;
      return {'success': false, 'error': 'Unknown response'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Profiles
  static Future<ProfileModel?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  static Future<ProfileModel?> getCurrentProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return getProfile(uid);
  }

  static Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  static Future<List<ProfileModel>> getAllEmployees() async {
    final List<dynamic> data = await _client
        .from('profiles')
        .select()
        .eq('is_active', true)
        .order('name');
    return data
        .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createEmployee({
    required String userId,
    required String name,
    required String employeeCode,
    String? phone,
    String? departmentId,
  }) async {
    await _client.from('profiles').insert({
      'id': userId,
      'name': name,
      'employee_code': employeeCode,
      'phone': phone,
      'department_id': departmentId,
      'role': 'employee',
      'is_active': true,
    });
  }

  static Future<void> updateEmployee({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  static Future<void> deactivateEmployee(String userId) async {
    await _client
        .from('profiles')
        .update({'is_active': false}).eq('id', userId);
  }

  // Attendance
  static Future<AttendanceModel?> getTodayAttendance(String employeeId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('attendance')
        .select()
        .eq('employee_id', employeeId)
        .eq('attendance_date', today)
        .maybeSingle();
    if (data == null) return null;
    return AttendanceModel.fromJson(data);
  }

  static Future<void> checkIn({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String status,
  }) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _client.from('attendance').insert({
      'employee_id': employeeId,
      'attendance_date': today,
      'check_in': DateTime.now().toIso8601String(),
      'check_in_latitude': latitude,
      'check_in_longitude': longitude,
      'status': status,
    });
  }

  static Future<void> checkOut({
    required String employeeId,
    required double latitude,
    required double longitude,
    required int workingMinutes,
  }) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _client
        .from('attendance')
        .update({
          'check_out': DateTime.now().toIso8601String(),
          'check_out_latitude': latitude,
          'check_out_longitude': longitude,
          'working_minutes': workingMinutes,
        })
        .eq('employee_id', employeeId)
        .eq('attendance_date', today);
  }

  static Future<List<AttendanceModel>> getAttendanceHistory({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final List<dynamic> data = await _client
        .from('attendance')
        .select()
        .eq('employee_id', employeeId)
        .gte(
          'attendance_date',
          (startDate ?? DateTime(2024)).toIso8601String().split('T')[0],
        )
        .lte(
          'attendance_date',
          (endDate ?? DateTime.now()).toIso8601String().split('T')[0],
        )
        .order('attendance_date', ascending: false);

    return data
        .map((json) =>
            AttendanceModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AttendanceModel>> getAllAttendance({
    DateTime? startDate,
    DateTime? endDate,
    String? employeeId,
  }) async {
    var query = _client.from('attendance').select();

    if (employeeId != null) {
      query = query.eq('employee_id', employeeId);
    }
    if (startDate != null) {
      query = query.gte(
        'attendance_date',
        startDate.toIso8601String().split('T')[0],
      );
    }
    if (endDate != null) {
      query = query.lte(
        'attendance_date',
        endDate.toIso8601String().split('T')[0],
      );
    }

    final List<dynamic> data =
        await query.order('attendance_date', ascending: false);
    return data
        .map((json) =>
            AttendanceModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Company Settings
  static Future<CompanySettingsModel> getCompanySettings() async {
    final data =
        await _client.from('company_settings').select().limit(1).maybeSingle();
    if (data == null) {
      return CompanySettingsModel(
        id: 1, companyName: 'My Company',
        officeLatitude: 0, officeLongitude: 0,
        allowedRadius: 100, officeStartTime: '09:00',
        officeEndTime: '18:00', lateAfterMinutes: 15,
        updatedAt: DateTime.now(),
      );
    }
    return CompanySettingsModel.fromJson(data);
  }

  static Future<void> updateCompanySettings({
    required Map<String, dynamic> updates,
  }) async {
    await _client.from('company_settings').update(updates).eq('id', 1);
    final uid = currentUserId;
    if (uid != null) {
      final changed = updates.keys.join(', ');
      _logAudit(uid, 'settings_update', 'Changed: $changed');
    }
  }

  // Leave Requests
  static Future<void> submitLeaveRequest({
    required String employeeId,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    await _client.from('leave_requests').insert({
      'employee_id': employeeId,
      'from_date': fromDate.toIso8601String().split('T')[0],
      'to_date': toDate.toIso8601String().split('T')[0],
      'reason': reason,
      'status': 'pending',
    });
  }

  static Future<List<LeaveRequestModel>> getMyLeaveRequests(
    String employeeId,
  ) async {
    final List<dynamic> data = await _client
        .from('leave_requests')
        .select()
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);
    return data
        .map((json) =>
            LeaveRequestModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<List<LeaveRequestModel>> getAllLeaveRequests() async {
    final List<dynamic> data = await _client
        .from('leave_requests')
        .select()
        .order('created_at', ascending: false);
    return data
        .map((json) =>
            LeaveRequestModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updateLeaveStatus({
    required int leaveId,
    required String status,
    required String adminId,
  }) async {
    await _client
        .from('leave_requests')
        .update({
          'status': status,
          'admin_id': adminId,
        })
        .eq('id', leaveId);
    _logAudit(adminId, 'leave_status_change', 'Leave $leaveId → $status');
  }

  static Future<void> _logAudit(String adminId, String action, String details) async {
    await _client.from('admin_audit_log').insert({
      'admin_id': adminId,
      'action': action,
      'details': details,
      'ip_address': 'mobile_app',
    });
  }

  // ==================== Payroll ====================

  static Future<EmployeeSalaryModel?> getLatestEmployeeSalary(String employeeId) async {
    final data = await _client
        .from('employee_salary_history')
        .select()
        .eq('employee_id', employeeId)
        .order('effective_from', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return EmployeeSalaryModel.fromJson(data);
  }

  static Future<void> setEmployeeSalary({
    required String employeeId,
    required double monthlySalary,
    required int workingDays,
    required int allowedLeaves,
    required DateTime effectiveFrom,
  }) async {
    await _client.from('employee_salary_history').insert({
      'employee_id': employeeId,
      'monthly_salary': monthlySalary,
      'working_days': workingDays,
      'allowed_leaves': allowedLeaves,
      'effective_from': effectiveFrom.toIso8601String().split('T')[0],
    });
  }

  static Future<Map<String, dynamic>> generatePayroll(int month, int year) async {
    try {
      final result = await _client.functions.invoke('generate-payroll', body: {
        'month': month,
        'year': year,
      });
      final raw = result.data;
      if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
      if (raw is Map) return raw as Map<String, dynamic>;
      return {'success': false, 'error': 'Unknown response'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<PayrollRecordModel>> getPayrollRecords(int month, int year) async {
    final List<dynamic> data = await _client
        .from('payroll_records')
        .select()
        .eq('month', month)
        .eq('year', year)
        .order('created_at', ascending: false);
    return data
        .map((json) => PayrollRecordModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<List<PayrollRecordModel>> getMyPayrollRecords() async {
    final userId = currentUserId;
    if (userId == null) return [];
    final List<dynamic> data = await _client
        .from('payroll_records')
        .select()
        .eq('employee_id', userId)
        .order('created_at', ascending: false);
    return data
        .map((json) => PayrollRecordModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updatePayrollStatus(String recordId, String status) async {
    await _client
        .from('payroll_records')
        .update({'status': status})
        .eq('id', recordId);
  }

  // ==================== Salary Components ====================

  static Future<SalaryComponentModel?> getSalaryComponents(String employeeId) async {
    final data = await _client
        .from('salary_components')
        .select()
        .eq('employee_id', employeeId)
        .maybeSingle();
    if (data == null) return null;
    return SalaryComponentModel.fromJson(data);
  }

  static Future<void> setSalaryComponents({
    required String employeeId,
    required double basicPct,
    required double hraPct,
    required double conveyancePct,
    required double medicalPct,
    required double specialPct,
    required double healthInsurance,
    required double professionalTax,
    required double tds,
  }) async {
    final existing = await _client
        .from('salary_components')
        .select('id')
        .eq('employee_id', employeeId)
        .maybeSingle();
    final body = {
      'employee_id': employeeId,
      'basic_pct': basicPct,
      'hra_pct': hraPct,
      'conveyance_pct': conveyancePct,
      'medical_pct': medicalPct,
      'special_pct': specialPct,
      'health_insurance': healthInsurance,
      'professional_tax': professionalTax,
      'tds': tds,
    };
    if (existing != null) {
      await _client.from('salary_components').update(body).eq('employee_id', employeeId);
    } else {
      await _client.from('salary_components').insert(body);
    }
  }

  // ==================== Advance Requests ====================

  static Future<void> submitAdvanceRequest({
    required String employeeId,
    required double amount,
    String? reason,
    int? month,
    int? year,
  }) async {
    final now = DateTime.now();
    await _client.from('advance_requests').insert({
      'employee_id': employeeId,
      'amount': amount,
      'reason': reason,
      'month': month ?? now.month,
      'year': year ?? now.year,
    });
  }

  static Future<List<AdvanceRequestModel>> getMyAdvanceRequests() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final List<dynamic> data = await _client
        .from('advance_requests')
        .select()
        .eq('employee_id', uid)
        .order('created_at', ascending: false);
    return data.map((j) => AdvanceRequestModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<List<AdvanceRequestModel>> getAllAdvanceRequests() async {
    final List<dynamic> data = await _client
        .from('advance_requests')
        .select()
        .order('created_at', ascending: false);
    return data.map((j) => AdvanceRequestModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<int> getPendingAdvancesCount() async {
    try {
      final List<dynamic> data = await _client
          .from('advance_requests')
          .select('id')
          .eq('status', 'pending');
      return data.length;
    } catch (_) { return 0; }
  }

  static Future<void> updateAdvanceStatus(String id, String status, String adminId) async {
    await _client
        .from('advance_requests')
        .update({'status': status, 'admin_id': adminId})
        .eq('id', id);
  }

  static Future<List<AdvanceRequestModel>> getApprovedAdvances(int month, int year) async {
    final List<dynamic> data = await _client
        .from('advance_requests')
        .select()
        .eq('status', 'approved')
        .eq('month', month)
        .eq('year', year);
    return data.map((j) => AdvanceRequestModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<bool> hasApprovedLeaveInMonth({required int month, required int year, String? excludeEmployeeId}) async {
    try {
      var query = _client
          .from('leave_requests')
          .select('id')
          .eq('status', 'approved')
          .gte('from_date', '$year-${month.toString().padLeft(2, '0')}-01')
          .lte('to_date', '$year-${month.toString().padLeft(2, '0')}-31');
      if (excludeEmployeeId != null) {
        query = query.neq('employee_id', excludeEmployeeId);
      }
      final List<dynamic> data = await query;
      return data.isNotEmpty;
    } catch (_) { return false; }
  }

  // ==================== Leave Queries ====================

  static Future<int> getEmployeesOnLeaveCount(String date) async {
    try {
      final List<dynamic> data = await _client
          .from('attendance')
          .select('employee_id')
          .eq('attendance_date', date)
          .eq('status', 'on_leave');
      return data.length;
    } catch (_) { return 0; }
  }
}
