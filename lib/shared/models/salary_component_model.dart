class SalaryComponentModel {
  final String id;
  final String employeeId;
  final double basicPct;
  final double hraPct;
  final double conveyancePct;
  final double medicalPct;
  final double specialPct;
  final double healthInsurance;
  final double professionalTax;
  final double tds;
  final DateTime createdAt;

  SalaryComponentModel({
    required this.id,
    required this.employeeId,
    this.basicPct = 45,
    this.hraPct = 17,
    this.conveyancePct = 3,
    this.medicalPct = 2,
    this.specialPct = 33,
    this.healthInsurance = 0,
    this.professionalTax = 200,
    this.tds = 0,
    required this.createdAt,
  });

  double get totalPct => basicPct + hraPct + conveyancePct + medicalPct + specialPct;

  double basicAmount(double salary) => (salary * basicPct / 100);
  double hraAmount(double salary) => (salary * hraPct / 100);
  double conveyanceAmount(double salary) => (salary * conveyancePct / 100);
  double medicalAmount(double salary) => (salary * medicalPct / 100);
  double specialAmount(double salary) => (salary * specialPct / 100);
  double grossAmount(double salary) => basicAmount(salary) + hraAmount(salary) + conveyanceAmount(salary) + medicalAmount(salary) + specialAmount(salary);
  double totalDeductions() => healthInsurance + professionalTax + tds;

  factory SalaryComponentModel.fromJson(Map<String, dynamic> json) {
    return SalaryComponentModel(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      basicPct: (json['basic_pct'] as num?)?.toDouble() ?? 45,
      hraPct: (json['hra_pct'] as num?)?.toDouble() ?? 17,
      conveyancePct: (json['conveyance_pct'] as num?)?.toDouble() ?? 3,
      medicalPct: (json['medical_pct'] as num?)?.toDouble() ?? 2,
      specialPct: (json['special_pct'] as num?)?.toDouble() ?? 33,
      healthInsurance: (json['health_insurance'] as num?)?.toDouble() ?? 0,
      professionalTax: (json['professional_tax'] as num?)?.toDouble() ?? 200,
      tds: (json['tds'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
  }
}
