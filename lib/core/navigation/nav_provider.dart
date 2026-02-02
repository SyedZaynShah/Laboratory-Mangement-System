import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppSection {
  dashboard,
  patients,
  testsMaster,
  billing,
  samples,
  results,
  reports,
  settings,
}

class NavNotifier extends Notifier<AppSection> {
  @override
  AppSection build() => AppSection.dashboard;

  void set(AppSection section) => state = section;
}

final currentSectionProvider = NotifierProvider<NavNotifier, AppSection>(
  () => NavNotifier(),
);
