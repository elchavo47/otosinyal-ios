# OTOSİNYAL 6.1 OEM Diagnostics

Bu sürüm 6.0 diagnostic katmanını genişletir.

## Eklenenler
- Delphi-OBD kataloglarından VAG, BMW/MINI, Mercedes, Ford, Toyota/Lexus ve Hyundai/Kia/Genesis OEM katalogları asset olarak eklendi.
- Aynı üreticiler için OEM DTC katalogları eklendi; açıklamalar UI'da "doğrulama önerilir" notuyla kullanılır.
- UDS negatif yanıt (0x7F/NRC) parser'ı eklendi.
- ReadDataByIdentifier (0x22 / 0x62) read-only parser'ı eklendi.
- Standart UDS kimlik DID'leri: F190 VIN, F187 parça no, F189 yazılım sürümü, F18C ECU seri no, F191 donanım no.
- CAN responder discovery: ATH1 + Mode 01 probe ile yanıt veren CAN ID'leri görünür hale getirildi.
- OEM katalog eşleştirme VIN/algılanan marka üzerinden yapılır.
- OEM katalog ECU/DID/routine sayıları gelişmiş teşhis ekranında gösterilir.
- Mode 06 MID/TID sözlükleri uygulama asset'lerine eklendi ve runtime katalog servisi hazırlandı.
- Delphi UDS standard/NRC, Mode 06 ve VIN WMI veri dosyaları asset'lere eklendi.
- PDF raporuna OEM katalog, CAN responder ve desteklenen UDS kimlik bilgileri eklendi.

## Güvenlik / doğruluk
Delphi OEM DID kayıtlarının seçilen kataloglarda `verified=true` sayısı 0 olduğu için bu sürüm OEM DID'leri araca otomatik göndermez. Böylece katalogdaki deneysel/adresi doğrulanmamış bir DID yüzünden yanlış ECU sorgusu yapılmaz. Otomatik sorgular read-only standart UDS kimlik DID'leriyle sınırlıdır. Coding, flashing, key adaptation, security access ve actuator write işlemleri bilerek eklenmemiştir.
