import 'package:shared_preferences/shared_preferences.dart';
import 'native_bridge.dart';

/// App Store puan penceresini doğru anda, nadiren gösterir.
///
/// Kural: en az 3 başarılı tarama/kontrol tamamlandıktan sonra ve son
/// istekten en az 120 gün geçmişse. Apple ayrıca pencereyi yılda en fazla
/// 3 kez gösterir; ne zaman görüneceğine sistem karar verir.
class ReviewPromptService {
  ReviewPromptService._();

  static const _countKey = 'otosinyal_review_success_count';
  static const _lastKey = 'otosinyal_review_last_request';
  static const int _minSuccesses = 3;
  static const Duration _cooldown = Duration(days: 120);

  /// Başarılı bir tarama veya kontrol sonrası çağrılır. Hiç hata fırlatmaz.
  static Future<void> registerSuccessfulScan() async {
    if (!NativeBridge.isSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_countKey) ?? 0) + 1;
      await prefs.setInt(_countKey, count);
      if (count < _minSuccesses) return;

      final lastMs = prefs.getInt(_lastKey);
      final now = DateTime.now();
      if (lastMs != null && now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) < _cooldown) return;

      await prefs.setInt(_lastKey, now.millisecondsSinceEpoch);
      // Sonuç ekranı çizildikten sonra göster; tarama animasyonunun ortasına düşmesin.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await NativeBridge.requestReview();
    } catch (_) {}
  }
}
