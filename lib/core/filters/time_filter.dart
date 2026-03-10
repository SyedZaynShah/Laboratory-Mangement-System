import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimeFilterPreset {
  last7Days,
  last30Days,
  last90Days,
  last6Months,
  lastYear,
  customRange,
  specificDate,
}

@immutable
class TimeFilter {
  final TimeFilterPreset preset;
  final int? fromSec;
  final int? toSec;

  const TimeFilter._({
    required this.preset,
    required this.fromSec,
    required this.toSec,
  });

  factory TimeFilter.preset(TimeFilterPreset preset) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    DateTime? start;
    switch (preset) {
      case TimeFilterPreset.last7Days:
        start = end.subtract(const Duration(days: 6));
        break;
      case TimeFilterPreset.last30Days:
        start = end.subtract(const Duration(days: 29));
        break;
      case TimeFilterPreset.last90Days:
        start = end.subtract(const Duration(days: 89));
        break;
      case TimeFilterPreset.last6Months:
        start = DateTime(end.year, end.month - 5, end.day);
        break;
      case TimeFilterPreset.lastYear:
        start = DateTime(end.year - 1, end.month, end.day);
        break;
      case TimeFilterPreset.customRange:
      case TimeFilterPreset.specificDate:
        start = null;
        break;
    }

    return TimeFilter._(
      preset: preset,
      fromSec: start == null ? null : startAtDay(start),
      toSec: endAtDay(end),
    );
  }

  factory TimeFilter.customRange({required DateTime from, required DateTime to}) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return TimeFilter._(
      preset: TimeFilterPreset.customRange,
      fromSec: startAtDay(f),
      toSec: endAtDay(t),
    );
  }

  factory TimeFilter.specificDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return TimeFilter._(
      preset: TimeFilterPreset.specificDate,
      fromSec: startAtDay(d),
      toSec: endAtDay(d),
    );
  }

  static int startAtDay(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    return d.millisecondsSinceEpoch ~/ 1000;
  }

  static int endAtDay(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
    return d.millisecondsSinceEpoch ~/ 1000;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is TimeFilter &&
            other.preset == preset &&
            other.fromSec == fromSec &&
            other.toSec == toSec);
  }

  @override
  int get hashCode => Object.hash(preset, fromSec, toSec);
}

class TimeFilterNotifier extends Notifier<TimeFilter> {
  @override
  TimeFilter build() {
    return TimeFilter.preset(TimeFilterPreset.last30Days);
  }

  void setPreset(TimeFilterPreset preset) {
    state = TimeFilter.preset(preset);
  }

  void setCustomRange({required DateTime from, required DateTime to}) {
    state = TimeFilter.customRange(from: from, to: to);
  }

  void setSpecificDate(DateTime date) {
    state = TimeFilter.specificDate(date);
  }
}

final globalTimeFilterProvider = NotifierProvider<TimeFilterNotifier, TimeFilter>(
  () => TimeFilterNotifier(),
);
