import 'dart:convert';
import '../../core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/attendance_model.dart';
import '../models/company_settings_model.dart';
import '../models/leave_request_model.dart';
import '../models/employee_salary_model.dart';
import '../models/payroll_record_model.dart';
import '../models/salary_component_model.dart';
import '../models/advance_request_model.dart';
import '../models/leave_balance_model.dart';

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

  static Future<Map<String, dynamic>?> getEmployeeByCode(String code) async {
    try {
      final result = await _client.functions.invoke('manage-pin', body: {
        'action': 'get-email',
        'code': code,
      });
      final raw = result.data;
      final data = (raw is String) ? jsonDecode(raw) as Map<String, dynamic> : raw as Map<String, dynamic>;
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> createEmployeeUser({
    required String email,
    required String password,
    required String name,
    required String employeeCode,
    String? phone,
  }) async {
    try {
      final result = await _client.functions.invoke('manage-pin', body: {
        'action': 'create-user',
        'email': email,
        'password': password,
        'name': name,
        'employee_code': employeeCode,
        'phone': phone ?? '',
      });
      final raw = result.data;
      if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
      if (raw is Map) return raw as Map<String, dynamic>;
      return {'success': false, 'error': 'Unknown response'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<String?> getEmailByEmployeeCode(String code) async {
    final data = await getEmployeeByCode(code);
    return data?['email'] as String?;
  }

  static Future<Map<String, dynamic>> checkLoginAttempt(String userId) async {
    try {
      final result = await _client.functions.invoke('manage-pin', body: {
        'action': 'check-login-attempt',
        'target_user_id': userId,
      });
      final raw = result.data;
      if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
      if (raw is Map) return raw as Map<String, dynamic>;
      return {'allowed': true};
    } catch (_) {
      return {'allowed': true};
    }
  }

  static Future<void> recordLoginFailure(String userId) async {
    try {
      await _client.functions.invoke('manage-pin', body: {
        'action': 'record-login-failure',
        'target_user_id': userId,
      });
    } catch (_) {}
  }

  static Future<void> clearLoginAttempts(String userId) async {
    try {
      await _client.functions.invoke('manage-pin', body: {
        'action': 'clear-login-attempts',
        'target_user_id': userId,
      });
    } catch (_) {}
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
        .eq('role', 'employee')
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

  static Future<Map<String, dynamic>> checkIn({
    required String employeeId,
    required double latitude,
    required double longitude,
    String? companyId,
  }) async {
    try {
      final body = <String, dynamic>{
        'action': 'check-in',
        'employee_id': employeeId,
        'latitude': latitude,
        'longitude': longitude,
      };
      if (companyId != null) body['company_id'] = companyId;
      final result = await _client.functions.invoke('process-attendance', body: body);
      final raw = result.data;
      if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
      if (raw is Map) return raw as Map<String, dynamic>;
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkOut({
    required String employeeId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final result = await _client.functions.invoke('process-attendance', body: {
        'action': 'check-out',
        'employee_id': employeeId,
        'latitude': latitude,
        'longitude': longitude,
      });
      final raw = result.data;
      if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
      if (raw is Map) return raw as Map<String, dynamic>;
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
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
        .order('attendance_date', ascending: false)
        .limit(200);

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
        await query.order('attendance_date', ascending: false).limit(500);
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
    String leaveType = 'casual',
  }) async {
    await _client.from('leave_requests').insert({
      'employee_id': employeeId,
      'from_date': fromDate.toIso8601String().split('T')[0],
      'to_date': toDate.toIso8601String().split('T')[0],
      'reason': reason,
      'status': 'pending',
      'leave_type': leaveType,
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
        .order('created_at', ascending: false)
        .limit(500);
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
        .order('created_at', ascending: false)
        .limit(100);
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

  // ==================== Leave Balance ====================

  static Future<List<LeaveBalanceModel>> getLeaveBalances(String employeeId) async {
    try {
      final List<dynamic> data = await _client
          .from('leave_balance')
          .select()
          .eq('employee_id', employeeId)
          .eq('year', DateTime.now().year)
          .order('leave_type');
      return data.map((j) => LeaveBalanceModel.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  static Future<void> initLeaveBalance(String employeeId) async {
    final year = DateTime.now().year;
    final defaults = [
      {'employee_id': employeeId, 'year': year, 'leave_type': 'sick', 'total_days': 12},
      {'employee_id': employeeId, 'year': year, 'leave_type': 'casual', 'total_days': 12},
      {'employee_id': employeeId, 'year': year, 'leave_type': 'annual', 'total_days': 15},
    ];
    for (final record in defaults) {
      await _client.from('leave_balance').upsert(record,
          onConflict: 'employee_id,year,leave_type');
    }
  }

  static Future<bool> hasLeaveBalance(String employeeId, String leaveType, int days) async {
    try {
      final data = await _client
          .from('leave_balance')
          .select()
          .eq('employee_id', employeeId)
          .eq('year', DateTime.now().year)
          .eq('leave_type', leaveType)
          .maybeSingle();
      if (data == null) return false;
      final balance = LeaveBalanceModel.fromJson(data);
      return balance.remainingDays >= days;
    } catch (_) { return true; }
  }

  static Future<void> deductLeaveBalance(String employeeId, String leaveType, int days) async {
    try {
      final data = await _client
          .from('leave_balance')
          .select()
          .eq('employee_id', employeeId)
          .eq('year', DateTime.now().year)
          .eq('leave_type', leaveType)
          .maybeSingle();
      if (data != null) {
        final used = (data['used_days'] as int) + days;
        await _client.from('leave_balance').update({'used_days': used}).eq('id', data['id'] as String);
      }
    } catch (_) {}
  }

  // For leave type label display
  static const Map<String, String> leaveTypeLabels = {
    'sick': 'Sick Leave',
    'casual': 'Casual Leave',
    'annual': 'Annual Leave',
  };

  static Future<bool> hasReachedLeaveLimit({required int month, required int year}) async {
    try {
      final List<dynamic> data = await _client
          .from('leave_requests')
          .select('employee_id')
          .eq('status', 'pending')
          .gte('from_date', '$year-${month.toString().padLeft(2, '0')}-01')
          .lte('to_date', '$year-${month.toString().padLeft(2, '0')}-31');
      final List<dynamic> data2 = await _client
          .from('leave_requests')
          .select('employee_id')
          .eq('status', 'approved')
          .gte('from_date', '$year-${month.toString().padLeft(2, '0')}-01')
          .lte('to_date', '$year-${month.toString().padLeft(2, '0')}-31');
      final ids = [...data, ...data2].map((d) => d['employee_id'] as String).toSet();
      final settings = await getCompanySettings();
      return ids.length >= settings.maxEmployeesOnLeave;
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
