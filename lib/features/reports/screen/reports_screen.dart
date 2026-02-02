import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../pdf/report_template.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Reports - Generate/Export/Print professional PDFs'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Preview Sample Report'),
            onPressed: () async {
              final data = PdfReportData(
                labName: 'Your Lab Name',
                patientName: 'John Doe',
                patientId: 'P-0001',
                rows: [
                  PdfTestRow(
                    name: 'Hemoglobin',
                    value: '13.4',
                    unit: 'g/dL',
                    normalRange: '13-17',
                    flag: null,
                  ),
                  PdfTestRow(
                    name: 'WBC',
                    value: '12.5',
                    unit: 'x10^3/uL',
                    normalRange: '4.0-11.0',
                    flag: 'HIGH',
                  ),
                  PdfTestRow(
                    name: 'Platelets',
                    value: '140',
                    unit: 'x10^3/uL',
                    normalRange: '150-400',
                    flag: 'LOW',
                  ),
                ],
              );
              await Printing.layoutPdf(onLayout: (_) => buildReportPdf(data));
            },
          ),
        ],
      ),
    );
  }
}
