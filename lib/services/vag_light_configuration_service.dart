import '../models/vag_light_configuration.dart';

class VagLightConfigurationService {
  static const String requestId = '70E';
  static const String responseId = '778';
  static const int securityAccessCode = 31347;

  static const List<VagLightChannel> channels = [
    VagLightChannel(index: 0, did: '0550', name: '0 BLK VL B36', hint: 'Ön sol sinyal'),
    VagLightChannel(index: 1, did: '0551', name: '1 BLK VR B20', hint: 'Ön sağ sinyal'),
    VagLightChannel(index: 2, did: '0552', name: '2 SL VLB10', hint: 'Ön sol park/pozisyon'),
    VagLightChannel(index: 3, did: '0553', name: '3 SL VRB21', hint: 'Ön sağ park/pozisyon'),
    VagLightChannel(index: 4, did: '0554', name: '4 TFL LB4', hint: 'Ön sol DRL'),
    VagLightChannel(index: 5, did: '0555', name: '5 TFL RB32', hint: 'Ön sağ DRL'),
    VagLightChannel(index: 6, did: '0556', name: '6 ABL LC5', hint: 'Sol kısa far'),
    VagLightChannel(index: 7, did: '0557', name: '7 ABL RB1', hint: 'Sağ kısa far'),
    VagLightChannel(index: 8, did: '0558', name: '8 FL LB39', hint: 'Sol uzun far'),
    VagLightChannel(index: 9, did: '0559', name: '9 FL RB2', hint: 'Sağ uzun far'),
    VagLightChannel(index: 10, did: '055A', name: '10 SHUTTER LB23', hint: 'Sol far teşhis/shutter'),
    VagLightChannel(index: 11, did: '055B', name: '11 SHUTTER RB22', hint: 'Sağ far teşhis/shutter'),
    VagLightChannel(index: 12, did: '055C', name: '12 NL LB45', hint: 'Sol sis farı'),
    VagLightChannel(index: 13, did: '055D', name: '13 NL RB5', hint: 'Sağ sis farı'),
    VagLightChannel(index: 14, did: '055E', name: '14 LOCKUNLOCK61', hint: 'Kilit/açma aydınlatması'),
    VagLightChannel(index: 15, did: '055F', name: '15 35 LED Warnblinktaster C48', hint: 'Dörtlü düğmesi LED'),
    VagLightChannel(index: 16, did: '0560', name: '16 BLK SLB35BLK SL KC9', hint: 'Sol ön DRL/sinyal bölümü'),
    VagLightChannel(index: 17, did: '0561', name: '17 TFL R BLK SRB3TFL R BLK SR KC3', hint: 'Sağ ön DRL/sinyal bölümü'),
    VagLightChannel(index: 18, did: '0562', name: '18 BLK HLA60', hint: 'Arka sol sinyal'),
    VagLightChannel(index: 19, did: '0563', name: '19 BLK HRC31', hint: 'Arka sağ sinyal'),
    VagLightChannel(index: 20, did: '0564', name: '20 BR LA71', hint: 'Sol stop'),
    VagLightChannel(index: 21, did: '0565', name: '21 BR RC8', hint: 'Sağ stop'),
    VagLightChannel(index: 22, did: '0566', name: '22 BR MA57', hint: '3. stop / orta fren'),
    VagLightChannel(index: 23, did: '0567', name: '23 SL HLC10', hint: 'Arka sol park/pozisyon'),
    VagLightChannel(index: 24, did: '0568', name: '24 SL HRA65', hint: 'Arka sağ park/pozisyon'),
    VagLightChannel(index: 25, did: '0569', name: '25 KZL HA59', hint: 'Plaka aydınlatması'),
    VagLightChannel(index: 26, did: '056A', name: '26 NSL LA72', hint: 'Arka sol sis'),
    VagLightChannel(index: 27, did: '056B', name: '27 NSL RC6', hint: 'Arka sağ sis'),
    VagLightChannel(index: 28, did: '056C', name: '28 RFL LC11', hint: 'Arka sol geri vites'),
    VagLightChannel(index: 29, did: '056D', name: '29 RFL RA64', hint: 'Arka sağ geri vites'),
    VagLightChannel(index: 30, did: '056E', name: '30 FR LC72', hint: 'Ayak aydınlatması'),
    VagLightChannel(index: 31, did: '056F', name: '31 AMBL 1C61', hint: 'Ambiyans 1'),
    VagLightChannel(index: 32, did: '0570', name: '32 AMBL 2C35', hint: 'Ambiyans 2'),
    VagLightChannel(index: 33, did: '0571', name: '33 AMBL 3C36', hint: 'Ambiyans 3'),
    VagLightChannel(index: 34, did: '0572', name: '34 AMBL 4C37', hint: 'Ambiyans 4'),
  ];

  static String hex(List<int> bytes) => bytes
      .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
}
