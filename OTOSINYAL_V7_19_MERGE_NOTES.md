# OTOSINYAL 7.19.0+18 — Safe Merge

Base: OTOSINYAL_V7_18_CARSCANNER_CONNECTION_RSSI

Korunan mevcut özellikler:
- VAG coding ekranı ve coding transaction/rollback servisleri
- Unit Scan / OEM module profile yapısı
- BLE RSSI/dBm gösterimi
- Wi-Fi TCP ELM327 provider
- USB OTG ELM327 auto-baud provider
- mevcut VIN/garage/diagnostic akışı

Eklenenler:
- AI Mekanik ekranı + HTTPS backend proxy örneği
- Mode 09 ECU Modules keşfi (0904 Calibration ID, 0906 CVN, 090A ECU Name)
- OBD komut latency/timeout tabanlı adaptör kalite puanı
- Geliştirilmiş OTOSINYAL PDF + JSON teşhis raporu
- DTC Mode 04 sonrası gerçek yeniden tarama doğrulaması
- DTC/Mode09 sırasında live polling çakışmasını önleyen exclusive operation kilidi
- Bozuk/eksik PID bitmap'lerinde gerçek PID probe fallback'i
- Fast lane RPM/Hız; medium sıcaklık/MAP; slow lane EGR/MAF/yakıt rayı/yakıt debisi/yağ/tork vb.

Not: Flutter SDK bu çalışma ortamında olmadığı için gerçek `flutter build` koşulamadı. Dart kaynaklarında denge/import/statik bütünlük kontrolleri yapıldı.
