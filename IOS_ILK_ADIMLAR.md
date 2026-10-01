# OtoSinyal: iOS ilk derleme (Apple hesabinda App ID mevcut)

- Apple Bundle ID: `com.aydworks.otosinyal` (Explicit).
- App Store Connect ilk surum: `1.0`; GitHub build de `1.0 (1)` uretiyor.
- Android surumu ve Android kimligi bu paketle degistirilmedi.

## Dosyalari projene yerlestirme

Bu guncelleme paketi yalnizca degisen/yeni dosyalari icerir. **Orijinal OtoSinyal ZIP'ini
acip, paketteki klasorleri ustune kopyalayarak dosyalari degistir.** Mevcut
`assets/fonts/` ve diger varliklar orijinal projende kalmali.

## GitHub Actions'da ilk iOS derlemesi

1. GitHub'da **Private** bir repo olustur. Flutter projesinin *klasor icerigini*
   (ozellikle `lib`, `ios`, `assets`, `pubspec.yaml` ve `.github`) repoya yukle.
   Tek bir ZIP dosyasini repoya yuklemek derleme icin yeterli degildir.
2. GitHub > repo > Actions > **iOS Build Check** > Run workflow. Main/master
   dalina yuklediginde is akisi otomatik olarak da calisir.
3. Derleme sonucunu Actions > ilgili run > **Compile iOS without signing**
   adimindan kontrol et. Basarili olsa dahi cikan Runner.app *imzasizdir*:
   TestFlight'a dogrudan yuklenemez ve iPhone'a normal sekilde kurulamaz.
4. Sonraki adim Apple Distribution sertifikasi + App Store provisioning profile
   olusturmak, bunlari GitHub Secrets'a kaydetmek, **imzali IPA** derlemek ve
   App Store Connect'e/TestFlight'a yuklemektir. Sertifika veya `.p8` anahtarini
   sohbetle ya da GitHub reposuna paylasma.

## Platform farklari

- iOS: BLE (`flutter_blue_plus`) ve Wi-Fi TCP baglantilarina odaklanildi.
- Bluetooth Classic/SPP (`flutter_blue_classic`) ve `usb_serial` mevcut
  eklentilerle Android'e ozeldir. iOS arayuzunde Classic devre disi birakildi,
  USB icin Android'e ozel bilgi mesaji korunuyor.
- Wifi adaptoru icin iPhone'un adaptore ait Wi-Fi agina bagli olmasi gerekir.
- Mevcut `Info.plist` Bluetooth ve yerel ag aciklamalarini iceriyor.

## Gercek iPhone testinden once

- BLE cihazinin GATT servis/karakteristik eslesmesini TestFlight'ta dogrula.
- Uyumluluk, derleme ve App Store incelemesi macOS CI sonucu gelmeden kesinlesmez.
