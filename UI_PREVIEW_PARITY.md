# OTOSİNYAL REDLINE v5 — Preview Parity

Bu sürümde kullanıcı tarafından verilen `docs/ui_reference_redline.png` görseli doğrudan tasarım referansı olarak kullanıldı.

- Ana başlık: hamburger + ortalanmış OTOSİNYAL wordmark + bildirim ikonu
- Ana sayfa: ince bağlantı şeridi, karanlık/kırmızı araç vitrini, Hız/RPM yarım kadranları, üç mini sensör kartı
- Dashboard: CANLI VERİLER/PERFORMANS sekme çizgisi ve iki sütun kompakt kart grid'i
- Bağlantı: başlık + kırmızı alt çizgili Bluetooth/Wi-Fi/USB sekmeleri
- Alt navigasyon: referanstaki gibi daha ince, beş ikonlu ve yalnız aktif sekmede kırmızı vurgu
- Garaj: daha kompakt başlık/kart ölçüleri ve kırmızı aktif araç vurgusu
- Derleme hatası: `const` bağlamında `withValues()` kullanımı kaldırıldı

OBD çekirdeği, DTC okuma/silme, Classic/BLE bağlantı ve araç profili davranışları korunmuştur.
