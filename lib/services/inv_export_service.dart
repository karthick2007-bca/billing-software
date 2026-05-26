import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvExportService {
  // ── Open PDF helper ───────────────────────────────────────────────────────
  static Future<void> _openPdf(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^\w\-]'), '_');
    final path = '${dir.path}/$safe.pdf';
    await File(path).writeAsBytes(bytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }

  // ── PDF ──────────────────────────────────────────────────────────────────
  static Future<void> exportPdf(String title, List<String> headers, List<List<String>> rows) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (ctx) => [
        pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
        ),
      ],
    ));
    await _openPdf(pdf, title);
  }

  // ── Excel ─────────────────────────────────────────────────────────────────
  static Future<String> exportExcel(String title, List<String> headers, List<List<String>> rows) async {
    final excel = Excel.createExcel();
    final sheet = excel[title.replaceAll('/', '-').replaceAll(' ', '_')];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final bytes = excel.encode();
    if (bytes != null) File(path).writeAsBytesSync(bytes);
    return path;
  }

  // ── Receipt PDF ───────────────────────────────────────────────────────────
  static Future<void> printSaleReceipt({
    required String receiptNo,
    required String saleDate,
    required String studentName,
    String studentClass = '',
    String studentSection = '',
    required String module,
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMode,
  }) async {
    final pdf = pw.Document();

    const schoolName    = 'SREE SOWDAMBIKA INTERNATIONAL SCHOOL';
    const schoolAddress = 'CHETTIKURICHI, ARUPPUKOTTAI';
    const primary       = PdfColor.fromInt(0xFF1E3A5F);

    final amountWords = _toWords(total.toInt());
    final cls = [studentClass, studentSection].where((s) => s.isNotEmpty).join(' - ');

    pw.Widget receiptBody() => pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [

        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(schoolName,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(schoolAddress, style: const pw.TextStyle(fontSize: 9)),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('$module RECEIPT',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primary)),
          ]),
        ]),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.black, thickness: 1),
        pw.SizedBox(height: 8),

        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Row(children: [
            pw.Text('Receipt No : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(receiptNo, style: const pw.TextStyle(fontSize: 9)),
          ]),
          pw.Row(children: [
            pw.Text('Date : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(saleDate, style: const pw.TextStyle(fontSize: 9)),
          ]),
        ]),
        pw.SizedBox(height: 10),

        _receiptRow('Name', studentName),
        pw.SizedBox(height: 6),
        if (cls.isNotEmpty) ...[
          _receiptRow('Class', cls),
          pw.SizedBox(height: 6),
        ],
        _receiptRow('Particulars', module),
        pw.SizedBox(height: 12),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _th('Item / Size'), _th('Qty'), _th('Rate (Rs.)'), _th('Amount (Rs.)'),
              ],
            ),
            ...items.map((it) {
              final name  = it['name']?.toString() ?? '';
              final size  = it['size']?.toString() ?? '';
              final label = size.isNotEmpty ? '$name ($size)' : name;
              final qty   = (it['quantity'] as num).toInt();
              final price = (it['unit_price'] as num).toDouble();
              final amt   = qty * price;
              return pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text('$qty', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(price.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(amt.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
              ]);
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(), pw.SizedBox(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(total.toStringAsFixed(2),
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),

        pw.Row(children: [
          pw.Text('Rupees : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text('$amountWords ONLY', style: const pw.TextStyle(fontSize: 9)),
        ]),
        pw.SizedBox(height: 6),

        pw.Row(children: [
          pw.Text('Payment Mode : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text(paymentMode.toUpperCase(), style: const pw.TextStyle(fontSize: 9)),
        ]),
        pw.SizedBox(height: 24),

        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(width: 80, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 3),
            pw.Text('Cashier', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ]),
      ]),
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => receiptBody(),
    ));

    await _openPdf(pdf, 'receipt_$receiptNo');
  }

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

  static pw.Widget _th(String t) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
  );
}
