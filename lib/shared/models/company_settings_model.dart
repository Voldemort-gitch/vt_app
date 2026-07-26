class CompanySettingsModel {
  final int id;
  final String companyName;
  final double officeLatitude;
  final double officeLongitude;
  final double allowedRadius;
  final String officeStartTime;
  final String officeEndTime;
  final int lateAfterMinutes;
  final int maxEmployeesOnLeave;
  final DateTime updatedAt;

  CompanySettingsModel({
    required this.id,
    required this.companyName,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.allowedRadius,
    required this.officeStartTime,
    required this.officeEndTime,
    required this.lateAfterMinutes,
    this.maxEmployeesOnLeave = 2,
    required this.updatedAt,
  });

  factory CompanySettingsModel.fromJson(Map<String, dynamic> json) {
    return CompanySettingsModel(
      id: json['id'] as int,
      companyName: json['company_name'] as String? ?? 'My Company',
      officeLatitude: (json['office_latitude'] as num?)?.toDouble() ?? 0.0,
      officeLongitude: (json['office_longitude'] as num?)?.toDouble() ?? 0.0,
      allowedRadius: (json['allowed_radius'] as num?)?.toDouble() ?? 100.0,
      officeStartTime: json['office_start_time'] as String? ?? '09:00',
      officeEndTime: json['office_end_time'] as String? ?? '18:00',
      lateAfterMinutes: json['late_after_minutes'] as int? ?? 15,
      maxEmployeesOnLeave: json['max_employees_on_leave'] as int? ?? 2,
      updatedAt: DateTime.parse(json['updated_at'] as String ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_name': companyName,
      'office_latitude': officeLatitude,
      'office_longitude': officeLongitude,
      'allowed_radius': allowedRadius,
      'office_start_time': officeStartTime,
      'office_end_time': officeEndTime,
      'late_after_minutes': lateAfterMinutes,
      'max_employees_on_leave': maxEmployeesOnLeave,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
