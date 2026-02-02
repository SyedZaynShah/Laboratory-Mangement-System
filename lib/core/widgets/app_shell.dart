import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation/nav_provider.dart';
import '../../features/dashboard/screen/dashboard_screen.dart';
import '../../features/patients/screen/patients_screen.dart';
import '../../features/tests_master/screen/tests_master_screen.dart';
import '../../features/billing/screen/billing_screen.dart';
import '../../features/samples/screen/samples_screen.dart';
import '../../features/results/screen/results_screen.dart';
import '../../features/reports/screen/reports_screen.dart';
import '../../features/settings/screen/settings_screen.dart';
import '../../models/roles.dart';

class AppShell extends ConsumerWidget {
  final UserRole? role;
  const AppShell({super.key, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(currentSectionProvider);

    Widget buildContent() {
      Widget content;
      switch (section) {
        case AppSection.dashboard:
          content = const DashboardScreen();
          break;
        case AppSection.patients:
          content = const PatientsScreen();
          break;
        case AppSection.testsMaster:
          content = const TestsMasterScreen();
          break;
        case AppSection.billing:
          content = const BillingScreen();
          break;
        case AppSection.samples:
          content = const SamplesScreen();
          break;
        case AppSection.results:
          content = const ResultsScreen();
          break;
        case AppSection.reports:
          content = const ReportsScreen();
          break;
        case AppSection.settings:
          content = const SettingsScreen();
          break;
      }
      return content;
    }

    final items = <_NavItem>[
      _NavItem('Dashboard', Icons.dashboard, AppSection.dashboard),
      _NavItem('Patients', Icons.people, AppSection.patients),
      if (role == UserRole.admin)
        _NavItem('Test Master', Icons.science, AppSection.testsMaster),
      _NavItem('Billing', Icons.receipt, AppSection.billing),
      _NavItem('Samples', Icons.biotech, AppSection.samples),
      _NavItem('Results', Icons.analytics, AppSection.results),
      _NavItem('Reports', Icons.picture_as_pdf, AppSection.reports),
      _NavItem('Settings', Icons.settings, AppSection.settings),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 220,
            selectedIndex: items.indexWhere((i) => i.section == section),
            onDestinationSelected: (idx) {
              final dest = items[idx];
              ref.read(currentSectionProvider.notifier).set(dest.section);
            },
            leading: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'LMS',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            destinations: [
              for (final i in items)
                NavigationRailDestination(
                  icon: Icon(i.icon),
                  label: Text(i.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: items.firstWhere((e) => e.section == section).label,
                ),
                const Divider(height: 1),
                Expanded(child: buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final AppSection section;
  _NavItem(this.label, this.icon, this.section);
}
