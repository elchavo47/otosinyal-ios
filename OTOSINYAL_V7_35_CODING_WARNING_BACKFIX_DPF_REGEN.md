# OTOSINYAL V7.35

- Kodlama sekmesine her girişte sorumluluk reddi + sahte/klon ELM327 uyarısı gösterilir.
- Eski kodlama preflight/adapter-quality zorunlu kapısı kaldırıldı; VIN/ECU doğrulama, backup, verify ve rollback korunur.
- Platform -> bölüm navigasyonunda Android/geri tuşu artık önce bölüm listesinə döner; doğrudan platform ekranına atlamaz.
- Doğrudan açılan özel alt ekranlarda (örn. Lamba Adaptasyonu -> Dış Aydınlatma) geri davranışı önceki route'a döner.
- Recovery DB'den doğrulanan VAG DPF servis rejenerasyonu eklendi:
  - MQB UID 10103, MLB-A4B9 UID 10188, PQ35 UID 10013
  - Engine ECU 7E0 / 7E8
  - DID 0316
  - Security Access code 27971 (legacy recovered 27 03 / 27 04 flow)
  - Start value 01
- DPF servis rejenerasyonu VAG Motor Lab altında görünür.
- Recovery DB'deki "Block DPF regenerations" (DID 0317) özelliği emisyon sistemini engellediği için UI'a eklenmedi.
