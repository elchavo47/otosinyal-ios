# OTOSINYAL V7.24 — VAG MOTOR KURTARMA DURUMU

Eski VAG motoru yalnız MQB değil, kurtarma paketindeki tüm adaptation DB aileleri için çözüldü ve normalize edildi.

## Kurtarılan motor/veri aileleri

| Platform | Kayıt | 2-byte DID | Seçenekli | Security metadata | Özel pre/post |
|---|---:|---:|---:|---:|---:|
| MEB | 44 | 44 | 40 | 1 | 0 |
| MLB-A4B9 | 194 | 194 | 168 | 138 | 0 |
| MQB | 346 | 346 | 220 | 241 | 0 |
| MQB-CAMERA-FUSION | 4 | 0 | 4 | 4 | 4 |
| MQB-SWAP-CUSTOM-CODING | 1 | 0 | 0 | 1 | 1 |
| PQ26 | 80 | 80 | 33 | 62 | 0 |
| PQ26-NEW-RAPID-2020 | 62 | 62 | 42 | 39 | 0 |
| PQ35 | 15 | 15 | 3 | 14 | 0 |

**Toplam: 746 gerçek kurtarılmış adaptasyon/kodlama kaydı.**

## Motor bağlantısı

- ShiftStream2 dönüşümü yeniden oluşturuldu.
- Eski BSON payload yapısı parse ediliyor.
- Tüm kurtarılan DBler JSON asset kataloğuna dönüştürülüyor.
- UDS 0x22 okuma ve güvenli 0x2E yazma yolu OTOSINYAL providerına bağlı.
- Yazmadan önce ECU part/software okunuyor, mevcut değer yedekleniyor, yazma sonrası read-back verify yapılıyor ve işlem başarısızsa rollback zinciri kullanılıyor.
- Security Access veya özel pre/post prosedür isteyen kayıtlar katalogda kaybolmadan korunuyor; algoritması doğrulanmamış olanlar otomatik generic writer ile körlemesine çalıştırılmıyor.

## Kurtarılan kaynaklar

- `recovered_meb_adaptations_v1.json` — MEB (44 kayıt)
- `recovered_mlb_a4b9_adaptations_v1.json` — MLB-A4B9 (194 kayıt)
- `recovered_mqb_adaptations_v1.json` — MQB (346 kayıt)
- `recovered_mqb_camera_fusion_adaptations_v1.json` — MQB-CAMERA-FUSION (4 kayıt)
- `recovered_mqb_swap_custom_coding_adaptations_v1.json` — MQB-SWAP-CUSTOM-CODING (1 kayıt)
- `recovered_pq26_adaptations_v1.json` — PQ26 (80 kayıt)
- `recovered_pq26_new_rapid_2020_adaptations_v1.json` — PQ26-NEW-RAPID-2020 (62 kayıt)
- `recovered_pq35_adaptations_v1.json` — PQ35 (15 kayıt)
