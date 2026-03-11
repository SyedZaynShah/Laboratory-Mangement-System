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
  final lightGrey = PdfColor.fromInt(0xFFF2F2F2);
  final borderGrey = PdfColor.fromInt(0xFFCCCCCC);

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
        final infoBorder = pw.BoxDecoration(
          border: pw.Border.all(color: borderGrey, width: 0.8),
        );

        pw.Widget infoCell(String label, String value) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderGrey, width: 0.6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  flex: 7,
                  child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
            ),
          );
        }

        pw.Widget sectionTitle(String text) {
          return pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: lightGrey,
              border: pw.Border.all(color: borderGrey, width: 0.8),
            ),
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          );
        }

        return pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 7,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (data.logoBytes != null)
                          pw.Container(
                            width: 54,
                            height: 54,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(pw.MemoryImage(data.logoBytes!)),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'AL-MUNEER',
                                style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: baseColor,
                                ),
                              ),
                              pw.Text(
                                'Clinical Laboratory',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: baseColor,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Exclusively Automated',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.red,
                                ),
                              ),
                              if ((data.address ?? '').isNotEmpty)
                                pw.Text(
                                  data.address!,
                                  style: const pw.TextStyle(fontSize: 8.5),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Container(
                    width: 86,
                    alignment: pw.Alignment.topRight,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: data.invoiceNo,
                      width: 86,
                      height: 86,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(height: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 8),

              pw.Container(
                decoration: infoBorder,
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: infoCell('Invoice No', data.invoiceNo),
                        ),
                        pw.Expanded(
                          child: infoCell('Order No', data.orderNumber ?? ''),
                        ),
                        pw.Expanded(child: infoCell('Status', data.status)),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: infoCell('Patient Name', data.patientName),
                        ),
                        pw.Expanded(
                          child: infoCell(
                            'Issued On',
                            _fmtDate(data.issuedAtSec),
                          ),
                        ),
                        pw.Expanded(
                          child: infoCell('Referred By', data.referredBy ?? ''),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(child: infoCell('Phone', data.phone ?? '')),
                        pw.Expanded(child: infoCell('Email', data.email ?? '')),
                        pw.Expanded(
                          child: infoCell('Verification No', data.invoiceNo),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),
              sectionTitle('INVOICE DETAILS'),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder(
                  top: pw.BorderSide(color: borderGrey, width: 0.8),
                  bottom: pw.BorderSide(color: borderGrey, width: 0.8),
                  left: pw.BorderSide(color: borderGrey, width: 0.8),
                  right: pw.BorderSide(color: borderGrey, width: 0.8),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300),
                  verticalInside: pw.BorderSide(color: PdfColors.grey300),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.4),
                  1: pw.FlexColumnWidth(1.8),
                  2: pw.FlexColumnWidth(0.9),
                  3: pw.FlexColumnWidth(0.9),
                  4: pw.FlexColumnWidth(1.5),
                  5: pw.FlexColumnWidth(1.6),
                  6: pw.FlexColumnWidth(1.6),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGrey),
                    children: [
                      _hdrCell('Test Name'),
                      _hdrCell('Result'),
                      _hdrCell('Abn'),
                      _hdrCell('Qty'),
                      _hdrCell('Unit Price'),
                      _hdrCell('Discount'),
                      _hdrCell('Total'),
                    ],
                  ),
                  for (final it in data.items)
                    pw.TableRow(
                      children: [
                        _bodyCell(it.description),
                        _bodyCell(
                          it.resultText ??
                              (it.resultNum != null
                                  ? it.resultNum.toString()
                                  : ''),
                        ),
                        _bodyCell(
                          (it.isAbnormal == null)
                              ? '—'
                              : ((it.isAbnormal == true) ? 'Yes' : 'No'),
                          color: (it.isAbnormal == true)
                              ? PdfColors.red
                              : PdfColors.black,
                          bold: it.isAbnormal == true,
                          alignRight: false,
                        ),
                        _bodyCell('${it.qty}', alignRight: true),
                        _bodyCell(
                          _fmtMoney(it.unitPriceCents),
                          alignRight: true,
                        ),
                        _bodyCell(
                          _fmtMoney(it.discountCents),
                          alignRight: true,
                        ),
                        _bodyCell(
                          _fmtMoney(it.lineTotalCents),
                          alignRight: true,
                        ),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 260,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderGrey, width: 0.8),
                    ),
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
                        pw.Divider(color: PdfColors.grey400),
                        _totalRow('Total:', _fmtMoney(data.totalCents)),
                        _totalRow('Paid:', _fmtMoney(data.paidCents)),
                        _totalRow('Balance:', _fmtMoney(data.balanceCents)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Container(height: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Electronically Verified Report. No Signature(s) Required',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber}/${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  border: pw.Border.all(color: borderGrey, width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        (data.phone ?? '').trim(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        (data.address ?? '').trim(),
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
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

pw.Widget _hdrCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
  );
}

pw.Widget _bodyCell(
  String text, {
  bool alignRight = false,
  PdfColor? color,
  bool bold = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Align(
      alignment: alignRight
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          color: color ?? PdfColors.black,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ),
  );
}
