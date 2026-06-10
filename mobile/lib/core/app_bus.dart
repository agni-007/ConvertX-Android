import 'package:flutter/foundation.dart';
import '../models/preset.dart';

/// Cross-screen notifiers: the Presets tab applies a preset to the Convert
/// tab ("tap to apply", SRS §5.1) and screens react to tab switches.
class AppBus {
  AppBus._();

  static final appliedPreset = ValueNotifier<Preset?>(null);
  static final navIndex = ValueNotifier<int>(0);
}
