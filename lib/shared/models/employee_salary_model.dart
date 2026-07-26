class EmployeeSalaryModel {
  final String id;
  final String employeeId;
  final double monthlySalary;
  final int workingDays;
  final int allowedLeaves;
  final DateTime effectiveFrom;
  final DateTime createdAt;

  EmployeeSalaryModel({
    required this.id,
    required this.employeeId,
    required this.monthlySalary,
    required this.workingDays,
    required this.allowedLeaves,
    required this.effectiveFrom,
    required this.createdAt,
  });

  factory EmployeeSalaryModel.fromJson(Map<String, dynamic> json) {
    return EmployeeSalaryModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      monthlySalary: (json['monthly_salary'] as num).toDouble(),
      workingDays: json['working_days'] as int? ?? 30,
      allowedLeaves: json['allowed_leaves'] as int? ?? 4,
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'monthly_salary': monthlySalary,
      'working_days': workingDays,
      'allowed_leaves': allowedLeaves,
      'effective_from': effectiveFrom.toIso8601String().split('T')[0],
    };
  }
}
