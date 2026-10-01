# OtoSinyal V7.33 — VAG Long Coding Recovery

- APK_VAG_KURTARMA recovery kaynaklarındaki 63 adet VAG `.backup.xx` listesi işlendi.
- 3884 adet read-only UDS 0x22 DID komutu platform/modül kataloğuna aktarıldı.
- Yeni VAG Long Coding ekranı eklendi.
- DID 0x0600 gerçek ECU'dan okunur ve byte/bit bazında düzenlenebilir.
- 09 BCM, 17 Instruments ve 5F Information Electronics için kontrollü 0x2E0600 yazma akışı eklendi.
- Yazma zinciri: live read -> kalıcı VIN/ECU yedeği -> extended session -> tester present -> write -> read-back verify -> otomatik rollback.
- ABS, Airbag, Engine, Transmission, Steering Assist ve A5 ADAS için ham long-coding write kilitli tutuldu.
- Recovery `.backup.xx` listeleri ile modül DID yedeği alınabilir ve JSON olarak paylaşılabilir.
- Kodlama geçmişi / geri alma ekranı eklendi; yalnız OtoSinyal'in daha önce yakaladığı VIN ve ECU kimlikli değerler geri yazılabilir.
- Mevcut 746 recovered adaptation kaydı ve güvenli read/write/verify akışı korunmuştur.

Not: SFD token üretme/bypass veya bilinmeyen seed-key algoritması eklenmemiştir. ECU yetki isterse mevcut güvenli akış erişim kodu olmadan yazmaz.
