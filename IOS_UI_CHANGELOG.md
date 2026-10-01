# OtoSinyal V7.39 iOS UI düzenlemeleri

- Kodlama sekmesine sadece bakmak için girerken çıkan uyarı kaldırıldı. ECU yazma ekranlarının kendi güvenlik akışları korunmuştur; her yazma yolunun ayrı test edilmesi gerekir.
- Ana ekranda sıcaklık ve voltaj kartları performans kısayolunun üstüne taşındı.
- Ana ekran, DTC, gelişmiş teşhis, bağlantı ve kodlama ekranlarındaki 11 pt altı sabit yazı boyutları en az 11 pt yapıldı. Küçük cihazlarda görsel taşma testi gereklidir.
- Bağlantı yardımında iOS BLE, Wi-Fi ve USB/Classic kısıtları açıklandı.

## Henüz yapılmamış işler
- ECU yanıt vermedi/destek yok/veri bekleniyor durumlarının bütün sensör kartlarında ayrıştırılması.
- Canlı PID kategorileri ve favori sensörler.
- Tüm ECU tarama sonuçlarında cevap vermeyen modüllerin eksiksiz gösterimi.
- Tüm kodlama yollarında eski/yeni değer, ECU, yedek ve geri okuma onaylarının tek tip olması.
- Gerçek iPhone, BLE/Wi-Fi adaptör ve araç üzerinde test; Xcode/Flutter build doğrulaması.
