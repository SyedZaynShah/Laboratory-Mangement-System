import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/navigation/nav_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              SizedBox(
                width: 220,
                child: KpiCard(title: 'Today Patients', value: '0'),
              ),
              SizedBox(
                width: 220,
                child: KpiCard(title: 'Pending Reports', value: '0'),
              ),
              SizedBox(
                width: 220,
                child: KpiCard(title: 'Completed Reports', value: '0'),
              ),
              SizedBox(
                width: 220,
                child: KpiCard(title: 'Revenue Today', value: '0'),
              ),
              SizedBox(
                width: 220,
                child: KpiCard(title: 'Total Tests', value: '0'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('New Patient'),
                onPressed: () {
                  ref
                      .read(currentSectionProvider.notifier)
                      .set(AppSection.patients);
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Reports'),
                onPressed: () {
                  ref
                      .read(currentSectionProvider.notifier)
                      .set(AppSection.reports);
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Settings'),
                onPressed: () {
                  ref
                      .read(currentSectionProvider.notifier)
                      .set(AppSection.settings);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
