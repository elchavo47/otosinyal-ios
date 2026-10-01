# OTOSINYAL V7.30 – Performance Visibility & Auto-Save

- Performans Testi ana ekranda hız/RPM kartlarının hemen altına belirgin kısa yol olarak taşındı.
- Canlı Teşhis ekranında Performans ayrı ve doğrudan görünen bölüm oldu; Gelişmiş araçlar expansion'ına bağlı değil.
- 0-100, 60-100, 80-120, 100-200 testlerinde başlangıç eşiği yukarı yönlü geçişle otomatik algılanır.
- Hedef hıza ulaşıldığında test otomatik durur.
- Sonuç SharedPreferences üzerinde otomatik kaydedilir; son 30 sonuç tarih/saat, süre, OBD/GPS maksimum hızlarıyla listelenir.
- Kullanıcı tamamlanan testten sonra başka preset seçip yeni test yapabilir.
- Hız/RPM TelemetryCard sayısal değeri Center ile geometrik merkeze sabitlendi.
- Güvenlik uyarısı/kapalı alan onayı korunmuştur.
