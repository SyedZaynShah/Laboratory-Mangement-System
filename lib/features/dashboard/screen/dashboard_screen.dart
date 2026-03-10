import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/navigation/nav_provider.dart';
import '../data/dashboard_providers.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String money(int cents) => NumberFormat('###,##0.00').format(cents / 100.0);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: Consumer(
                  builder: (context, ref, _) {
                    final v = ref.watch(patientsTodayProvider);
                    final s = v.asData?.value ?? 0;
                    return KpiCard(
                      title: 'Today Patients',
                      value: '$s',
                      icon: Icons.people_outline,
                    );
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: Consumer(
                  builder: (context, ref, _) {
                    final v = ref.watch(samplesCollectedTodayProvider);
                    final s = v.asData?.value ?? 0;
                    return KpiCard(
                      title: 'Samples Collected Today',
                      value: '$s',
                      icon: Icons.biotech_outlined,
                    );
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: Consumer(
                  builder: (context, ref, _) {
                    final v = ref.watch(ordersTodayProvider);
                    final s = v.asData?.value ?? 0;
                    return KpiCard(
                      title: 'Orders Today',
                      value: '$s',
                      icon: Icons.assignment_outlined,
                    );
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: Consumer(
                  builder: (context, ref, _) {
                    final v = ref.watch(pendingOrdersProvider);
                    final s = v.asData?.value ?? 0;
                    return KpiCard(
                      title: 'Pending Orders',
                      value: '$s',
                      icon: Icons.schedule_outlined,
                    );
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: Consumer(
                  builder: (context, ref, _) {
                    final v = ref.watch(completedOrdersProvider);
                    final s = v.asData?.value ?? 0;
                    return KpiCard(
                      title: 'Completed Orders',
                      value: '$s',
                      icon: Icons.check_circle_outline,
                    );
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: Consumer(
                  builder: (context, ref, _) {
                    final v = ref.watch(revenueTodayProvider);
                    final s = v.asData?.value ?? 0;
                    return KpiCard(
                      title: 'Revenue Today',
                      value: money(s),
                      icon: Icons.payments_outlined,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('New Patient'),
                onPressed: () {
                  ref
                      .read(currentSectionProvider.notifier)
                      .set(AppSection.patients);
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Reports'),
                onPressed: () {
                  ref
                      .read(currentSectionProvider.notifier)
                      .set(AppSection.reports);
                },
              ),
              FilledButton.icon(
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
