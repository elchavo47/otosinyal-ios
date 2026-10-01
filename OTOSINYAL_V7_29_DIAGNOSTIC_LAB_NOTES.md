# OTOSINYAL V7.29 — Diagnostic Lab

Bu sürüm V7.28 OBD diagnostic recovery üstüne aşağıdaki özellikleri ekler:

- ECU Modülleri ekranında Calibration ID, CVN, protokol ve CAN yanıt adresi birlikte gösterilir.
- Canlı Veri Otomatik Keşfi:
  - SAE Mode 01 PID bitmap + gerçek PID cevap doğrulaması.
  - VAG motor ECU için güvenli UDS 0x22 aday DID taraması.
  - Sadece ECU olumlu 0x62 cevabı veren DID'ler desteklenmiş sayılır.
- Grafik + Kayıt:
  - RPM, boost, rail pressure, MAF, EGT/katalizör sıcaklığı, yağ/su sıcaklığı, voltaj.
  - Aynı anda 4 metrik grafik.
  - 500 ms örnekleme ve CSV paylaşımı.
- VAG Motor Lab:
  - Turbo target/actual adayları, fuel rail, DPF regen, DPF EGT, diff pressure, soot %, soot g, regen mesafesi ve misfire sayaçları.
  - Desteklenmeyen veri için sahte/varsayılan değer üretmez.
- DTC açıklama motoru:
  - Muhtemel nedenler, kontrol sırası, ciddiyet ve sürüş tavsiyesi.
  - P0299/P0401/P0300 için genişletilmiş yerel açıklamalar + OEM katalog fallback.
- Freeze-frame:
  - DTC okumasından sonra otomatik Mode 02 snapshot okuması.
  - Tetikleyen DTC, RPM, hız, coolant, load ve MAP kartları.
- Araç Sağlık Skoru:
  - 0-100 skor; stored/pending/permanent DTC, MIL, readiness, sıcaklık ve şarj voltajına göre açıklanabilir kesintiler.
- Performans Testi:
  - 0-100 / 60-100 / 80-120 / 100-200.
  - GPS ve OBD hızını yan yana gösterir, farkı hesaplar.
  - GPS mevcutsa süreyi GPS hızından, yoksa OBD hızından alır.
  - Kapalı/güvenli alan onayı olmadan test başlatılmaz.

## Yeni bağımlılık

`geolocator: ^14.0.2`

Android ve iOS konum izin açıklamaları projeye eklenmiştir. İlk build öncesi Flutter normal şekilde `pub get` çalıştırmalıdır.
