class LeaveBalanceModel {
  final String id;
  final String employeeId;
  final int year;
  final String leaveType;
  final int totalDays;
  final int usedDays;

  LeaveBalanceModel({
    required this.id,
    required this.employeeId,
    required this.year,
    required this.leaveType,
    required this.totalDays,
    required this.usedDays,
  });

  int get remainingDays => totalDays - usedDays;

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      year: json['year'] as int,
      leaveType: json['leave_type'] as String,
      totalDays: json['total_days'] as int,
      usedDays: json['used_days'] as int,
    );
  }
}
