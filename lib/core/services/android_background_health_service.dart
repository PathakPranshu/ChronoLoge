import 'dart:io';

import 'package:flutter/services.dart';

import 'diagnostic_log_service.dart';

/// Reads Android's battery/background restrictions through a tiny native API.
class AndroidBackgroundHealthService {
  AndroidBackgroundHealthService._();

  static const _channel = MethodChannel('chronologe/background_health');

  // Checks whether Android is likely to delay or stop background tracking.
  static Future<AndroidBackgroundHealth> check({bool writeLog = false}) async {
    if (!Platform.isAndroid) return const AndroidBackgroundHealth.unsupported();

    try {
      final values = await _channel.invokeMapMethod<String, Object?>(
        'getStatus',
      );
      final health = AndroidBackgroundHealth(
        isSupported: true,
        ignoresBatteryOptimizations:
            values?['ignoresBatteryOptimizations'] as bool? ?? false,
        isBackgroundRestricted:
            values?['isBackgroundRestricted'] as bool? ?? false,
        standbyBucket: values?['standbyBucket'] as String? ?? 'unknown',
        deviceLabel: values?['deviceLabel'] as String? ?? 'Android device',
        sdkInt: values?['sdkInt'] as int?,
      );
      if (writeLog) {
        await DiagnosticLogService.record(
          'android',
          'Background health: device=${health.deviceLabel}, '
              'sdk=${health.sdkInt ?? 'unknown'}, '
              'batteryExempt=${health.ignoresBatteryOptimizations}, '
              'backgroundRestricted=${health.isBackgroundRestricted}, '
              'standbyBucket=${health.standbyBucket}',
        );
      }
      return health;
    } catch (error) {
      if (writeLog) {
        await DiagnosticLogService.record(
          'android',
          'Could not read Android background health',
          error: error,
        );
      }
      return const AndroidBackgroundHealth.unavailable();
    }
  }

  // Opens this app's system page where battery use can be made unrestricted.
  static Future<void> openAppBatterySettings() async {
    if (!Platform.isAndroid) return;
    await DiagnosticLogService.record(
      'android',
      'Opening app settings for battery configuration',
    );
    await _channel.invokeMethod<void>('openAppSettings');
  }
}

class AndroidBackgroundHealth {
  const AndroidBackgroundHealth({
    required this.isSupported,
    required this.ignoresBatteryOptimizations,
    required this.isBackgroundRestricted,
    required this.standbyBucket,
    required this.deviceLabel,
    required this.sdkInt,
  });

  const AndroidBackgroundHealth.unsupported()
    : isSupported = false,
      ignoresBatteryOptimizations = true,
      isBackgroundRestricted = false,
      standbyBucket = 'unsupported',
      deviceLabel = '',
      sdkInt = null;

  const AndroidBackgroundHealth.unavailable()
    : isSupported = true,
      ignoresBatteryOptimizations = false,
      isBackgroundRestricted = false,
      standbyBucket = 'unknown',
      deviceLabel = 'Android device',
      sdkInt = null;

  final bool isSupported;
  final bool ignoresBatteryOptimizations;
  final bool isBackgroundRestricted;
  final String standbyBucket;
  final String deviceLabel;
  final int? sdkInt;

  bool get needsAttention {
    return isSupported &&
        (!ignoresBatteryOptimizations ||
            isBackgroundRestricted ||
            standbyBucket == 'restricted' ||
            standbyBucket == 'rare');
  }

  String get label {
    if (!isSupported) return 'Managed by the operating system';
    if (isBackgroundRestricted || standbyBucket == 'restricted') {
      return 'Android is restricting background activity';
    }
    if (!ignoresBatteryOptimizations) {
      return 'Battery optimization may pause tracking';
    }
    if (standbyBucket == 'rare') {
      return 'Android has placed the app in deep standby';
    }
    return 'Background battery access looks good';
  }
}
