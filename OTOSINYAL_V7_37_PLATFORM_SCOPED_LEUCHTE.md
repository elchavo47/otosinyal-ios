# OtoSinyal V7.37 — Platform Scoped Leuchte Editor

## Düzeltilen akış
- Kodlama ana ekranındaki global **Lamba Adaptasyonu** kartı kaldırıldı.
- Özel Leuchte editörü artık yalnızca **MQB** platformu seçildikten sonra görünür.
- Yeni akış: `Kodlama ve Servis -> MQB -> 09 Merkezi Elektrik • Leuchte Editörü`.
- MQB Leuchte editörü recovery paketindeki `MQB_LightConfiguration` / `MQB_LightConfigurationCoding`, `mqb_light_functions` ve `mqb_light_types` kanıtlarına göre sınırlandırıldı.
- MQB editörü Leuchte 0–34, DID 0550–0572 mapping'ini kullanmaya devam eder.

## Platform uyumluluğu
- **MQB:** özel Leuchte editörü AÇIK (doğrulanmış özel light configuration motoru + kataloglar mevcut).
- **PQ35:** özel MQB Leuchte editörü YOK; yalnızca PQ35 recovery/adaptation kataloğu gösterilir.
- **PQ26 / PQ26-NEW-RAPID-2020:** özel MQB Leuchte editörü YOK; kendi recovery/adaptation katalogları gösterilir.
- **MLB-A4B9:** özel MQB Leuchte editörü YOK; kendi recovery/adaptation kataloğu gösterilir.
- **MEB:** özel MQB Leuchte editörü YOK.
- **MQB-CAMERA-FUSION / MQB-SWAP-CUSTOM-CODING:** bunlar özel alt kataloglardır; Leuchte editörü burada ayrıca gösterilmez. Ana MQB platformundan erişilir.

## Neden
Recovery DLL'de özel ışık yapılandırma sınıfları `MQB_LightConfiguration` ve `MQB_LightConfigurationCoding` olarak bulunuyor. Eşleşen `mqb_light_functions` ve `mqb_light_types` kaynakları da yalnızca MQB adına mevcut. PQ35/PQ26/MLB için aynı özel Leuchte mapping sınıfı doğrulanamadığından MQB DID haritası bu platformlara taşınmadı.
