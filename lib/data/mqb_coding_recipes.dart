import '../models/vag_coding.dart';

/// OTOSİNYAL'ın ilk nesil MQB kataloğu.
///
/// Sayısal konumu doğrulanan long-coding bitleri okunabilir. Adaptation kanal
/// adları kataloglanır ancak ECU/ASAM bazında sayısal DID eşleşmesi olmadan
/// kesinlikle yazılmaz.
class MqbCodingRecipes {
  static const supportedVehicles = <String>{
    'vw-golf7', 'vw-passatb8', 'skoda-octavia3', 'seat-leon3', 'audi-a3-8v',
  };

  static const recipes = <VagCodingRecipe>[
    VagCodingRecipe(id:'needle_sweep',title:'İbre Selamlama',description:'Kontak açılışında ibrelerin test turu yapması',category:'Gösterge',moduleKey:'17',moduleName:'17 • Gösterge Paneli',requestId:'714',responseId:'77E',kind:CodingRecipeKind.longCodingBit,did:'0600',byteIndex:1,bitIndex:0,vehicleIds:supportedVehicles,writeEnabled:false),
    VagCodingRecipe(id:'lap_timer',title:'Lap Timer',description:'Gösterge menüsünde tur zamanı ekranı',category:'Gösterge',moduleKey:'17',moduleName:'17 • Gösterge Paneli',requestId:'714',responseId:'77E',kind:CodingRecipeKind.longCodingBit,did:'0600',byteIndex:1,bitIndex:3,vehicleIds:supportedVehicles,writeEnabled:false),
    VagCodingRecipe(id:'refill_quantity',title:'Depoya Eklenecek Yakıt',description:'Gösterge ekranında dolum miktarı önerisi',category:'Gösterge',moduleKey:'17',moduleName:'17 • Gösterge Paneli',requestId:'714',responseId:'77E',kind:CodingRecipeKind.longCodingBit,did:'0600',byteIndex:10,bitIndex:4,vehicleIds:supportedVehicles,writeEnabled:false),
    VagCodingRecipe(id:'comfort_blink',title:'Konfor Sinyali',description:'Dokunmatik sinyal tekrar sayısını ayarlar',category:'Aydınlatma',moduleKey:'09',moduleName:'09 • Merkezi Elektrik',requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'Aussenlicht_Blinker / Komfortblinken Blinkzyklen',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'coming_home',title:'Coming / Leaving Home',description:'Karşılama ve uğurlama aydınlatması',category:'Aydınlatma',moduleKey:'09',moduleName:'09 • Merkezi Elektrik',requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'Aussenlicht_uebergreifend / Coming Home Verbaustatus',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'auto_lock',title:'Otomatik Kilit',description:'Araç hızlanınca kapıları kilitler',category:'Kilitler',moduleKey:'09',moduleName:'09 • Merkezi Elektrik',requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'ZV allgemein / Autolock',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'auto_unlock',title:'Otomatik Kilit Açma',description:'Kontak kapanınca kapı kilitlerini açar',category:'Kilitler',moduleKey:'09',moduleName:'09 • Merkezi Elektrik',requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'ZV allgemein / Autounlock',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'remote_windows',title:'Kumandadan Cam',description:'Camları kumandayla açıp kapatır',category:'Camlar',moduleKey:'09',moduleName:'09 • Merkezi Elektrik',requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'ZV Komfort / Funk Komfort oeffnen-schliessen',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'remote_ignition',title:'Kontak Açıkken Kumanda',description:'Kontak açıkken uzaktan kumandayı etkin tutar',category:'Konfor',moduleKey:'09',moduleName:'09 • Merkezi Elektrik',requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'ZV allgemein / Funk bei Klemme 15 ein',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'lock_sound',title:'Kilitleme Geri Bildirim Sesi',description:'Kilit işleminde akustik geri bildirim',category:'Kilitler',moduleKey:'09',moduleName:'09 • Merkezi Elektrik',requestId:'70E',responseId:'778',kind:CodingRecipeKind.adaptation,adaptationPath:'Response signals / Akustische Rueckmeldung',vehicleIds:supportedVehicles,experimental:true),
    VagCodingRecipe(id:'safety_abs',title:'ABS / ESP Kodlama',description:'Güvenlik kritik modül; OTOSİNYAL tarafından kilitlidir',category:'Güvenlik',moduleKey:'03',moduleName:'03 • ABS/ESP',requestId:'713',responseId:'77D',kind:CodingRecipeKind.unsupportedSafety,vehicleIds:supportedVehicles,experimental:true,risk:'Kritik'),
    VagCodingRecipe(id:'safety_airbag',title:'Airbag Kodlama',description:'Güvenlik kritik modül; OTOSİNYAL tarafından kilitlidir',category:'Güvenlik',moduleKey:'15',moduleName:'15 • Airbag',requestId:'715',responseId:'77F',kind:CodingRecipeKind.unsupportedSafety,vehicleIds:supportedVehicles,experimental:true,risk:'Kritik'),
  ];

  static List<VagCodingRecipe> forVehicle(String vehicleId) =>
      recipes.where((item) => item.vehicleIds.contains(vehicleId)).toList(growable:false);
}
