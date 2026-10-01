# OTOSİNYAL v7 VIP Universal Transport & Diagnostic Lab

## Yeni altyapı

- Build düzeltmesi: ünite tarama ekranındaki eksik kapanış, OEM profil `isEmpty` çağrısı, Cupertino geçiş importu ve `file_picker` v11 API uyumu giderildi.

- Bluetooth Classic ve BLE korunarak Wi‑Fi TCP ELM327 ve Android USB OTG ELM327 taşıma katmanları eklendi.
- Tüm taşıma tipleri ortak `ObdConnection` arayüzü üzerinden aynı ECU teşhis motorunu kullanır.
- Wi‑Fi IP/port profilleri ve bağlantı durumu ekranı eklendi.
- FTDI, CDC, CP210x, PL2303 ve CH34x ailesi USB seri cihazları için OTG bağlantı akışı eklendi.
- Bağlantı provider yenilenmelerinde RX aboneliğini gereksiz yere yeniden kuran mimari düzeltildi.
- OTG USB için otomatik `9600 / 38400 / 115200` baud denemesi ve elle hız seçimi eklendi.

## Güvenli modül taraması

- Motor ECU, TCU, ABS/ESP, Airbag/SRS, BCM ve Gateway için seçilebilir tarama merkezi eklendi.
- Tarama yalnızca read-only Mode 01 ve DTC sorguları kullanır.
- Modül cevap vermeden “bulundu” olarak işaretlenmez.
- Tipik CAN ID listeleri keşif sonucu ile doğrulanır; araçta olmayan üniteye sahte sonuç yazılmaz.
- Marka kataloglarındaki ECU adresleri üzerinden CAN-UDS `22 F190` ve `19 02 FF` salt-okunur sorguları eklendi.
- DoIP/UDS için ISO 13400 routing activation ve tanımlı logical address profilleri eklendi; normal ELM Wi-Fi bağlantısı bozulmadan ayrı DoIP socket kullanılır.

## Veri yedekleme

- Garaj, aktif araç, sürüş geçmişi, DTC geçmişi, birimler, bağlantı modu, Wi-Fi profili ve USB baud tercihi uygulamaya özel şifreli `.otosinyal` yedeğine alınabilir.
- `.otosinyal` kapsayıcısı AES-256-GCM kullanır; magic başlığı, sürüm, boyut ve MAC doğrulanmadan provider'lara veri yazılmaz.
- Düz JSON, yanlış uzantılı veya dosya içeriği değiştirilmiş yedekler içe aktarma aşamasında reddedilir.
- Ham ECU/VIN flight recorder verisi normal kullanıcı yedeğine dahil edilmez; mevcut ayrıntılı log paylaşımı ayrı kalır.

## VIP arayüz

- Kırmızı tek renk tema yerine uzay siyahı, mor, cyan, pembe, mavi ve altın renk spektrumu.
- Bağlantı merkezinde cam kartlar, gradient yüzeyler, animasyonlu canlı durum noktası ve geçişli sekmeler.
- Modernize edilmiş alt navigasyon, butonlar, kart yüzeyleri ve sayfa geçişleri.
- Ünite tarama merkezi; seç, tara, gerçek cevap ID’sini ve DTC özetini gör.

## Sağlamlık / gizlilik

- Wi‑Fi/USB gönderim hataları artık komut zaman aşımı gibi gizlenmeden loglanır.
- Tam tarama hata aldığında kullanıcıya olay bildirimi gönderilir ve tarama durumu temizlenir.
- Teşhis log oturumu `SESSION_END` sonrasında kapatılır.
- Gizlilik ekranı, PDF/log paylaşımında VIN ve ham ECU cevaplarının seçilen uygulamaya gidebileceğini açıklar.
- Eski Flutter sayaç testi kaldırılıp gerçek VIP katalog testi eklendi.

## Sınır

“Tüm üniteler” seçilebilir hale getirildi; fakat üretici ve modelden bağımsız şekilde her modülün aynı CAN/DoIP adresi veya aynı UDS DID desteği yoktur. Cevap vermeyen modüller desteklenmiyor olarak gösterilir. Coding, flashing, security access ve aktüatör işlemleri bilerek kapalıdır.
