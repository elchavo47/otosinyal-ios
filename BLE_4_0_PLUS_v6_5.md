# OTOSİNYAL v6.5 — BLE 4.0+

- Varsayılan bağlantı modu BLE 4.0+ yapıldı.
- Classic/SPP yalnız eski adaptörler için alternatif olarak bırakıldı.
- Mod değiştirirken diğer transport bağlantısı kapatılıyor.
- BLE tarafı GATT servis/karakteristik çiftini ATI ile doğrulamadan bağlantıyı hazır saymıyor.
- Bilinen Nordic UART ve FFE0/FFE1 BLE-seri profilleri öncelikli deneniyor.
- Android manifest'e Bluetooth LE donanım özelliği eklendi (Classic fallback'i korumak için required=false).
- Bağlantı ekranında BLE 4.0+ "ÖNERİLEN" olarak gösteriliyor.
