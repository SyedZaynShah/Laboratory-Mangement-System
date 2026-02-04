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

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                  pw.Text(
                    'Patient ID: ${data.patientId}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Patient: ${data.patientName}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(1),
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
                          'Test',
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
                          'Unit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Normal Range',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Flag',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  for (final r in data.rows)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(r.name),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(r.value),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(r.unit),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(r.normalRange),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            r.flag ?? '',
                            style: pw.TextStyle(
                              color: r.flag == null
                                  ? PdfColors.black
                                  : (r.flag == 'HIGH'
                                        ? PdfColors.red
                                        : (r.flag == 'LOW'
                                              ? PdfColors.orange
                                              : accent)),
                            ),
                          ),
                        ),
                      ],
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
                      style: pw.TextStyle(fontSize: 12),
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
