# OTOSİNYAL OBD2 v6.2 — çekirdek kontrol notu

Bu paket v6.1 üzerinde bilinen kritik regresyonlar tekrar taranarak hazırlandı.

- Classic bağlantıda zorunlu `bondDevice()` çağrısı yok.
- Classic bağlantı başarısız olduğunda uygulama otomatik PIN/eşleştirme zorlamaz; BLE seçeneğini önerir.
- Classic ve BLE komutları `\r` karakterini normalize ederek yalnız bir kez gönderir.
- `SharePlus` / `ShareParams` eski compile hataları yok; share_plus 10.x API kullanılıyor.
- Bluetooth UI ortak provider tipi `ScannableBluetoothProvider`; `ChangeNotifier.isScanning` compile regresyonu yok.
- Daha önceki `const` + runtime `withValues()` compile hatası bulunan bağlantı butonu düzeltilmiş durumda.
- DTC 03/07/0A ve Mode 04 sonrası yeniden doğrulama altyapısı korunmuştur.

Not: Bu çalışma ortamında Flutter SDK bulunmadığı için gerçek `flutter build apk` çalıştırılamadı. Gerçek ELM327/araç testi ayrıca gereklidir.
