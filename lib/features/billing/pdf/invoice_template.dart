import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfItem {
  final String description;
  final int qty;
  final int unitPriceCents;
  final int discountCents;
  final int lineTotalCents;
  final String? resultText;
  final num? resultNum;
  final bool? isAbnormal;
  InvoicePdfItem({
    required this.description,
    required this.qty,
    required this.unitPriceCents,
    required this.discountCents,
    required this.lineTotalCents,
    this.resultText,
    this.resultNum,
    this.isAbnormal,
  });
}

class InvoicePdfData {
  final String labName;
  final String? address;
  final String? phone;
  final String? email;
  final Uint8List? logoBytes;

  final String invoiceNo;
  final String status;
  final int issuedAtSec;
  final String patientName;
  final String? orderNumber;
  final String? referredBy;

  final List<InvoicePdfItem> items;
  final int headerDiscountCents;
  final int headerTaxCents;
  final int subtotalCents;
  final int totalCents;
  final int paidCents;
  final int balanceCents;

  InvoicePdfData({
    required this.labName,
    this.address,
    this.phone,
    this.email,
    this.logoBytes,
    required this.invoiceNo,
    required this.status,
    required this.issuedAtSec,
    required this.patientName,
    this.orderNumber,
    this.referredBy,
    required this.items,
    required this.headerDiscountCents,
    required this.headerTaxCents,
    required this.subtotalCents,
    required this.totalCents,
    required this.paidCents,
    required this.balanceCents,
  });
}

String _fmtMoney(int cents) => NumberFormat('###,##0.00').format(cents / 100.0);
String _fmtDate(int ts) => DateFormat(
  'yyyy-MM-dd HH:mm',
).format(DateTime.fromMillisecondsSinceEpoch(ts * 1000));

Future<Uint8List> buildInvoicePdf(InvoicePdfData data) async {
  final pdf = pw.Document();
  final baseColor = PdfColor.fromInt(0xFF0B1B3F);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        final subtotal = data.subtotalCents;
        final discount = data.headerDiscountCents;
        final net = subtotal - discount;
        final tax = data.headerTaxCents;
        final discPct = subtotal > 0 ? (discount * 100) / subtotal : 0.0;
        final taxPct = net > 0 ? (tax * 100) / net : 0.0;
        return pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header branding
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (data.logoBytes != null)
                        pw.Container(
                          width: 48,
                          height: 48,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(pw.MemoryImage(data.logoBytes!)),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            data.labName,
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: baseColor,
                            ),
                          ),
                          if ((data.address ?? '').isNotEmpty)
                            pw.Text(
                              data.address!,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          pw.Text(
                            [
                              data.phone,
                              data.email,
                            ].where((e) => (e ?? '').isNotEmpty).join(' · '),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Invoice',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('No: ${data.invoiceNo}'),
                      pw.Text('Issued: ${_fmtDate(data.issuedAtSec)}'),
                      pw.Text('Status: ${data.status}'),
                      if ((data.orderNumber ?? '').isNotEmpty)
                        pw.Text('Order: ${data.orderNumber}'),
                      if ((data.referredBy ?? '').isNotEmpty)
                        pw.Text('Referred by: ${data.referredBy}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),

              pw.Text('Bill To: ${data.patientName}'),
              pw.SizedBox(height: 12),

              // Items table
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(2),
                  5: pw.FlexColumnWidth(2),
                  6: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Test Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Result',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Abn',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Unit Price',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Line Discount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Line Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  for (final it in data.items)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(it.description),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            it.resultText ??
                                (it.resultNum != null
                                    ? it.resultNum.toString()
                                    : ''),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            (it.isAbnormal == null)
                                ? '—'
                                : ((it.isAbnormal == true) ? 'Yes' : 'No'),
                            style: pw.TextStyle(
                              color: (it.isAbnormal == true)
                                  ? PdfColors.red
                                  : PdfColors.black,
                              fontWeight: (it.isAbnormal == true)
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('${it.qty}'),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(_fmtMoney(it.unitPriceCents)),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(_fmtMoney(it.discountCents)),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(_fmtMoney(it.lineTotalCents)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 12),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 240,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _totalRow('Subtotal:', _fmtMoney(data.subtotalCents)),
                        _totalRow(
                          'Discount:',
                          '${_fmtMoney(data.headerDiscountCents)} (${discPct.toStringAsFixed(2)}%)',
                        ),
                        _totalRow(
                          'Tax:',
                          '${_fmtMoney(data.headerTaxCents)} (${taxPct.toStringAsFixed(2)}%)',
                        ),
                        pw.Divider(),
                        _totalRow('Total:', _fmtMoney(data.totalCents)),
                        _totalRow('Paid:', _fmtMoney(data.paidCents)),
                        _totalRow('Balance:', _fmtMoney(data.balanceCents)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'This is a computer-generated report',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  children: [
                    pw.SizedBox(height: 60),
                    pw.Container(
                      height: 1,
                      width: 160,
                      color: PdfColors.grey500,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Authorized Signatory',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _totalRow(String label, String value) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(label), pw.Text(value)],
  );
}
