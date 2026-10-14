import '../models/vag_coding.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// OTOSİNYAL'ın ilk nesil MQB kataloğu.
///
/// Sayısal konumu doğrulanan long-coding bitleri okunabilir. Adaptation kanal
/// adları kataloglanır ancak ECU/ASAM bazında sayısal DID eşleşmesi olmadan
/// kesinlikle yazılmaz.
class MqbCodingRecipes {
  static const supportedVehicles = <String>{
    'vw-golf7', 'vw-passatb8', 'skoda-octavia3', 'seat-leon3', 'audi-a3-8v',
  };

  static final recipes = <VagCodingRecipe>[
    VagCodingRecipe(id:'needle_sweep',title:tx('İbre Selamlama'),description:tx('Kontak açılışında ibrelerin test turu yapması'),category:tx('Gösterge'),moduleKey:'17',moduleName:tx('17 • Gösterge Paneli'),requestId:'714',responseId:'77E',kind:CodingRecipeKind.longCodingBit,did:'0600',byteIndex:1,bitIndex:0,vehicleIds:supportedVehicles,writeEnabled:false),
    VagCodingRecipe(id:'lap_timer',title:'Lap Timer',description:tx('Gösterge menüsünde tur zamanı ekranı'),category:tx('Gösterge'),moduleKey:'17',moduleName:tx('17 • Gösterge Paneli'),requestId:'714',responseId:'77E',kind:CodingRecipeKind.longCodingBit,did:'0600',byteIndex:1,bitIndex:3,vehicleIds:supportedVehicles,writeEnabled:false),
    VagCodingRecipe(id:'refill_quantity',title:tx('Depoya Eklenecek Yakıt'),description:tx('Gösterge ekranında dolum miktarı önerisi'),category:tx('Gösterge'),moduleKey:'17',moduleName:tx('17 • Gösterge Paneli'),requestId:'714',responseId:'77E',kind:CodingRecipeKind.longCodingBit,did:'0600',byteIndex:10,bitIndex:4,vehicleIds:supportedVehicles,writeEnabled:false),
    VagCodingRecipe(id:'comfort_blink',title:tx('Konfor Sinyali'),description:tx('Dokunmatik sinyal tekrar sayısını ayarlar'),category:tx('Aydınlatma'),moduleKey:'09',moduleName:tx('09 • Merkezi Elektrik'),requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'Aussenlicht_Blinker / Komfortblinken Blinkzyklen',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'coming_home',title:'Coming / Leaving Home',description:tx('Karşılama ve uğurlama aydınlatması'),category:tx('Aydınlatma'),moduleKey:'09',moduleName:tx('09 • Merkezi Elektrik'),requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'Aussenlicht_uebergreifend / Coming Home Verbaustatus',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'auto_lock',title:tx('Otomatik Kilit'),description:tx('Araç hızlanınca kapıları kilitler'),category:tx('Kilitler'),moduleKey:'09',moduleName:tx('09 • Merkezi Elektrik'),requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'ZV allgemein / Autolock',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'auto_unlock',title:tx('Otomatik Kilit Açma'),description:tx('Kontak kapanınca kapı kilitlerini açar'),category:tx('Kilitler'),moduleKey:'09',moduleName:tx('09 • Merkezi Elektrik'),requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'ZV allgemein / Autounlock',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'remote_windows',title:'Kumandadan Cam',description:tx('Camları kumandayla açıp kapatır'),category:tx('Camlar'),moduleKey:'09',moduleName:tx('09 • Merkezi Elektrik'),requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'ZV Komfort / Funk Komfort oeffnen-schliessen',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'remote_ignition',title:tx('Kontak Açıkken Kumanda'),description:tx('Kontak açıkken uzaktan kumandayı etkin tutar'),category:tx('Konfor'),moduleKey:'09',moduleName:tx('09 • Merkezi Elektrik'),requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'ZV allgemein / Funk bei Klemme 15 ein',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'lock_sound',title:tx('Kilitleme Geri Bildirim Sesi'),description:tx('Kilit işleminde akustik geri bildirim'),category:tx('Kilitler'),moduleKey:'09',moduleName:tx('09 • Merkezi Elektrik'),requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'Response signals / Akustische Rueckmeldung',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'safety_abs',title:tx('ABS / ESP Kodlama'),description:tx('Güvenlik kritik modül; OTOSİNYAL tarafından kilitlidir'),category:tx('Güvenlik'),moduleKey:'03',moduleName:'03 • ABS/ESP',requestId:'713',responseId:'77D',kind:CodingRecipeKind.unsupportedSafety,vehicleIds:supportedVehicles,experimental:true,risk:tx('Kritik')),
    VagCodingRecipe(id:'safety_airbag',title:tx('Airbag Kodlama'),description:tx('Güvenlik kritik modül; OTOSİNYAL tarafından kilitlidir'),category:tx('Güvenlik'),moduleKey:'15',moduleName:'15 • Airbag',requestId:'715',responseId:'77F',kind:CodingRecipeKind.unsupportedSafety,vehicleIds:supportedVehicles,experimental:true,risk:tx('Kritik')),
  ];

  static List<VagCodingRecipe> forVehicle(String vehicleId) =>
      recipes.where((item) => item.vehicleIds.contains(vehicleId)).toList(growable:false);
}
