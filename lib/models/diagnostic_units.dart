import 'package:flutter/material.dart';

enum DiagnosticUnit { engine, transmission, abs, airbag, body, gateway }

class DiagnosticUnitDefinition {
  final DiagnosticUnit unit;
  final String label;
  final String subtitle;
  final IconData icon;
  final List<String> typicalResponseIds;

  const DiagnosticUnitDefinition({
    required this.unit,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.typicalResponseIds,
  });
}

/// These are common 11-bit CAN response IDs, not a promise that every OEM
/// uses them. The scanner still requires a real ECU response before marking a
/// unit as found.
const diagnosticUnitDefinitions = <DiagnosticUnitDefinition>[
  DiagnosticUnitDefinition(
    unit: DiagnosticUnit.engine,
    label: 'Motor ECU',
    subtitle: 'Canlı veri, DTC, VIN ve emisyon durumu',
    icon: Icons.settings_suggest_rounded,
    typicalResponseIds: ['7E8'],
  ),
  DiagnosticUnitDefinition(
    unit: DiagnosticUnit.transmission,
    label: 'Şanzıman / TCU',
    subtitle: 'Güvenli salt-okunur cevap ve DTC taraması',
    icon: Icons.swap_vertical_circle_rounded,
    typicalResponseIds: ['7E9', '7EA'],
  ),
  DiagnosticUnitDefinition(
    unit: DiagnosticUnit.abs,
    label: 'ABS / ESP',
    subtitle: 'Fren ve denge sistemi kontrol ünitesi',
    icon: Icons.speed_rounded,
    typicalResponseIds: ['768', '769', '7B8'],
  ),
  DiagnosticUnitDefinition(
    unit: DiagnosticUnit.airbag,
    label: 'Airbag / SRS',
    subtitle: 'Güvenlik modülü için yalnızca okuma sorguları',
    icon: Icons.health_and_safety_rounded,
    typicalResponseIds: ['758', '75A', '7B8'],
  ),
  DiagnosticUnitDefinition(
    unit: DiagnosticUnit.body,
    label: 'Gövde / BCM',
    subtitle: 'Konfor ve gövde elektronik modülleri',
    icon: Icons.electric_bolt_rounded,
    typicalResponseIds: ['72E', '738'],
  ),
  DiagnosticUnitDefinition(
    unit: DiagnosticUnit.gateway,
    label: 'Gateway / Ağ',
    subtitle: 'Araç içi CAN ağının yanıt veren düğümleri',
    icon: Icons.hub_rounded,
    typicalResponseIds: ['708', '7E8'],
  ),
];

DiagnosticUnitDefinition diagnosticUnitDefinition(DiagnosticUnit unit) =>
    diagnosticUnitDefinitions.firstWhere((item) => item.unit == unit);

class DiagnosticUnitScanResult {
  final DiagnosticUnit unit;
  final bool discovered;
  final bool demo;
  final String? responseId;
  final List<String> dtcs;
  final String? detail;
  final String? protocol;
  final String? profile;
  final DateTime scannedAt;

  const DiagnosticUnitScanResult({
    required this.unit,
    required this.discovered,
    required this.demo,
    required this.responseId,
    required this.dtcs,
    required this.detail,
    this.protocol,
    this.profile,
    required this.scannedAt,
  });

  String get statusLabel {
    if (demo) return 'DEMO';
    if (discovered) return 'BULUNDU';
    return 'YANIT YOK';
  }
}
