import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int?> kpiInitMs = ValueNotifier<int?>(null);
final ValueNotifier<int?> kpiWarmMs = ValueNotifier<int?>(null);

class WarmKpi {
  static Stopwatch? _sw;
  static void start() {
    _sw = Stopwatch()..start();
  }

  static void stopAndPublish() {
    final sw = _sw;
    if (sw != null && sw.isRunning) {
      sw.stop();
      kpiWarmMs.value = sw.elapsedMilliseconds;
      _sw = null;
    }
  }
}
