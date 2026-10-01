# OTOSİNYAL OBD2 — Premium v5

- Son saha testinde çalışan BLE 4.0+ / ELM / ECU handshake çekirdeği korunmuştur.
- Uygulamadaki 39 markanın logosu `optimized.zip` içinden eşleştirilmiştir; gereksiz logolar pakete alınmamıştır.
- Ana sayfadaki jenerik araç renderı kaldırıldı; marka logosu + ECU/protokol/DTC/motor durumu teşhis özeti getirildi.
- Garaj kartları gerçek marka logosu kullanır.
- MIL metni kullanıcı dilinde `SORUN YOK / KONTROL GEREKLİ` oldu.
- VAG gelişmiş kartları tam/kısmi/ECU-özel olarak ayrıldı; tek gerçek değer geldi diye sahte yeşil tik göstermez.
- Göstergelere tick çizgileri, needle ve glow ile daha premium otomotiv görünümü eklendi.
- PDF raporu Inter Unicode fontlarını kullanır; Türkçe karakter bozulması giderildi.
- PDF tek snapshot üzerinden voltaj/MIL/protokol/VIN/rail/uyarı değerlerini kullanır; aynı raporda farklı zamanların değerleri karışmaz.
- Hakkında ekranındaki açık kaynak ibaresi kullanıcıya dönük ürün metniyle değiştirildi.
- VIN üzerinden mevcut WMI tablosuyla marka otomatik tahmini korunmuştur. Tam model/motor VIN'den her üreticide standart OBD ile garanti edilemez.

## Premium üyelik notu
Gerçek üyelik/ödeme doğrulaması backend veya Play Billing/App Store StoreKit entegrasyonu olmadan güvenli değildir. Bu pakette sahte premium kilidi eklenmedi; mevcut gelişmiş teşhis özellikleri çalışır halde bırakıldı.
