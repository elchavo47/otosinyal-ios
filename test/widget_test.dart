import 'package:flutter_test/flutter_test.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/models/diagnostic_units.dart';
import 'package:otosinyal_obd2/services/uds_diagnostic.dart';
import 'package:otosinyal_obd2/services/vin_decoder.dart';
import 'package:otosinyal_obd2/services/vag_uds_address_catalog.dart';
import 'package:otosinyal_obd2/models/coding_backup_record.dart';
import 'package:otosinyal_obd2/services/coding_transaction_service.dart';
import 'package:otosinyal_obd2/data/mqb_coding_recipes.dart';
import 'package:otosinyal_obd2/data/vag_vehicle_catalog.dart';
import 'package:otosinyal_obd2/providers/obd_provider.dart';

void main() {
  test('VIP tema ve ünite kataloğu yüklenebilir', () {
    expect(AppColors.vipGradient.colors.length, 3);
    expect(diagnosticUnitDefinitions.length, 6);
    expect(diagnosticUnitDefinitions.first.unit, DiagnosticUnit.engine);
  });

  test('adaptör kalite puanı gerçek ölçümlerden 0-100 hesaplanır',(){
    const strong=AdapterQualityResult(successful:8,total:8,averageMs:90,verdict:'Kodlamaya uygun',capabilities:{'Header':true,'ISO-TP':true,'Uzun UDS':true},packetLossPercent:0);
    const weak=AdapterQualityResult(successful:3,total:8,averageMs:2200,verdict:'Zayıf',capabilities:{'Header':true,'ISO-TP':false},packetLossPercent:25);
    expect(strong.score,100);
    expect(weak.score,lessThan(40));
  });

  test('boşluksuz ve CAN headerlı UDS cevabı ayrıştırılır', () {
    final bytes = UdsDiagnostic.hexBytes('7E8 10 14 62 F1 90 57 56 57\r7E8 21 5A 5A 5A 55 5A 46 57\r7E8 22 30 30 30 30 30 31 32>');
    expect(bytes.contains(0x62), isTrue);
    expect(UdsDiagnostic.readDidPayload('62F1905756575A5A5A55313233343536373839', 0xF190), isNotNull);
    expect(UdsDiagnostic.hexBytes('50030032'), [0x50, 0x03, 0x00, 0x32]);
  });

  test('UDS F190 içinden 17 karakter VIN alınır', () {
    expect(
      VinDecoder.extractVinFromUds('7E8 10 14 62 F1 90 57 56 57\r7E8 21 5A 5A 5A 55 5A 46 57\r7E8 22 30 30 30 30 30 30 31'),
      'WVWZZZUZFW0000001',
    );
  });

  test('VAG gateway adresi doğru profile bağlıdır', () {
    final gateway = VagUdsAddressCatalog.forUnit(DiagnosticUnit.gateway).single;
    expect(gateway.requestId, '710');
    expect(gateway.responseId, '77A');
  });

  test('kodlama geri dönüş kaydı kayıpsız saklanır', () {
    final record = CodingBackupRecord(
      id: 'backup-1',
      vin: 'WVWZZZUZFW0000001',
      brand: 'Volkswagen',
      moduleName: 'Gösterge Paneli',
      requestId: '714',
      responseId: '77E',
      did: '0600',
      originalHex: '00112233',
      requestedHex: '01112233',
      ecuPartNumber: '5G0920',
      ecuSoftwareVersion: '1001',
      status: CodingBackupStatus.applied,
      createdAt: DateTime.utc(2026, 9, 2),
    );
    final restored = CodingBackupRecord.fromMap(record.toMap());
    expect(restored.vin, record.vin);
    expect(restored.originalHex, record.originalHex);
    expect(restored.canRollback, isTrue);
  });

  test('kodlama işleminde yedek yazmadan ECU yazılmaz', () async {
    var ecu = '00112233';
    var backupSaved = false;
    final events = <String>[];
    final result = await CodingTransactionService.execute(
      requestedHex: '01112233',
      readCurrent: () async => ecu,
      writeValue: (value) async {
        expect(backupSaved, isTrue);
        events.add('write');
        ecu = value;
      },
      createBackup: (original) => CodingBackupRecord(
        id: 'tx-1', vin: 'WVWZZZUZFW0000001', brand: 'Volkswagen',
        moduleName: 'Gösterge Paneli', requestId: '714', responseId: '77E',
        did: '0600', originalHex: original, ecuPartNumber: '5G0920',
        ecuSoftwareVersion: '1001', status: CodingBackupStatus.captured,
        createdAt: DateTime.utc(2026, 9, 2),
      ),
      saveBackup: (record) async { events.add('backup'); backupSaved = true; },
      updateStatus: (id, status, {requestedHex, verifiedHex}) async { events.add(status.name); },
    );
    expect(result.success, isTrue);
    expect(events.first, 'backup');
    expect(ecu, '01112233');
  });

  test('MQB başlangıç kataloğu beş aracı ve güvenlik kilitlerini içerir', () {
    expect(MqbCodingRecipes.supportedVehicles.length, 5);
    expect(MqbCodingRecipes.forVehicle('vw-golf7').any((e) => e.id == 'needle_sweep'), isTrue);
    expect(MqbCodingRecipes.recipes.where((e) => e.moduleKey == '03' || e.moduleKey == '15').every((e) => !e.writeEnabled), isTrue);
  });

  test('VIN model yılı çevrimi ve profil önerisi çalışır', () {
    expect(VagVehicleCatalog.modelYearFromVin('WVWZZZAUZFW000001'), 2015);
    final suggestions = VagVehicleCatalog.suggestionsForVin('WVWZZZAUZFW000001', 'Volkswagen');
    expect(suggestions.any((e) => e.id == 'vw-golf7'), isTrue);
  });
}
