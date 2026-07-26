import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../shared/models/payroll_record_model.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/models/salary_component_model.dart';
import '../../../shared/services/supabase_service.dart';

class PayslipGenerator {
  static Future<Uint8List> generate({
    required PayrollRecordModel record,
    required String employeeName,
    String? employeeCode,
    SalaryComponentModel? components,
    String? companyName,
    String? payslipNumber,
    String? bankName,
    String? accountNumber,
    Uint8List? logoBytes,
    Map<String, int>? attendanceSummary,
  }) async {
    final company = companyName ?? await _getCompanyName();
    final comp = components ?? await _getComponents(record.employeeId);
    final profile = await _getProfile(record.employeeId);
    final bank = bankName ?? profile?.bankName;
    final account = accountNumber ?? profile?.accountNumber;
    final monthName = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][record.month - 1];
    final slipNo = payslipNumber ?? 'PS-${record.year}-${record.month.toString().padLeft(2, '0')}-${employeeCode ?? 'EMP'}';

    final basicAmt = comp?.basicAmount(record.basicSalary) ?? record.basicSalary;
    final hraAmt = comp?.hraAmount(record.basicSalary) ?? 0;
    final convAmt = comp?.conveyanceAmount(record.basicSalary) ?? 0;
    final medAmt = comp?.medicalAmount(record.basicSalary) ?? 0;
    final specAmt = comp?.specialAmount(record.basicSalary) ?? 0;
    final gross = record.grossSalary > 0 ? record.grossSalary : record.basicSalary;
    final healthIns = comp?.healthInsurance ?? 0;
    final profTax = comp?.professionalTax ?? 200;
    final tdsAmt = comp?.tds ?? 0;

    Uint8List? logoFinal = logoBytes;
    if (logoFinal == null) {
      try {
        logoFinal = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
      } catch (_) {}
    }

    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final boldFont = pw.Font.ttf(boldData);
    final fontItalic = await _loadItalic();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return pw.Theme(
            data: pw.ThemeData.withFont(base: font, bold: boldFont, italic: fontItalic),
            child: pw.Column(
              children: [
                _buildHeader(company, monthName, record.year, slipNo, logoFinal),
                pw.SizedBox(height: 16),
                _buildEmployeeInfo(employeeName, employeeCode, bank, account),
                if (attendanceSummary != null) ...[
                  pw.SizedBox(height: 10),
                  _buildAttendanceSummary(attendanceSummary),
                  pw.SizedBox(height: 10),
                ],
                pw.SizedBox(height: 16),
                _buildSalaryRow(basicAmt, hraAmt, convAmt, medAmt, specAmt, gross,
                    healthIns, profTax, tdsAmt, record.deductionAmount, record.advanceAmount),
                pw.SizedBox(height: 16),
                _buildNetPay(record.finalSalary),
                pw.SizedBox(height: 12),
                _buildAmountInWords(record.finalSalary),
                pw.SizedBox(height: 16),
                _buildFooter(),
              ],
            ),
          );
        },
      ),
    );
    return doc.save();
  }

  static Future<pw.Font> _loadItalic() async {
    try {
      final data = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  static pw.Widget _buildHeader(String company, String month, int year, String slipNo, Uint8List? logoBytes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight,
          colors: [PdfColor.fromInt(0xFF2563EB), PdfColor.fromInt(0xFF1D4ED8)],
        ),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), width: 40, height: 40, fit: pw.BoxFit.contain)
              else
                pw.Container(
                  width: 40, height: 40,
                  child: pw.Center(child: pw.Text('VT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.white))),
                ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(company, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: PdfColors.white)),
                  pw.Text('Salary Slip', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xD9FFFFFF))),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('$month $year', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text('Payslip No: $slipNo', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xCCFFFFFF))),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEmployeeInfo(String name, String? code, String? bank, String? account) {
    final showBank = bank != null && bank.isNotEmpty;
    final showAccount = account != null && account.isNotEmpty;
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _label('Employee Name'),
                _value(name),
                pw.SizedBox(height: 10),
                _label('Employee ID'),
                _value(code ?? '—'),
              ],
            ),
          ),
          if (showBank || showAccount) pw.SizedBox(width: 24),
          if (showBank || showAccount)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (showBank) ...[
                    _label('Bank Name'),
                    _value(bank ?? ''),
                    pw.SizedBox(height: 10),
                  ],
                  if (showAccount) ...[
                    _label('Account Number'),
                    _value(account != null && account.length > 4 ? 'XXXX${account.substring(account.length - 4)}' : account ?? ''),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildAttendanceSummary(Map<String, int> summary) {
    final items = [
      ('Present', summary['present'] ?? 0, PdfColor.fromInt(0xFF10B981)),
      ('Late', summary['late'] ?? 0, PdfColor.fromInt(0xFFF59E0B)),
      ('Absent', summary['absent'] ?? 0, PdfColor.fromInt(0xFFDC2626)),
      ('Leave', summary['on_leave'] ?? 0, PdfColor.fromInt(0xFF3B82F6)),
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ATTENDANCE SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromInt(0xFF6B7280), letterSpacing: 1)),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: items.map((item) {
              return pw.Column(
                children: [
                  pw.Text(item.$2.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: item.$3)),
                  pw.Text(item.$1, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF9CA3AF))),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSalaryRow(
    double basic, double hra, double conv, double med, double spec, double gross,
    double healthIns, double profTax, double tds, double leaveDed, double advanceDed,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _tableCard('EARNINGS', [
          ('Basic Salary', basic, false),
          ('HRA', hra, false),
          ('Conveyance Allowance', conv, false),
          ('Medical Allowance', med, false),
          ('Special Allowance', spec, false),
          _sep(),
          ('Gross Salary', gross, true),
        ])),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _tableCard('DEDUCTIONS', [
          ('Health Insurance', healthIns, false),
          ('Professional Tax', profTax, false),
          ('TDS', tds, false),
          if (leaveDed > 0) ('Leave Deduction', leaveDed, false),
          if (advanceDed > 0) ('Advance Deduction', advanceDed, false),
          _sep(),
          ('Total Deduction', healthIns + profTax + tds + leaveDed + advanceDed, true),
        ])),
      ],
    );
  }

  static (String, double, bool) _sep() => ('', 0, false);

  static pw.Widget _tableCard(String title, List<(String, double, bool)> rows) {
    final color = title == 'EARNINGS' ? PdfColor.fromInt(0xFF2563EB) : PdfColor.fromInt(0xFFDC2626);
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromInt(0xFF374151), letterSpacing: 1)),
          pw.SizedBox(height: 10),
          for (final row in rows) ...[
            if (row.$1.isEmpty && row.$2 == 0)
              _divider()
            else ...[
              if (row != rows.first && row != rows.where((r) => r.$1.isNotEmpty || r.$2 != 0).skip(1).firstOrNull)
                _divider(),
              pw.SizedBox(height: 6),
              _row(row.$1, row.$2, row.$3, row.$3 ? color : null),
              pw.SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }

  static pw.Widget _row(String label, double amount, bool isTotal, PdfColor? accent) {
    final isEarningsTotal = isTotal && accent == PdfColor.fromInt(0xFF2563EB);
    final isDedTotal = isTotal && accent == PdfColor.fromInt(0xFFDC2626);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(
          fontSize: isTotal ? 11 : 10,
          fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isEarningsTotal ? PdfColor.fromInt(0xFF2563EB) : isDedTotal ? PdfColor.fromInt(0xFFDC2626) : PdfColor.fromInt(0xFF111827),
        )),
        pw.Text('₹ ${_fmt(amount)}', style: pw.TextStyle(
          fontSize: isTotal ? 12 : 10,
          fontWeight: pw.FontWeight.bold,
          color: isEarningsTotal ? PdfColor.fromInt(0xFF2563EB) : isDedTotal ? PdfColor.fromInt(0xFFDC2626) : PdfColor.fromInt(0xFF111827),
        )),
      ],
    );
  }

  static pw.Widget _divider() {
    return pw.Container(height: 1, color: PdfColor.fromInt(0xFFE5E7EB), margin: const pw.EdgeInsets.symmetric(vertical: 2));
  }

  static pw.Widget _buildNetPay(double netPay) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEFF6FF),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
        border: pw.Border.all(color: PdfColor.fromInt(0xFF2563EB), width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Text('NET PAY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromInt(0xFF6B7280), letterSpacing: 1)),
          pw.SizedBox(height: 2),
          pw.Text('₹ ${_fmt(netPay)}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 28, color: PdfColor.fromInt(0xFF1E3A5F))),
        ],
      ),
    );
  }

  static pw.Widget _buildAmountInWords(double amount) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text('Amount in Words: ${_amountInWords(amount)}',
          style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColor.fromInt(0xFF6B7280))),
    );
  }

  static pw.Widget _buildFooter() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.month - 1];
    final y = now.year;
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColor.fromInt(0xFFE5E7EB)),
        pw.SizedBox(height: 6),
        pw.Text('Generated on: $d $m $y  •  Generated by Visual Time',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF9CA3AF))),
        pw.SizedBox(height: 2),
        pw.Text('This is a computer generated payslip.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF9CA3AF), fontStyle: pw.FontStyle.italic)),
      ],
    );
  }

  // --------------- Helpers ---------------

  static pw.Widget _label(String text) {
    return pw.Text(text, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6B7280)));
  }

  static pw.Widget _value(String text) {
    return pw.Text(text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF111827)));
  }

  static Future<String> _getCompanyName() async {
    try {
      final settings = await SupabaseService.getCompanySettings();
      return settings.companyName;
    } catch (_) {
      return 'Visual Time';
    }
  }

  static Future<ProfileModel?> _getProfile(String employeeId) async {
    try {
      return await SupabaseService.getProfile(employeeId);
    } catch (_) {
      return null;
    }
  }

  static Future<SalaryComponentModel?> _getComponents(String employeeId) async {
    try {
      return await SupabaseService.getSalaryComponents(employeeId);
    } catch (_) {
      return null;
    }
  }

  static String _fmt(double amount) {
    final n = amount.round();
    final str = n.toString();
    final len = str.length;
    if (len <= 3) return str;
    final last3 = str.substring(len - 3);
    final rest = str.substring(0, len - 3);
    final buf = StringBuffer();
    int i = rest.length - 1;
    int c = 0;
    while (i >= 0) {
      if (c > 0 && c % 2 == 0) buf.write(',');
      buf.write(rest[i]);
      i--;
      c++;
    }
    return '${buf.toString().split('').reversed.join()},$last3';
  }

  static String _amountInWords(double amount) {
    final n = amount.round();
    if (n == 0) return 'Zero Rupees Only';
    return '${_numToWords(n)} Rupees Only';
  }

  static String _numToWords(int n) {
    if (n == 0) return '';
    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
                  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
                  'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    if (n < 20) return ones[n];
    if (n < 100) return '${tens[n ~/ 10]} ${_numToWords(n % 10)}'.trim();
    if (n < 1000) return '${ones[n ~/ 100]} Hundred ${_numToWords(n % 100)}'.trim();
    if (n < 100000) return '${_numToWords(n ~/ 1000)} Thousand ${_numToWords(n % 1000)}'.trim();
    if (n < 10000000) return '${_numToWords(n ~/ 100000)} Lakh ${_numToWords(n % 100000)}'.trim();
    return '${_numToWords(n ~/ 10000000)} Crore ${_numToWords(n % 10000000)}'.trim();
  }
}
