import 'package:otosinyal_obd2/l10n/tx.dart';
class VagLiveDidDefinition {
  final int did;
  final String name;
  final String decoder;
  final double scale;
  final double offset;
  final String? unit;
  final String group;

  const VagLiveDidDefinition({
    required this.did,
    required this.name,
    required this.decoder,
    required this.group,
    this.scale = 1,
    this.offset = 0,
    this.unit,
  });

  String get hex => did.toRadixString(16).padLeft(4, '0').toUpperCase();

  double? decodeNumber(List<int> b) {
    if (b.isEmpty) return null;
    int? raw;
    switch (decoder) {
      case 'u8': raw = b[0]; break;
      case 'i8': raw = b[0] >= 0x80 ? b[0] - 0x100 : b[0]; break;
      case 'u16': if (b.length >= 2) raw = (b[0] << 8) | b[1]; break;
      case 'i16':
        if (b.length >= 2) {
          final v = (b[0] << 8) | b[1];
          raw = v >= 0x8000 ? v - 0x10000 : v;
        }
        break;
      case 'u32':
        if (b.length >= 4) raw = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
        break;
    }
    return raw == null ? null : raw * scale + offset;
  }
}

class VagLiveDidCatalog {
  // Read-only engine candidates. They are never reported as supported until
  // the ECU returns a positive UDS 0x62 response for that exact DID.
  static const List<VagLiveDidDefinition> candidates = [
    VagLiveDidDefinition(did: 0x1050, name: tx('Turbo hedef basıncı'), decoder: 'u16', scale: .1, unit: 'kPa', group: 'Turbo'),
    VagLiveDidDefinition(did: 0x4E06, name: tx('Turbo gerçek basıncı'), decoder: 'i16', unit: 'hPa', group: 'Turbo'),
    VagLiveDidDefinition(did: 0x4E0D, name: tx('Yakıt rail basıncı'), decoder: 'u16', unit: 'bar', group: tx('Yakıt')),
    VagLiveDidDefinition(did: 0x1054, name: tx('DPF rejenerasyon aktif'), decoder: 'u8', unit: 'bool', group: 'DPF'),
    VagLiveDidDefinition(did: 0x1055, name: tx('DPF giriş EGT'), decoder: 'u16', scale: .1, unit: '°C', group: 'DPF'),
    VagLiveDidDefinition(did: 0x1056, name: tx('DPF çıkış EGT'), decoder: 'u16', scale: .1, unit: '°C', group: 'DPF'),
    VagLiveDidDefinition(did: 0x1057, name: tx('DPF diferansiyel basınç'), decoder: 'u16', scale: .01, unit: 'kPa', group: 'DPF'),
    VagLiveDidDefinition(did: 0x105D, name: tx('DPF soot yükü hesaplanan'), decoder: 'u8', scale: .4, unit: '%', group: 'DPF'),
    VagLiveDidDefinition(did: 0x105E, name: tx('DPF soot yükü ölçülen'), decoder: 'u8', scale: .4, unit: '%', group: 'DPF'),
    VagLiveDidDefinition(did: 0x4E16, name: tx('DPF soot kütlesi'), decoder: 'u16', scale: .01, unit: 'g', group: 'DPF'),
    VagLiveDidDefinition(did: 0x1061, name: tx('Son rejenerasyondan mesafe'), decoder: 'u16', unit: 'km', group: 'DPF'),
    VagLiveDidDefinition(did: 0x10A7, name: tx('Turbo öncesi EGT'), decoder: 'u16', scale: .1, unit: '°C', group: 'Turbo'),
    VagLiveDidDefinition(did: 0x1090, name: tx('Misfire silindir 1'), decoder: 'u16', group: 'Misfire'),
    VagLiveDidDefinition(did: 0x1091, name: tx('Misfire silindir 2'), decoder: 'u16', group: 'Misfire'),
    VagLiveDidDefinition(did: 0x1092, name: tx('Misfire silindir 3'), decoder: 'u16', group: 'Misfire'),
    VagLiveDidDefinition(did: 0x1093, name: tx('Misfire silindir 4'), decoder: 'u16', group: 'Misfire'),
  ];
}
