class AttendanceModel {
  final int id;
  final String employeeId;
  final DateTime attendanceDate;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final int workingMinutes;
  final String status;
  final String? remarks;
  final DateTime createdAt;

  AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.attendanceDate,
    this.checkIn,
    this.checkOut,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.workingMinutes = 0,
    this.status = 'present',
    this.remarks,
    required this.createdAt,
  });

  bool get hasCheckedIn => checkIn != null;
  bool get hasCheckedOut => checkOut != null;
  bool get isDoneToday => hasCheckedIn && hasCheckedOut;

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as int,
      employeeId: json['employee_id'] as String,
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      checkIn: json['check_in'] != null
          ? DateTime.parse(json['check_in'] as String)
          : null,
      checkOut: json['check_out'] != null
          ? DateTime.parse(json['check_out'] as String)
          : null,
      checkInLatitude: (json['check_in_latitude'] as num?)?.toDouble(),
      checkInLongitude: (json['check_in_longitude'] as num?)?.toDouble(),
      checkOutLatitude: (json['check_out_latitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['check_out_longitude'] as num?)?.toDouble(),
      workingMinutes: json['working_minutes'] as int? ?? 0,
      status: json['status'] as String? ?? 'present',
      remarks: json['remarks'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
