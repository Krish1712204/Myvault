import 'dart:io';
import 'package:flutter/widgets.dart';

/// Whether decorative, looping animations should run.
/// Off under `flutter test` (so pumpAndSettle can settle) and when the user asked the
/// system to reduce motion.
bool motionEnabled(BuildContext context) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
  return !MediaQuery.disableAnimationsOf(context);
}
