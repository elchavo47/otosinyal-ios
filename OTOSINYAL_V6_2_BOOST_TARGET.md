# OTOSİNYAL 6.2 - ECU Canlı Turbo Hedefi

- SAE J1979 Mode 01 PID 70 Boost Pressure Control desteği eklendi.
- ECU destekliyorsa Commanded Boost Pressure A ve Boost Pressure Sensor A doğrudan ECU cevabından çözülür.
- Değerler absolute kPa olarak alınır; gösterge basıncı BARO çıkarılarak hesaplanır.
- Stage 1/2 araçlarda stok hedef tablosu kullanılmaz: ECU hangi hedefi bildiriyorsa o gösterilir.
- ECU PID 70 hedef verisini desteklemiyorsa hedef değer uydurulmaz.
- Gelişmiş Teşhis ekranında TURBO HEDEF ve TURBO GERÇEK ayrı kartlara ayrıldı.
- Hedef/gerçek sapması ve boost kontrol durumu gösterilir.
- OEM/UDS requested boost için yalnız doğrulanmış ECU profilleri ileride etkinleştirilecektir; doğrulanmamış DID otomatik gönderilmez.
