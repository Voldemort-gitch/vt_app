class ProfileModel {
  final String id;
  final String name;
  final String employeeCode;
  final String? phone;
  final String role;
  final String? departmentId;
  final bool isActive;
  final String? avatarUrl;
  final String? bankName;
  final String? accountNumber;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.name,
    required this.employeeCode,
    this.phone,
    required this.role,
    this.departmentId,
    this.isActive = true,
    this.avatarUrl,
    this.bankName,
    this.accountNumber,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      employeeCode: json['employee_code'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      departmentId: json['department_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'employee_code': employeeCode,
      'phone': phone,
      'role': role,
      'department_id': departmentId,
      'is_active': isActive,
      'avatar_url': avatarUrl,
      'bank_name': bankName,
      'account_number': accountNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'phone': phone,
      'bank_name': bankName,
      'account_number': accountNumber,
    };
  }

  ProfileModel copyWith({
    String? name,
    String? phone,
    String? departmentId,
    bool? isActive,
    String? avatarUrl,
    String? bankName,
    String? accountNumber,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      employeeCode: employeeCode,
      phone: phone ?? this.phone,
      role: role,
      departmentId: departmentId ?? this.departmentId,
      isActive: isActive ?? this.isActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      createdAt: createdAt,
    );
  }
}
