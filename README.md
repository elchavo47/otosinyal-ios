# OTOSİNYAL OBD2

OTOSİNYAL, ELM327 uyumlu adaptörlerle çalışan Flutter tabanlı araç teşhis ve canlı veri uygulamasıdır. v7 VIP sürümü; spektrum renkli cam arayüz, güvenli bağlantı katmanı ve seçmeli ünite tarama akışıyla yeniden tasarlanmıştır.

## Özellikler
- Bluetooth Classic ve BLE adaptör bağlantısı
- ECU iletişim doğrulaması ve otomatik OBD-II protokol seçimi
- Gerçek zamanlı hız, RPM, sıcaklık, voltaj ve desteklenen canlı PID'ler
- Stored / Pending / Permanent DTC taraması
- Mode 04 arıza silme ve silme sonrası yeniden tarama
- Araç garajı ve aktif araç profili
- VIN, sürüş geçmişi, birim tercihleri ve rapor paylaşımı
- Bluetooth Classic ve BLE yanında Wi‑Fi TCP OBD desteği
- Android OTG USB seri ELM327 bağlantısı ve tak-çıkar cihaz keşfi
- USB için otomatik 9600/38400/115200 baud denemesi ve manuel hız seçimi
- Motor, TCU, ABS/ESP, airbag/SRS, gövde/BCM ve gateway için seçmeli salt-okunur tarama
- Marka kataloğuna göre CAN-UDS ve uygun profillerde DoIP/UDS tanımlama ve DTC okuma
- Garaj, sürüş geçmişi, DTC geçmişi ve bağlantı ayarları için uygulamaya özel şifreli `.otosinyal` export/import yedeği
- `.otosinyal` dosyası AES-256-GCM ile korunur; dosya imzası, sürüm, boyut ve MAC doğrulanmadan geri yükleme yapılmaz
- Düz JSON veya uzantısı değiştirilmiş dosya OTOSİNYAL içe aktarma motoru tarafından reddedilir
- VIP neon-violet/cyan/pink cam teması, animasyonlu bağlantı merkezi ve durum kartları
- Ulaşılamayan veya araçta olmayan modüllerde sahte sonuç üretmeyen güvenli sonuç modeli

Değişiklik özeti: `OTOSINYAL_V7_VIP_CHANGELOG.md`

> Not: Generic OBD-II, esas olarak motor/emisyon ECU verilerini standartlaştırır. ABS, airbag ve üreticiye özel modüller için marka/protokol özel teşhis gerekir.

## Derleme
```bash
flutter clean
flutter pub get
flutter build apk --release
```

Play Store için:
```bash
flutter build appbundle --release
```

## Açık kaynak bildirimi
Bu proje, GPL-3.0 lisanslı ReDrive açık kaynak kod tabanından türetilmiş geliştirmeler içerir. Lisans ve kaynak kod yükümlülükleri için `LICENSE` dosyasına bakın. OTOSİNYAL marka kimliği, Türkçe teşhis akışı ve uygulamaya eklenen geliştirmeler bu fork üzerinde sürdürülmektedir.
