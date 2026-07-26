class AdvanceRequestModel {
  final String id;
  final String employeeId;
  final double amount;
  final String? reason;
  final String status;
  final String? adminId;
  final int? month;
  final int? year;
  final DateTime createdAt;

  AdvanceRequestModel({
    required this.id,
    required this.employeeId,
    required this.amount,
    this.reason,
    this.status = 'pending',
    this.adminId,
    this.month,
    this.year,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory AdvanceRequestModel.fromJson(Map<String, dynamic> json) {
    return AdvanceRequestModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      adminId: json['admin_id'] as String?,
      month: json['month'] as int?,
      year: json['year'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'amount': amount,
      'reason': reason,
      'status': status,
      'month': month,
      'year': year,
    };
  }
}
