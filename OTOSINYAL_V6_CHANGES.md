# OTOSİNYAL OBD2 — Redline Diagnostic v4.0

- Referans Redline ekran diline yaklaştırılmış ana ekran, dashboard, garaj ve DTC UI.
- Dashboard yarım kadran göstergeleri ve Gelişmiş Teşhis sekmesi.
- SAE OBD-II destekleniyorsa: EGR komutu (01 2C), EGR sapması (01 2D), yakıt ray basıncı (01 23), ECU voltajı (01 42), dış sıcaklık (01 46), yakıt debisi (01 5E).
- MAP + barometrik basınçtan gerçek boost gauge hesabı.
- Akü / alternatör şarj analizi ve anormal değer uyarıları.
- Araç bazlı DTC tarama geçmişi (Stored/Pending/Permanent + MIL durumu).
- PDF teşhis/ekspertiz raporu oluşturma ve paylaşma.
- VAG gelişmiş modül bölümü: generic değerler gerçek okunur; ECU-özel UDS gerektiren DPF/enjektör/target boost verileri destek yoksa uydurulmaz.
- Play Store release imzası için android/key.properties desteği; key yoksa yerel release testinde debug signing fallback.

## v6.1 Bluetooth pairing fix
- Classic Bluetooth bağlantısında zorunlu `bondDevice()` kaldırıldı.
- Uygulama artık önce doğrudan RFCOMM bağlantısı dener; gereksiz PIN/şifre penceresi açmaz.
- Gerçekten bonding isteyen yalnız-Classic SPP adaptörlerde Android sistem gereksinimi devam edebilir; BLE bağlantılar PIN istemez.
