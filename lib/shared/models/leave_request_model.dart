class LeaveRequestModel {
  final int id;
  final String employeeId;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status;
  final String? adminId;
  final DateTime createdAt;

  LeaveRequestModel({
    required this.id,
    required this.employeeId,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = 'pending',
    this.adminId,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] as int,
      employeeId: json['employee_id'] as String,
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      reason: json['reason'] as String,
      status: json['status'] as String? ?? 'pending',
      adminId: json['admin_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'from_date': fromDate.toIso8601String().split('T')[0],
      'to_date': toDate.toIso8601String().split('T')[0],
      'reason': reason,
      'status': status,
    };
  }
}
