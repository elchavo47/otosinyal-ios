import '../models/maintenance_reminder.dart';
import 'native_bridge.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// Bakım hatırlatıcıları için yerel bildirimler (yalnız iOS).
///
/// Her bakım kalemi için, bir sonraki bakım tarihinde saat 10:00'da tek bir
/// bildirim planlanır. Bildirim izni yalnızca kullanıcı bir bakımı "yapıldı"
/// olarak işaretlediğinde istenir; uygulama açılışında asla istenmez.
class MaintenanceNotificationService {
  MaintenanceNotificationService._();

  static String _idFor(MaintenanceReminder item) => 'maintenance_${item.id}';

  /// Mevcut izinle bildirimleri yeniden planlar. İzin yoksa hiçbir şey sormaz.
  static Future<void> sync(List<MaintenanceReminder> items) async {
    if (!NativeBridge.isSupported) return;
    if (await NativeBridge.notificationStatus() != 'authorized') return;
    await _schedule(items);
  }

  /// Kullanıcı bir bakımı tamamladığında çağrılır: gerekiyorsa izni bir kez
  /// sorar, ardından bildirimleri planlar.
  static Future<void> afterUserCompleted(List<MaintenanceReminder> items) async {
    if (!NativeBridge.isSupported) return;
    var status = await NativeBridge.notificationStatus();
    if (status == 'notDetermined') {
      status = await NativeBridge.requestNotificationPermission() ? 'authorized' : 'denied';
    }
    if (status != 'authorized') return;
    await _schedule(items);
  }

  static Future<void> _schedule(List<MaintenanceReminder> items) async {
    await NativeBridge.cancelNotifications(items.map(_idFor).toList());
    final now = DateTime.now();
    for (final item in items) {
      final due = item.nextDue;
      if (due == null) continue;
      final at = DateTime(due.year, due.month, due.day, 10);
      if (!at.isAfter(now)) continue;
      await NativeBridge.scheduleNotification(
        id: _idFor(item),
        title: tx('Bakım zamanı geldi'),
        body: tx('{0} için planlanan bakım zamanı geldi.', [item.displayTitle]),
        at: at,
      );
    }
  }
}
