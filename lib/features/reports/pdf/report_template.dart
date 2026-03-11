import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportData {
  final String labName;
  final String? address;
  final String? phone;
  final String? email;
  final Uint8List? logoBytes;
  final String patientName;
  final String patientId;
  final List<PdfTestRow> rows;
  PdfReportData({
    required this.labName,
    this.address,
    this.phone,
    this.email,
    this.logoBytes,
    required this.patientName,
    required this.patientId,
    required this.rows,
  });
}

class PdfTestRow {
  final String name;
  final String value;
  final String unit;
  final String normalRange;
  final String? flag;
  PdfTestRow({
    required this.name,
    required this.value,
    required this.unit,
    required this.normalRange,
    this.flag,
  });
}

Future<Uint8List> buildReportPdf(PdfReportData data) async {
  final pdf = pw.Document();
  final baseColor = PdfColor.fromInt(0xFF0B1B3F);
  final accent = PdfColor.fromInt(0xFF2D8CFF);
  final lightGrey = PdfColor.fromInt(0xFFF2F2F2);
  final borderGrey = PdfColor.fromInt(0xFFCCCCCC);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
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
                      data: data.patientId,
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
                          child: infoCell('Patient No', data.patientId),
                        ),
                        pw.Expanded(child: infoCell('T/R No', data.patientId)),
                        pw.Expanded(
                          child: infoCell('Verification No', data.patientId),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: infoCell('Patient Name', data.patientName),
                        ),
                        pw.Expanded(child: infoCell('Registered On', '')),
                        pw.Expanded(child: infoCell('Reported On', '')),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(child: infoCell('Phone', data.phone ?? '')),
                        pw.Expanded(child: infoCell('Email', data.email ?? '')),
                        pw.Expanded(
                          child: infoCell('Address', data.address ?? ''),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),
              sectionTitle('DEPARTMENT OF SPECIAL CHEMISTRY'),
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
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1.4),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(2.2),
                  4: pw.FlexColumnWidth(0.9),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGrey),
                    children: [
                      _hdrCell('Test Name'),
                      _hdrCell('Result'),
                      _hdrCell('Unit'),
                      _hdrCell('Normal Range'),
                      _hdrCell('Flag'),
                    ],
                  ),
                  for (final r in data.rows)
                    pw.TableRow(
                      children: [
                        _bodyCell(r.name),
                        _bodyCell(r.value, bold: (r.flag ?? '').isNotEmpty),
                        _bodyCell(r.unit),
                        _bodyCell(r.normalRange),
                        _bodyCell(
                          r.flag ?? '',
                          color: r.flag == null
                              ? PdfColors.black
                              : (r.flag == 'HIGH'
                                    ? PdfColors.red
                                    : (r.flag == 'LOW'
                                          ? PdfColors.orange
                                          : accent)),
                          bold: (r.flag ?? '').isNotEmpty,
                        ),
                      ],
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

pw.Widget _hdrCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
  );
}

pw.Widget _bodyCell(String text, {PdfColor? color, bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        color: color ?? PdfColors.black,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
