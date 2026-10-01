# OTOSİNYAL 6.0 Diagnostic Engine

Mevcut RC2 tabanı korunarak teşhis motoru genişletildi. GPL/AGPL veya lisansı uygun olmayan kaynak kodları doğrudan kopyalanmadı.

## Yeni teşhis akışı
- Tek tuş Tam Araç Taraması
- ELM/STN adaptör kimliği, açıklaması, protokolü ve voltaj sorgusu
- VIN/marka algılama
- Stored / Pending / Permanent DTC taraması
- MIL durumu
- Mode 01 supported PID discovery
- Mode 02 Freeze Frame: tetik DTC, RPM, hız, soğutma suyu, yük ve MAP
- SAE readiness özeti
- Mode 06 monitor cevabının güvenli yakalanması
- Gelişmiş canlı sensör yenilemesi
- Tarama sonucu kartı

## Güvenlik / doğruluk
- ECU'nun desteklemediği veri uydurulmaz.
- Manufacturer-specific DPF, hedef boost ve enjektör düzeltmesi generic OBD verisi gibi gösterilmez.
- ECU flashing, key adaptation, immobilizer/security access ve kontrol ünitesi kodlama consumer sürüme eklenmedi.
- Mode 06, doğrulanmış TID/CID tanımı olmadan sahte PASS/FAIL sonucuna çevrilmez.

## İncelenen referanslar
Delphi-OBD, AndrOBD, ObdGraphs, SwiftOBD2, Flutter-OBD2, OBD-Droid, libre-automotive-diagnostic, obd-master ve aa-torque.
