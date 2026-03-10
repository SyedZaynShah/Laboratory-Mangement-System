import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation/nav_provider.dart';
import '../../features/dashboard/screen/dashboard_screen.dart';
import '../../features/dashboard/data/dashboard_providers.dart';
import '../../features/patients/ui/patients_list_screen.dart';
import '../../features/patients/data/patients_providers.dart';
import '../../features/orders/ui/orders_list_screen.dart';
import '../../features/orders/data/test_orders_providers.dart';
import '../../features/tests/ui/tests_list_screen.dart';
import '../../features/tests/data/tests_providers.dart';
import '../../features/billing/ui/invoices_list_screen.dart';
import '../../features/billing/data/invoices_providers.dart';
import '../../features/samples/screen/samples_screen.dart';
import '../../features/results/screen/results_screen.dart';
import '../../features/reports/screen/reports_screen.dart';
import '../../features/finance/ui/finance_screen.dart';
import '../../features/settings/screen/settings_screen.dart';
import '../../models/roles.dart';
import '../auth/auth_controller.dart';
import '../auth/app_lock_controller.dart';
import 'glass_surface.dart';
import 'gradient_text.dart';

class AppShell extends ConsumerWidget {
  final UserRole? role;
  const AppShell({super.key, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(currentSectionProvider);

    void refreshCurrentSection() {
      switch (section) {
        case AppSection.dashboard:
          ref.invalidate(patientsTodayProvider);
          ref.invalidate(ordersTodayProvider);
          ref.invalidate(pendingOrdersProvider);
          ref.invalidate(completedOrdersProvider);
          ref.invalidate(samplesCollectedTodayProvider);
          ref.invalidate(revenueTodayProvider);
          break;
        case AppSection.patients:
          ref.invalidate(patientsPageProvider(1));
          ref.invalidate(patientsSearchProvider(''));
          break;
        case AppSection.orders:
          ref.invalidate(testOrdersPageProvider(1));
          break;
        case AppSection.testsMaster:
          ref.invalidate(testsPageProvider(1));
          break;
        case AppSection.billing:
          ref.invalidate(invoicesPageProvider(1));
          break;
        case AppSection.finance:
          // Finance uses screen-local From/To; it has its own refresh button.
          break;
        case AppSection.samples:
        case AppSection.results:
        case AppSection.reports:
          // These screens have filters/IDs managed locally.
          break;
        case AppSection.settings:
          break;
      }
    }

    Widget buildContent() {
      Widget content;
      switch (section) {
        case AppSection.dashboard:
          content = const DashboardScreen();
          break;
        case AppSection.patients:
          content = const PatientsListScreen();
          break;
        case AppSection.orders:
          content = const OrdersListScreen();
          break;
        case AppSection.testsMaster:
          content = const TestsListScreen();
          break;
        case AppSection.billing:
          content = const InvoicesListScreen();
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
        case AppSection.finance:
          content = const FinanceScreen();
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
      _NavItem('Orders', Icons.assignment, AppSection.orders),
      if (role == UserRole.admin)
        _NavItem('Test Master', Icons.science, AppSection.testsMaster),
      _NavItem('Billing', Icons.receipt, AppSection.billing),
      _NavItem('Samples', Icons.biotech, AppSection.samples),
      _NavItem('Results', Icons.analytics, AppSection.results),
      _NavItem('Reports', Icons.picture_as_pdf, AppSection.reports),
      if (role == UserRole.admin || role == UserRole.accountant)
        _NavItem(
          'Finance',
          Icons.account_balance_wallet_outlined,
          AppSection.finance,
        ),
      _NavItem('Settings', Icons.settings, AppSection.settings),
    ];

    return Scaffold(
      body: Row(
        children: [
          GlassSurface(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.zero,
            blurSigma: 28,
            fillColor: const Color(0x14FFFFFF),
            borderColor: Colors.white12,
            boxShadow: const [],
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white.withOpacity(0.12)),
                ),
              ),
              child: NavigationRail(
                extended: true,
                minExtendedWidth: 220,
                selectedIndex: items.indexWhere((i) => i.section == section),
                onDestinationSelected: (idx) {
                  final dest = items[idx];
                  ref.read(currentSectionProvider.notifier).set(dest.section);
                },
                leading: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GradientText(
                    'LMS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                destinations: [
                  for (final i in items)
                    NavigationRailDestination(
                      icon: Icon(i.icon),
                      label: Container(
                        height: 40,
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: i.section == section
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(i.label),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E6BFF).withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                GlassSurface(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.zero,
                  blurSigma: 28,
                  fillColor: const Color(0x14FFFFFF),
                  borderColor: Colors.white12,
                  boxShadow: const [],
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                    ),
                    child: _TopBar(
                      title: items
                          .firstWhere((e) => e.section == section)
                          .label,
                      onRefresh: refreshCurrentSection,
                      onLock: () {
                        ref.read(appLockProvider.notifier).lock();
                      },
                      onLogout: () {
                        ref.read(authControllerProvider).signOut();
                      },
                    ),
                  ),
                ),
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
  final VoidCallback onRefresh;
  final VoidCallback onLock;
  final VoidCallback onLogout;
  const _TopBar({
    required this.title,
    required this.onRefresh,
    required this.onLock,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          GradientText(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onLock,
            icon: const Icon(Icons.lock),
            label: const Text('Lock App'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
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
