# OtoSinyal V7.34 — Lamba Adaptasyonu + Ön Kontrol Kaldırma

- Kodlama sekmesindeki kullanıcıya dönük VAG ön kontrol kartı kaldırıldı.
- Kodlama sekmesine girerken çıkan ekstra güvenlik kapısı kaldırıldı; ekran doğrudan açılıyor.
- Yazma öncesi mevcut otomatik yedek, doğrulama ve rollback altyapısı korunuyor.
- Yeni `Lamba Adaptasyonu • 09 Merkezi Elektrik` girişi eklendi.
- MQB için Dış Aydınlatma (grup 7), İç Aydınlatma (grup 8) ve Gösterge Aydınlatması (grup 22) doğrudan açılabiliyor.
- Kurtarılan 81 MQB Lichtfunktion ve 48 Lasttyp/Lamba Tipi kaydı aranabilir katalog olarak eklendi.
- RecoveredVagAdaptationsScreen artık doğrudan belirli bir grup ve özel başlık ile açılabiliyor.
- Sürüm 7.34.0+40.

Not: Kurtarılan Lichtfunktion/Lasttyp katalogları gerçek eski uygulama verileridir. ECU yazma yalnızca mevcut recovered adaptation kayıtlarında DID/opsiyon bilgisi bulunan işlemlerde mevcut güvenli 0x22/0x2E motorunu kullanır; bilinmeyen Leuchte kanal adresleri tahmin edilerek yazılmaz.
