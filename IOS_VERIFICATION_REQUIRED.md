# OtoSinyal iOS — build ve gerçek cihaz doğrulaması

Yapılan kaynak değişiklikleri:
- Xcode Runner ve RunnerTests Bundle ID: com.aydworks.otosinyal / com.aydworks.otosinyal.RunnerTests.
- Runner hedefinin kaynaklarına PrivacyInfo.xcprivacy eklendi. Manifestte uygulama seviyesinde tracking=false, boş veri ve required-reason listeleri BAŞLANGIÇ beyanıdır; SDK ve uygulama veri akışları Xcode privacy report ile doğrulanmadan App Store beyanı olarak kullanılmamalıdır.
- iOS Bluetooth adapterState unauthorized durumunda izin verilmiş sayılmıyor. İlk izin istemi BLE taramasında CoreBluetooth tarafından tetiklenir.
- Önceki özel iOS ikonları ve sürüm 1.0.0+4 korundu.

YAPILMADI / TEST GEREKİR:
- macOS/Xcode ve iPhone olmadığı için IPA archive, signing, TestFlight, crash log ve gerçek BLE/Wi-Fi adaptör testleri yapılmadı.
- Vgate BLE GATT, canlı PID, VIN, DTC, çoklu ECU, bağlantı kopması, kodlama/DPF gerçek araçta doğrulanmadı. Yazma işlemlerini test edilmeden etkin kullanmayın.
- Wi-Fi için iOS Settings > Privacy & Security > Local Network izni ve ELM327 TCP erişimi cihazda denenmeli.
- Apple'ın listesinde Flutter, device_info_plus, file_picker, DKImagePickerController, DKPhotoGallery, geolocator_apple, share_plus gibi SDK'lar bulunabilir. İmzalı binary ve privacy manifest gerekliliklerini CI'da kullanılan gerçek çözümlenmiş sürümlere göre doğrulayın. Uygulama manifesti SDK manifestlerinin yerine geçmez.
- Apple App Store Connect privacy nutrition labels, encryption export compliance, gerçek TestFlight crash raporları ve OBD cihaz desteği manuel kontrol gerektirir.
- Bu ZIP GitHub'a kendiliğinden yüklenmedi; güncel kaynakla yeni Actions run başlatın. Workflow'un kendi bundle-id override'ı varsa onu da güncelleyin.
