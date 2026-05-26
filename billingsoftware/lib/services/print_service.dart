import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' show TableHelper;

class PrintService {
  static const _schoolName    = 'SREE SOWDAMBIKA INTERNATIONAL SCHOOL';
  static const _schoolAddress = 'CHETTIKURICHI, ARUPPUKOTTAI';

  static const _primary      = PdfColor.fromInt(0xFF1E3A5F);
  static const _primaryLight = PdfColor.fromInt(0xFF2D5F9E);
  static const _success      = PdfColor.fromInt(0xFF059669);
  static const _danger       = PdfColor.fromInt(0xFFDC2626);
  static const _bg           = PdfColor.fromInt(0xFFF1F5F9);
  static const _border       = PdfColor.fromInt(0xFFE2E8F0);
  static const _textMuted    = PdfColor.fromInt(0xFF64748B);

  // ── Receipt ───────────────────────────────────────────────────────────────
  static Future<void> printReceipt(Map<String, dynamic> payment) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _schoolHeader('FEE RECEIPT'),
          pw.SizedBox(height: 12),
          _infoTable([
            ['Receipt No', payment['receipt_no'] ?? '', 'Date', payment['payment_date'] ?? ''],
            ['Student Name', payment['student_name'] ?? '', 'Admission No', payment['admission_no'] ?? ''],
            ['Class / Section', '${payment['class'] ?? ''} - ${payment['section'] ?? ''}', 'Parent Name', payment['parent_name'] ?? ''],
          ]),
          pw.SizedBox(height: 10),
          _sectionLabel('PAYMENT DETAILS'),
          _infoTable([
            ['Fee Type', payment['fee_type_name'] ?? '', 'Period', payment['period_label'] ?? ''],
            ['Challan No', payment['challan_no'] ?? '', 'Payment Mode', (payment['payment_mode'] ?? '').toUpperCase()],
            if (payment['cheque_no'] != null) ['Cheque No', payment['cheque_no'], 'Bank', payment['bank_name'] ?? ''],
          ]),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: _bg, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('AMOUNT PAID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _primary, fontSize: 12)),
              pw.Text('Rs. ${payment['amount_paid']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: _success)),
            ]),
          ),
          pw.SizedBox(height: 10),
          if (payment['collected_by_name'] != null)
            pw.Text('Collected by: ${payment['collected_by_name']}', style: pw.TextStyle(fontSize: 9, color: _textMuted)),
          pw.Spacer(),
          pw.Center(child: pw.Text('Thank you for your payment!', style: pw.TextStyle(fontSize: 10, color: _textMuted))),
        ],
      ),
    ));
    final pdfBytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(pdfBytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    }
  }

  // ── Challan (real school receipt style) ───────────────────────────────────
  static Future<void> printChallan(Map<String, dynamic> c) async {
    final pdf = pw.Document();

    pw.Widget receiptCopy() {
      final amount     = (c['net_amount'] ?? 0).toDouble();
      final amountStr  = amount.toStringAsFixed(2);
      final amountWords = _toWords(amount.toInt());
      final raw  = c['created_at'] as String? ?? DateTime.now().toIso8601String();
      final date = raw.contains('T') ? raw.split('T')[0] : raw.split(' ')[0];
      final receiptNo   = c['challan_no'] ?? '';
      final name        = c['student_name'] ?? '';
      final cls         = '${c['class'] ?? ''} - ${c['section'] ?? ''}';
      final particulars = '${c['fee_type_name'] ?? ''} - ${c['period_label'] ?? ''}';

      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [

          // ── School header ──
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_schoolName,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(_schoolAddress,
                style: const pw.TextStyle(fontSize: 9)),
            ])),
          ]),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.black, thickness: 1),
          pw.SizedBox(height: 8),

          // ── Receipt No + Date ──
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(children: [
              pw.Text('Receipt No : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(receiptNo, style: const pw.TextStyle(fontSize: 9)),
            ]),
            pw.Row(children: [
              pw.Text('Date : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(date, style: const pw.TextStyle(fontSize: 9)),
            ]),
          ]),
          pw.SizedBox(height: 10),

          // ── Name ──
          _receiptRow('Name', name),
          pw.SizedBox(height: 6),

          // ── Class ──
          _receiptRow('Class', cls),
          pw.SizedBox(height: 6),

          // ── Particulars ──
          _receiptRow('Particulars', particulars),
          pw.SizedBox(height: 12),

          // ── Amount table ──
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: pw.Text('Particulars',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: pw.Text('Amount (Rs.)',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(particulars, style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(amountStr,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
              ]),
              if ((c['discount_amount'] ?? 0) != 0)
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text('Discount', style: const pw.TextStyle(fontSize: 9))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text('- ${c['discount_amount']}',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right)),
                ]),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text('Total',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text(amountStr,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // ── Amount in words ──
          pw.Row(children: [
            pw.Text('Rupees : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text('$amountWords ONLY', style: const pw.TextStyle(fontSize: 9)),
          ]),
          pw.SizedBox(height: 24),

          // ── Signatures ──
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(width: 80, height: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 3),
              pw.Text('Cashier', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ]),
        ]),
      );
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => receiptCopy(),
    ));

    final pdfBytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(pdfBytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    }
  }

  // ── Backup Report (no cashier, all details fit in one page per class) ──────
  static Future<void> printBackup(String title, List<Map<String, dynamic>> rows) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';

    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final r in rows) {
      final cls = r['class']?.toString() ?? '';
      final sec = r['section']?.toString() ?? '';
      final key = cls.isNotEmpty || sec.isNotEmpty ? 'Class $cls - Sec $sec' : 'General';
      groups.putIfAbsent(key, () => []).add(r);
    }

    if (groups.isEmpty) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Center(child: pw.Text('No data available')),
      ));
    } else {
      for (final entry in groups.entries) {
        final groupLabel = entry.key;
        final groupRows  = entry.value;
        final totalBilled    = groupRows.fold<double>(0, (s, r) => s + (double.tryParse(r['total_billed']?.toString() ?? '0') ?? 0));
        final totalCollected = groupRows.fold<double>(0, (s, r) => s + (double.tryParse(r['total_paid']?.toString() ?? '0') ?? 0));
        final totalBalance   = groupRows.fold<double>(0, (s, r) => s + (double.tryParse(r['balance']?.toString() ?? '0') ?? 0));
        final paidCount      = groupRows.where((r) => r['fee_status'] == 'paid').length;
        final pendingCount   = groupRows.where((r) => r['fee_status'] == 'pending').length;

        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          build: (ctx) => [

            // ── School header ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(_schoolName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 1),
                  pw.Text(_schoolAddress, style: const pw.TextStyle(fontSize: 7.5)),
                ])),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _primary)),
                  pw.SizedBox(height: 2),
                  pw.Text('Date : $dateStr', style: const pw.TextStyle(fontSize: 7.5)),
                ]),
              ]),
            ),
            pw.SizedBox(height: 4),

            // ── Class/Section label + summary ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(color: _bg, border: pw.Border.all(color: _border, width: 0.5)),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Text(groupLabel,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _primary))),
                pw.Text('Total: ${groupRows.length}  |  Paid: $paidCount  |  Pending: $pendingCount',
                  style: pw.TextStyle(fontSize: 7.5, color: _textMuted)),
              ]),
            ),
            pw.SizedBox(height: 4),

            // ── Student table ──
            TableHelper.fromTextArray(
              headers: ['#', 'Adm No', 'Name', 'Parent Name', 'Phone', 'Billed', 'Paid', 'Balance', 'Status'],
              data: groupRows.asMap().entries.map((e) {
                final i = e.key + 1;
                final r = e.value;
                final bal = (double.tryParse(r['balance']?.toString() ?? '0') ?? 0);
                final status = r['fee_status']?.toString() ?? '';
                final statusLabel = status == 'paid' ? 'Paid' : status == 'pending' ? 'Pending' : 'No Challan';
                return [
                  '$i',
                  r['admission_no']?.toString() ?? '',
                  r['name']?.toString() ?? '',
                  r['parent_name']?.toString() ?? '',
                  r['parent_phone']?.toString() ?? '',
                  'Rs.${(double.tryParse(r['total_billed']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}',
                  'Rs.${(double.tryParse(r['total_paid']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}',
                  bal > 0 ? 'Rs.${bal.toStringAsFixed(0)}' : '-',
                  statusLabel,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 7),
              headerDecoration: const pw.BoxDecoration(color: _primary),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: _border, width: 0.4),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              oddRowDecoration: const pw.BoxDecoration(color: _bg),
              columnWidths: {
                0: const pw.FixedColumnWidth(16),
                1: const pw.FixedColumnWidth(46),
                2: const pw.FlexColumnWidth(2.2),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FixedColumnWidth(62),
                5: const pw.FixedColumnWidth(44),
                6: const pw.FixedColumnWidth(44),
                7: const pw.FixedColumnWidth(44),
                8: const pw.FixedColumnWidth(50),
              },
            ),
            pw.SizedBox(height: 4),

            // ── Summary totals row ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                border: pw.Border.all(color: _border, width: 0.4),
              ),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Students : ${groupRows.length}',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Row(children: [
                  pw.Text('Billed : Rs.${totalBilled.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _primary)),
                  pw.SizedBox(width: 10),
                  pw.Text('Collected : Rs.${totalCollected.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _success)),
                  pw.SizedBox(width: 10),
                  pw.Text('Balance : Rs.${totalBalance.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold,
                      color: totalBalance > 0 ? _danger : _success)),
                ]),
              ]),
            ),
          ],
        ));
      }
    }
    final pdfBytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(pdfBytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    }
  }

  // ── Report (class/section wise separate pages) ─────────────────────────
  static Future<void> printReport(String title, List<Map<String, dynamic>> rows, List<String> columns) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';

    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final r in rows) {
      final cls = r['class']?.toString() ?? '';
      final sec = r['section']?.toString() ?? '';
      final key = cls.isNotEmpty || sec.isNotEmpty ? 'Class $cls - Sec $sec' : 'General';
      groups.putIfAbsent(key, () => []).add(r);
    }

    if (groups.isEmpty) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Center(child: pw.Text('No data available')),
      ));
    } else {
      for (final entry in groups.entries) {
        final groupLabel = entry.key;
        final groupRows  = entry.value;
        final totalBalance = groupRows.fold<double>(0, (s, r) =>
            s + (double.tryParse(r['balance']?.toString() ?? '0') ?? 0));

        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => [
            // ── School header box ──
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(_schoolName,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text(_schoolAddress, style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(title,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primary)),
                  pw.SizedBox(height: 4),
                  pw.Text('Date : $dateStr', style: const pw.TextStyle(fontSize: 9)),
                ]),
              ]),
            ),
            pw.SizedBox(height: 8),

            // ── Class/Section label ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: _bg,
                border: pw.Border.all(color: _border),
              ),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(groupLabel,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primary)),
                pw.Text('Total Students : ${groupRows.length}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textMuted)),
              ]),
            ),
            pw.SizedBox(height: 8),

            // ── Data table ──
            TableHelper.fromTextArray(
              headers: columns.map((c) => c.replaceAll('_', ' ').toUpperCase()).toList(),
              data: groupRows.map((r) => columns.map((c) => r[c]?.toString() ?? '').toList()).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: _primary),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: _border, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              oddRowDecoration: const pw.BoxDecoration(color: _bg),
            ),
            pw.SizedBox(height: 8),

            // ── Summary row ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                border: pw.Border.all(color: _border, width: 0.5),
              ),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Records : ${groupRows.length}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                if (totalBalance > 0)
                  pw.Text('Total Balance Due : Rs. ${totalBalance.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _danger)),
              ]),
            ),
            pw.SizedBox(height: 28),

            // ── Cashier signature ──
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(width: 80, height: 0.5, color: PdfColors.black),
                pw.SizedBox(height: 3),
                pw.Text('Cashier', style: const pw.TextStyle(fontSize: 9)),
              ]),
            ]),
          ],
        ));
      }
    }
    final pdfBytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(pdfBytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static pw.Widget _schoolHeader(String docTitle) => pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      gradient: const pw.LinearGradient(colors: [_primary, _primaryLight]),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Row(children: [
      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(_schoolName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        pw.SizedBox(height: 3),
        pw.Text(_schoolAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
      ])),
      pw.Text(docTitle, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    ]),
  );

  static pw.Widget _sectionLabel(String label) => pw.Text(
    label,
    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textMuted, letterSpacing: 0.5),
  );

  static pw.Widget _receiptRow(String label, String value) => pw.Row(children: [
    pw.SizedBox(
      width: 80,
      child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ),
    pw.Text(': ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 1),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
      ),
      child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    )),
  ]);

  static pw.Widget _infoTable(List<List<String>> rows) => pw.Table(
    border: pw.TableBorder.all(color: _border, width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(1.5),
      1: const pw.FlexColumnWidth(2.5),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FlexColumnWidth(2.5),
    },
    children: rows.map((row) => pw.TableRow(children: [
      _labelCell(row[0]),
      _valueCell(row[1]),
      _labelCell(row.length > 2 ? row[2] : ''),
      _valueCell(row.length > 3 ? row[3] : ''),
    ])).toList(),
  );

  static pw.Widget _labelCell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    color: _bg,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textMuted)),
  );

  static pw.Widget _valueCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  static pw.Widget _tableCell(String text, {bool bold = false, bool italic = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : null,
        fontStyle: italic ? pw.FontStyle.italic : null,
        color: color,
      ),
    ),
  );

  // ── Number to words ───────────────────────────────────────────────────────
  static String _toWords(int n) {
    if (n == 0) return 'ZERO';
    const ones = ['', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN',
      'EIGHT', 'NINE', 'TEN', 'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN',
      'FIFTEEN', 'SIXTEEN', 'SEVENTEEN', 'EIGHTEEN', 'NINETEEN'];
    const tens = ['', '', 'TWENTY', 'THIRTY', 'FORTY', 'FIFTY',
      'SIXTY', 'SEVENTY', 'EIGHTY', 'NINETY'];

    String words(int num) {
      if (num == 0) return '';
      if (num < 20) return '${ones[num]} ';
      if (num < 100) return '${tens[num ~/ 10]} ${ones[num % 10]} ';
      return '${ones[num ~/ 100]} HUNDRED ${words(num % 100)}';
    }

    String result = '';
    if (n >= 10000000) { result += '${words(n ~/ 10000000)}CRORE '; n %= 10000000; }
    if (n >= 100000)   { result += '${words(n ~/ 100000)}LAKH ';   n %= 100000; }
    if (n >= 1000)     { result += '${words(n ~/ 1000)}THOUSAND '; n %= 1000; }
    result += words(n);
    return result.trim();
  }
}
