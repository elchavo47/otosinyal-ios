import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS'taki küçük yerel köprü (ios/Runner/AppDelegate.swift → OtoSinyalNative).
///
/// Yalnız iOS'ta çalışır; diğer platformlarda tüm çağrılar sessizce
/// etkisiz döner. Hiçbir çağrı hata fırlatmaz.
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('otosinyal/native');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> requestReview() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('requestReview');
    } catch (_) {}
  }

  /// 'authorized', 'denied' veya 'notDetermined'.
  static Future<String> notificationStatus() async {
    if (!isSupported) return 'denied';
    try {
      return await _channel.invokeMethod<String>('notificationStatus') ?? 'notDetermined';
    } catch (_) {
      return 'denied';
    }
  }

  static Future<bool> requestNotificationPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('scheduleNotification', <String, Object>{
            'id': id,
            'title': title,
            'body': body,
            'epochMs': at.millisecondsSinceEpoch,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelNotifications(List<String> ids) async {
    if (!isSupported || ids.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('cancelNotifications', <String, Object>{'ids': ids});
    } catch (_) {}
  }
}
