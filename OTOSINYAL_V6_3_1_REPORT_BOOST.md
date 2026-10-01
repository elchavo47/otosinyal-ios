# OTOSİNYAL 6.3.1+15
- PDF raporunda ECU'dan okunmuşsa Şase No (VIN) açık başlıkla gösterilir.
- PDF raporuna mevcutsa Turbo Hedef Basınç, Turbo Gerçek Basınç ve sapma eklendi.
- Turbo Takip Testi artık anlık basıncı her koşulda gösterir ama performans değerlendirmesini yalnızca yeterli RPM/yük/gaz koşulunda yapar.
- Tam gaz zorunlu değildir. Yetersiz yükte ölçüm gerçek veri olarak görünür ancak performans sonucu üretilmez.
- PDF'yi mevcut açık kaynak `pdf` paketiyle teknik olarak “kimsenin düzenleyemeyeceği” hale getirmek mümkün değildir. PDF permission bayrakları görüntüleyici tarafından uygulanır ve mutlak koruma değildir. Rapor metnine bütünlük uyarısı eklendi. Kriptografik imza/owner-permission için ayrıca imzalama/encryption çözümü gerekir.
