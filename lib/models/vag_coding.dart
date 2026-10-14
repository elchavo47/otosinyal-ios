import 'package:otosinyal_obd2/l10n/tx.dart';
enum CodingCompatibility {
  compatible,
  hardwareMissing,
  unverified,
  sfdProtected,
  reading,
  error,
}

extension CodingCompatibilityLabel on CodingCompatibility {
  String get label => switch (this) {
    CodingCompatibility.compatible => tx('UYUMLU'),
    CodingCompatibility.hardwareMissing => tx('DONANIM EKSİK'),
    CodingCompatibility.unverified => tx('DOĞRULANMAMIŞ'),
    CodingCompatibility.sfdProtected => tx('SFD KORUMALI'),
    CodingCompatibility.reading => tx('OKUNUYOR'),
    CodingCompatibility.error => tx('HATA'),
  };
}

class VagModuleIdentity {
  final String key;
  final String name;
  final String requestId;
  final String responseId;
  final bool responding;
  final String? vin;
  final String? partNumber;
  final String? softwareVersion;
  final String? asamDataset;
  final String? asamVersion;
  final bool sfdProtected;
  final String detail;

  const VagModuleIdentity({
    required this.key,
    required this.name,
    required this.requestId,
    required this.responseId,
    required this.responding,
    required this.detail,
    this.vin,
    this.partNumber,
    this.softwareVersion,
    this.asamDataset,
    this.asamVersion,
    this.sfdProtected = false,
  });
}

enum CodingRecipeKind { longCodingBit, adaptation, unsupportedSafety }

class VagCodingRecipe {
  final String id;
  final String title;
  final String description;
  final String category;
  final String moduleKey;
  final String moduleName;
  final String requestId;
  final String responseId;
  final CodingRecipeKind kind;
  final String? did;
  final int? byteIndex;
  final int? bitIndex;
  final String? adaptationPath;
  final Set<String> vehicleIds;

  /// Optional exact ECU identity constraints recovered/validated for this item.
  /// Empty sets mean that field is not used as a constraint.
  final Set<String> partNumbers;
  final Set<String> softwareVersions;
  final Set<String> asamDatasets;
  final Set<String> asamVersions;

  /// UDS mechanics are explicit so a recovered catalog is not forced into the
  /// first-generation 0x22/0x2E assumptions.
  final int readService;
  final int? writeService;
  final int diagnosticSession;
  final int? securityAccessLevel;
  final String? securityProviderId;

  final bool experimental;
  final bool writeEnabled;
  final String risk;
  final String evidence;
  final String sourceResource;
  final String sourceRevision;
  final bool recovered;

  VagCodingRecipe({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.moduleKey,
    required this.moduleName,
    required this.requestId,
    required this.responseId,
    required this.kind,
    required this.vehicleIds,
    this.did,
    this.byteIndex,
    this.bitIndex,
    this.adaptationPath,
    this.partNumbers = const {},
    this.softwareVersions = const {},
    this.asamDatasets = const {},
    this.asamVersions = const {},
    this.readService = 0x22,
    this.writeService = 0x2E,
    this.diagnosticSession = 0x03,
    this.securityAccessLevel,
    this.securityProviderId,
    this.experimental = false,
    this.writeEnabled = false,
    this.risk = 'Düşük', // l10n: tx() at display
    this.evidence = 'Katalog kaynağı belirtilmedi', // l10n: tx() at display
    this.sourceResource = '',
    this.sourceRevision = '',
    this.recovered = false,
  });

  bool get hasIdentityAllowlist =>
      partNumbers.isNotEmpty ||
      softwareVersions.isNotEmpty ||
      asamDatasets.isNotEmpty ||
      asamVersions.isNotEmpty;

  bool matchesIdentity(VagModuleIdentity module) {
    bool accepts(Set<String> allowed, String? value) {
      if (allowed.isEmpty) return true;
      final normalized = (value ?? '').trim().toUpperCase();
      return normalized.isNotEmpty &&
          allowed.map((e) => e.trim().toUpperCase()).contains(normalized);
    }

    return accepts(partNumbers, module.partNumber) &&
        accepts(softwareVersions, module.softwareVersion) &&
        accepts(asamDatasets, module.asamDataset) &&
        accepts(asamVersions, module.asamVersion);
  }
}

class CodingFeatureState {
  final String recipeId;
  final CodingCompatibility compatibility;
  final bool? enabled;
  final String? currentHex;
  final String detail;

  const CodingFeatureState({
    required this.recipeId,
    required this.compatibility,
    required this.detail,
    this.enabled,
    this.currentHex,
  });
}

class CodingApplyResult {
  final bool success;
  final bool rolledBack;
  final String message;
  const CodingApplyResult(this.success, this.message, {this.rolledBack = false});
}
