# OTOSİNYAL iOS Build 15 – OBD / VIN sağlamlaştırma

Bu sürüm Build 14 tabanlıdır. `obdium` ve `obd_vin_decoder` projeleri davranış referansı olarak incelenmiştir; GPL kaynak kodu doğrudan kopyalanmamıştır.

## Canlı veri
- ELM header modu `ATH1`: ECU/CAN frame sınırları korunur.
- 0100/0120/0140/... destek bitmap'i başarılıysa desteklenmeyen PID'ler canlı kuyruğa alınmaz.
- Bitmap başarısızsa runtime probe fallback'i devam eder.
- 0x20/0x40/0x60... bitmap devam PID'leri sensör sayısına dahil edilmez.
- RPM/hız/su/MAP gibi fast-lane gerçek cevapları da runtime-supported olarak işaretlenir.
- Advanced PID turu 5 döngüde bir yerine her döngüde bir sensör olacak şekilde hızlandırıldı; PID discovery tamamlanana kadar bekler.

## VIN
- Eski `vinMode09Supported=false` cache'i artık VIN sorgusunu kalıcı kapatmaz.
- Mode 09 için üç okuma stratejisi: headers+CAF1, headersız+CAF1, raw ISO-TP (ATH1+CAF0).
- `49 02 <record> ...` biçimindeki çok kayıtlı Mode 09 cevapları birleştirilir.
- Raw ISO-TP Mode 09 cevapları birleştirilir.
- UDS F190: VAG Gateway 710/77A, Engine 7E0/7E8, Cluster 714/77E ve genel 7Ex fallback adresleri denenir.
- UDS için CAF1, CAF0, explicit flow-control ve extended session fallback'leri vardır.
- VIN taraması sonrası bağlantının önceki `ATSPx` protokol seçimi geri yüklenir; Build 14'teki zorunlu `ATSP0` dönüşü kaldırıldı.
- VIN yalnız ISO uyumlu 17 karakter ise kabul edilir.

## Test ekleri
- OBDium örneği raw ISO-TP 0902 testi.
- ELM record-numbered 0902 testi.
- UDS F190 testi.
- VIN karakter doğrulama ve model yılı testi.
