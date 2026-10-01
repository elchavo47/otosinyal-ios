import '../models/coding_backup_record.dart';

class CodingTransactionResult {
  final bool success;
  final bool rolledBack;
  final String message;
  final CodingBackupRecord backup;

  const CodingTransactionResult({
    required this.success,
    required this.rolledBack,
    required this.message,
    required this.backup,
  });
}

typedef CodingValueReader = Future<String> Function();
typedef CodingValueWriter = Future<void> Function(String valueHex);
typedef CodingBackupSaver = Future<void> Function(CodingBackupRecord record);
typedef CodingStatusWriter = Future<void> Function(
  String id,
  CodingBackupStatus status, {
  String? requestedHex,
  String? verifiedHex,
});

/// Enforces read -> durable backup -> write -> read-back verification.
/// If verification fails, the captured value is written back immediately.
class CodingTransactionService {
  static Future<CodingTransactionResult> execute({
    required CodingBackupRecord Function(String originalHex) createBackup,
    required String requestedHex,
    required CodingValueReader readCurrent,
    required CodingValueWriter writeValue,
    required CodingBackupSaver saveBackup,
    required CodingStatusWriter updateStatus,
  }) async {
    final requested = _normalize(requestedHex);
    if (requested.isEmpty) throw const FormatException('Yeni kodlama değeri boş');

    final original = _normalize(await readCurrent());
    if (original.isEmpty) throw const FormatException('Mevcut ECU kodu okunamadı');
    if (original.length != requested.length) {
      throw const FormatException('Yeni değer mevcut kodla aynı uzunlukta değil');
    }

    final backup = createBackup(original);
    // This await is the safety barrier: no ECU write can happen unless the
    // original value has first reached persistent storage.
    await saveBackup(backup);

    await writeValue(requested);
    final verified = _normalize(await readCurrent());
    if (verified == requested) {
      await updateStatus(
        backup.id,
        CodingBackupStatus.applied,
        requestedHex: requested,
        verifiedHex: verified,
      );
      return CodingTransactionResult(
        success: true,
        rolledBack: false,
        message: 'Kodlama yazıldı ve ECU’dan doğrulandı',
        backup: backup,
      );
    }

    await updateStatus(
      backup.id,
      CodingBackupStatus.verificationFailed,
      requestedHex: requested,
      verifiedHex: verified,
    );

    try {
      await writeValue(original);
      final rollbackVerified = _normalize(await readCurrent());
      final rollbackOk = rollbackVerified == original;
      await updateStatus(
        backup.id,
        rollbackOk ? CodingBackupStatus.rolledBack : CodingBackupStatus.rollbackFailed,
        requestedHex: requested,
        verifiedHex: rollbackVerified,
      );
      return CodingTransactionResult(
        success: false,
        rolledBack: rollbackOk,
        message: rollbackOk
            ? 'Yeni değer doğrulanmadı; eski kod otomatik geri yüklendi'
            : 'Yeni değer doğrulanmadı ve otomatik geri dönüş de doğrulanamadı',
        backup: backup,
      );
    } catch (_) {
      await updateStatus(
        backup.id,
        CodingBackupStatus.rollbackFailed,
        requestedHex: requested,
        verifiedHex: verified,
      );
      return CodingTransactionResult(
        success: false,
        rolledBack: false,
        message: 'Doğrulama başarısız; otomatik geri dönüş sırasında bağlantı kesildi',
        backup: backup,
      );
    }
  }

  static String _normalize(String raw) {
    final value = raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    return value.length.isEven ? value : '';
  }
}
