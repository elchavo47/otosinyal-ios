import '../models/diagnostic_units.dart';
import '../models/oem_module_profile.dart';
import '../services/oem_diagnostic_catalog.dart';
import '../services/vag_uds_address_catalog.dart';

/// Converts the existing brand ECU catalog into safe module probes.
/// No profile is treated as verified until the ECU returns a positive response.
class OemModuleProfileService {
  static DiagnosticUnit? _unitFor(String name) {
    final value = name.toLowerCase();
    if (value.contains('engine') || value.contains('dme') || value.contains('motor')) {
      return DiagnosticUnit.engine;
    }
    if (value.contains('transmission') || value.contains('gearbox') || value.contains('tcu') || value.contains('egs') || value.contains('dsg') || value.contains('gear')) {
      return DiagnosticUnit.transmission;
    }
    if (value.contains('abs') || value.contains('esp') || value.contains('dsc') || value.contains('brake') || value.contains('stability')) {
      return DiagnosticUnit.abs;
    }
    if (value.contains('airbag') || value.contains('srs') || value.contains('crash') || value.contains('safety')) {
      return DiagnosticUnit.airbag;
    }
    if (value.contains('gateway') || value.contains('zgw') || value.contains('can gateway')) {
      return DiagnosticUnit.gateway;
    }
    if (value.contains('bcm') || value.contains('body') || value.contains('comfort') || value.contains('frm') || value.contains('bdc') || value.contains('footwell')) {
      return DiagnosticUnit.body;
    }
    return null;
  }

  static int? _parseAddress(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value.startsWith('0x')) return int.tryParse(value.substring(2), radix: 16);
    return int.tryParse(value, radix: 16) ?? int.tryParse(value);
  }

  static Future<List<OemModuleProfile>> forBrand(
    String? brand,
    DiagnosticUnit unit,
  ) async {
    final profiles = <OemModuleProfile>[];
    final normalizedBrand = (brand ?? '').toLowerCase();
    final isVag = normalizedBrand.contains('volkswagen') ||
        normalizedBrand.contains('audi') ||
        normalizedBrand.contains('skoda') ||
        normalizedBrand.contains('škoda') ||
        normalizedBrand.contains('seat') ||
        normalizedBrand.contains('cupra') ||
        normalizedBrand.contains('porsche');

    if (isVag) {
      profiles.addAll(VagUdsAddressCatalog.forUnit(unit).map((address) =>
          OemModuleProfile(
            unit: unit,
            name: address.name,
            source: 'VAG UDS adres kataloğu',
            protocol: OemModuleProtocol.canUds,
            requestId: address.requestId,
            responseId: address.responseId,
          )));
    }
    final catalog = await OemDiagnosticCatalog.summaryForBrand(brand);

    for (final ecu in catalog?.ecus ?? const []) {
      final classified = _unitFor('${ecu.name} ${ecu.commonName}');
      if (classified != unit) continue;
      final address = _parseAddress(ecu.address);
      if (address == null) continue;

      if (address >= 0x600 && address <= 0x7E7 && address + 8 <= 0x7FF) {
        profiles.add(OemModuleProfile(
          unit: unit,
          name: ecu.commonName,
          source: catalog?.displayName ?? 'OEM katalogı',
          protocol: OemModuleProtocol.canUds,
          requestId: address.toRadixString(16).padLeft(3, '0').toUpperCase(),
          responseId: (address + 8).toRadixString(16).padLeft(3, '0').toUpperCase(),
        ));
      } else if (address >= 0 && address <= 0xFF) {
        // Some catalogs expose a short logical ECU address. It is only a
        // DoIP candidate; the response still has to prove the ECU exists.
        profiles.add(OemModuleProfile(
          unit: unit,
          name: ecu.commonName,
          source: catalog?.displayName ?? 'OEM katalogı',
          protocol: OemModuleProtocol.doip,
          doipLogicalAddress: address,
        ));
      }
    }

    if (profiles.isEmpty) {
      final definition = diagnosticUnitDefinition(unit);
      for (final response in definition.typicalResponseIds) {
        final value = int.tryParse(response, radix: 16);
        if (value == null || value < 8) continue;
        profiles.add(OemModuleProfile(
          unit: unit,
          name: definition.label,
          source: 'Generic 11-bit CAN fallback',
          protocol: OemModuleProtocol.canUds,
          requestId: (value - 8).toRadixString(16).padLeft(3, '0').toUpperCase(),
          responseId: response,
        ));
      }
    }

    final unique = <String, OemModuleProfile>{};
    for (final profile in profiles) {
      final key = '${profile.protocol.name}:${profile.addressLabel}';
      unique[key] = profile;
    }
    return unique.values.toList(growable: false);
  }
}
