class PayrollRecordModel {
  final String id;
  final String employeeId;
  final int month;
  final int year;
  final double basicSalary;
  final double dailySalary;
  final int allowedLeave;
  final int usedLeave;
  final int extraLeave;
  final double deductionAmount;
  final double advanceAmount;
  final double grossSalary;
  final double finalSalary;
  final String status;
  final String? generatedBy;
  final DateTime createdAt;

  PayrollRecordModel({
    required this.id,
    required this.employeeId,
    required this.month,
    required this.year,
    required this.basicSalary,
    required this.dailySalary,
    required this.allowedLeave,
    required this.usedLeave,
    required this.extraLeave,
    required this.deductionAmount,
    this.advanceAmount = 0,
    this.grossSalary = 0,
    required this.finalSalary,
    required this.status,
    this.generatedBy,
    required this.createdAt,
  });

  bool get isDraft => status == 'draft';
  bool get isReviewed => status == 'reviewed';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';

  factory PayrollRecordModel.fromJson(Map<String, dynamic> json) {
    return PayrollRecordModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      month: json['month'] as int,
      year: json['year'] as int,
      basicSalary: (json['basic_salary'] as num).toDouble(),
      dailySalary: (json['daily_salary'] as num).toDouble(),
      allowedLeave: json['allowed_leave'] as int,
      usedLeave: json['used_leave'] as int,
      extraLeave: json['extra_leave'] as int? ?? 0,
      deductionAmount: (json['deduction_amount'] as num).toDouble(),
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0,
      grossSalary: (json['gross_salary'] as num?)?.toDouble() ?? 0,
      finalSalary: (json['final_salary'] as num).toDouble(),
      status: json['status'] as String? ?? 'draft',
      generatedBy: json['generated_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
