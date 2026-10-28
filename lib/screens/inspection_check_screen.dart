import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';
import 'package:otosinyal_obd2/models/vehicle.dart';
import 'package:otosinyal_obd2/providers/garage_provider.dart';
import 'package:otosinyal_obd2/providers/obd_provider.dart';
import 'package:otosinyal_obd2/services/diagnostic_report_service.dart';
import 'package:otosinyal_obd2/widget/common/oto_ui.dart';

/// Muayene öncesi ve ikinci el kontrolü.
///
/// Salt okunur OBD servisleri kullanır (Mode 01/03/07/0A): arıza lambası,
/// arıza kodları, hazırlık (readiness) monitörleri ve kod silme sayaçları.
/// ECU'ya hiçbir şey yazmaz.
class InspectionCheckScreen extends StatefulWidget {
  const InspectionCheckScreen({super.key});

  @override
  State<InspectionCheckScreen> createState() => _InspectionCheckScreenState();
}

class _InspectionCheckScreenState extends State<InspectionCheckScreen> {
  bool _hasRun = false;
  bool _reportBusy = false;

  Future<void> _run() async {
    final obd = context.read<ObdProvider>();
    await obd.runInspectionCheck();
    if (!mounted) return;
    setState(() => _hasRun = true);
  }

  Future<void> _shareReport() async {
    final obd = context.read<ObdProvider>();
    final vehicle = context.read<GarageProvider>().activeVehicle ??
        Vehicle(id: 'report', brand: obd.detectedBrand ?? tx('Bilinmeyen araç'), model: '', plate: '', vin: obd.detectedVin ?? '');
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reportBusy = true);
    try {
      await DiagnosticReportService.createAndShare(vehicle: vehicle, obd: obd);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(tx('PDF hazırlanamadı. Lütfen tekrar deneyin.'))));
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    final busy = obd.isInspectionChecking;
    final canRun = obd.canQueryDtc && !busy && !obd.isFullScanning;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: Text(tx('Muayene ve İkinci El Kontrolü'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _IntroCard(),
          const SizedBox(height: 14),
          if (!obd.canQueryDtc)
            OtoEmptyState(
              icon: Icons.cable_rounded,
              title: tx('Önce aracına bağlan'),
              body: tx('Kontrol için OBD adaptörüne bağlanman gerekir. Adaptörün yoksa ana ekrandaki demo moduyla deneyebilirsin.'),
            )
          else
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: canRun ? _run : null,
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.fact_check_rounded),
                label: Text(
                  busy ? tx('KONTROL EDİLİYOR...') : (_hasRun ? tx('KONTROLÜ YENİLE') : tx('KONTROLÜ BAŞLAT')),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          if (_hasRun && !busy) ...[
            const SizedBox(height: 18),
            _InspectionResult(obd: obd),
            const SizedBox(height: 12),
            _UsedCarResult(history: obd.clearHistory),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _reportBusy ? null : _shareReport,
                icon: _reportBusy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(tx('EKSPERTİZ RAPORUNU PAYLAŞ (PDF)'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            tx('Bu kontrol yalnızca aracın beyninin (ECU) bildirdiği verilere dayanır; resmi muayene veya ekspertiz yerine geçmez. Kaporta, şasi ve mekanik durum bu kontrolle anlaşılamaz.'),
            style: const TextStyle(color: Colors.white38, fontSize: 10.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2A0D10), Color(0xFF101113)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_rounded, color: AppColors.accentBright, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx('Muayeneye hazır mı? Kodlar silinmiş mi?'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              tx('Arıza lambası, arıza kodları ve emisyon hazırlık testlerini okur. İkinci el araç alırken arıza kodlarının yakın zamanda silinip silinmediğini gösterir.'),
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
            ),
          ]),
        ),
      ]),
    );
  }
}

enum _Verdict { pass, warn, fail, unknown }

extension on _Verdict {
  Color get color => switch (this) {
        _Verdict.pass => AppColors.success,
        _Verdict.warn => AppColors.warning,
        _Verdict.fail => AppColors.danger,
        _Verdict.unknown => AppColors.textMuted,
      };
  IconData get icon => switch (this) {
        _Verdict.pass => Icons.check_circle_rounded,
        _Verdict.warn => Icons.error_outline_rounded,
        _Verdict.fail => Icons.cancel_rounded,
        _Verdict.unknown => Icons.help_outline_rounded,
      };
}

class _CheckRow {
  const _CheckRow(this.verdict, this.title, this.detail);
  final _Verdict verdict;
  final String title;
  final String detail;
}

class _InspectionResult extends StatelessWidget {
  const _InspectionResult({required this.obd});
  final ObdProvider obd;

  @override
  Widget build(BuildContext context) {
    final stored = obd.dtcEntries.where((e) => e.status == DtcStatus.stored).length;
    final pending = obd.dtcEntries.where((e) => e.status == DtcStatus.pending).length;
    final permanent = obd.dtcEntries.where((e) => e.status == DtcStatus.permanent).length;
    final readiness = obd.readiness;

    final rows = <_CheckRow>[
      switch (obd.milOn) {
        true => _CheckRow(_Verdict.fail, tx('Arıza lambası yanıyor'), tx('Motor arıza lambası (Check Engine) açıkken araç emisyon muayenesinden geçemez.')),
        false => _CheckRow(_Verdict.pass, tx('Arıza lambası kapalı'), tx('ECU motor arıza lambasını kapalı bildiriyor.')),
        null => _CheckRow(_Verdict.unknown, tx('Arıza lambası okunamadı'), tx('ECU bu bilgiyi vermedi.')),
      },
      if (stored + permanent > 0)
        _CheckRow(_Verdict.fail, tx('{0} arıza kodu var', [stored + permanent]), tx('Kayıtlı veya kalıcı arıza kodları muayeneden önce giderilmeli.'))
      else
        _CheckRow(_Verdict.pass, tx('Kayıtlı arıza kodu yok'), tx('ECU kayıtlı veya kalıcı arıza kodu bildirmiyor.')),
      if (pending > 0)
        _CheckRow(_Verdict.warn, tx('{0} bekleyen arıza kodu', [pending]), tx('Henüz kesinleşmemiş ama ECU\'nun izlediği hatalar var.')),
      if (readiness.supported == 0)
        _CheckRow(_Verdict.unknown, tx('Hazırlık testleri okunamadı'), tx('ECU emisyon hazırlık (readiness) bilgisini vermedi.'))
      else if (readiness.incomplete.isEmpty)
        _CheckRow(_Verdict.pass, tx('Hazırlık testleri tamam'), tx('{0}/{1} emisyon testi tamamlanmış.', [readiness.completed, readiness.supported]))
      else
        _CheckRow(
          readiness.incomplete.length == 1 ? _Verdict.warn : _Verdict.fail,
          tx('{0} hazırlık testi tamamlanmamış', [readiness.incomplete.length]),
          tx('Eksik: {0}. Bu testler normal sürüşle (şehir içi + şehir dışı, birkaç gün) kendiliğinden tamamlanır.', [readiness.incomplete.join(', ')]),
        ),
    ];

    final verdict = rows.any((r) => r.verdict == _Verdict.fail)
        ? _Verdict.fail
        : rows.any((r) => r.verdict == _Verdict.warn || r.verdict == _Verdict.unknown)
            ? _Verdict.warn
            : _Verdict.pass;
    final headline = switch (verdict) {
      _Verdict.pass => tx('Muayene için OBD tarafında sorun görünmüyor'),
      _Verdict.warn => tx('Muayene öncesi kontrol edilmesi gerekenler var'),
      _ => tx('Araç bu haliyle emisyon muayenesinden kalabilir'),
    };

    return _ResultCard(title: tx('MUAYENE HAZIRLIĞI'), verdict: verdict, headline: headline, rows: rows);
  }
}

class _UsedCarResult extends StatelessWidget {
  const _UsedCarResult({required this.history});
  final ObdClearHistory history;

  @override
  Widget build(BuildContext context) {
    if (!history.hasData) {
      return _ResultCard(
        title: tx('İKİNCİ EL KONTROLÜ'),
        verdict: _Verdict.unknown,
        headline: tx('Kod silme geçmişi okunamadı'),
        rows: [_CheckRow(_Verdict.unknown, tx('ECU bu sayaçları desteklemiyor'), tx('Bazı eski veya üreticiye özel ECU\'lar kod silme sayaçlarını bildirmez.'))],
      );
    }

    final rows = <_CheckRow>[
      if (history.distanceSinceClearKm != null)
        _CheckRow(
          history.distanceSinceClearKm! < 200 ? _Verdict.fail : _Verdict.pass,
          tx('Kodlar silindikten sonra {0} km gidilmiş', [history.distanceSinceClearKm]),
          history.distanceSinceClearKm! < 200
              ? tx('Çok kısa mesafe: arıza kodları satış öncesi silinmiş olabilir.')
              : tx('Kodların yakın zamanda silindiğine dair bir işaret yok.'),
        ),
      if (history.warmUpsSinceClear != null)
        _CheckRow(
          history.warmUpsSinceClear! < 10 ? _Verdict.fail : _Verdict.pass,
          tx('{0} motor ısınma döngüsü', [history.warmUpsSinceClear! >= 255 ? '255+' : history.warmUpsSinceClear]),
          tx('Kodlar silindikten sonra motorun kaç kez çalışma sıcaklığına ulaştığını gösterir.'),
        ),
      if (history.minutesSinceClear != null)
        _CheckRow(
          _Verdict.pass,
          tx('{0} saat motor çalışma süresi', [(history.minutesSinceClear! / 60).toStringAsFixed(1)]),
          tx('Kodlar silindikten sonra motorun toplam çalışma süresi.'),
        ),
      if (history.milDistanceKm != null && history.milDistanceKm! > 0)
        _CheckRow(_Verdict.warn, tx('Arıza lambası yanarken {0} km gidilmiş', [history.milDistanceKm]), tx('Araç bir süre arıza lambası yanık halde kullanılmış.')),
    ];

    final verdict = history.recentlyCleared ? _Verdict.fail : _Verdict.pass;
    return _ResultCard(
      title: tx('İKİNCİ EL KONTROLÜ'),
      verdict: verdict,
      headline: history.recentlyCleared
          ? tx('Dikkat: arıza kodları yakın zamanda silinmiş olabilir.')
          : tx('Arıza kodlarının yakın zamanda silindiğine dair bir işaret yok.'),
      rows: rows,
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.verdict, required this.headline, required this.rows});
  final String title;
  final _Verdict verdict;
  final String headline;
  final List<_CheckRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: verdict.color.withValues(alpha: .35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(verdict.icon, color: verdict.color, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(headline, style: TextStyle(color: verdict.color, fontSize: 15, fontWeight: FontWeight.w900, height: 1.3))),
        ]),
        const SizedBox(height: 12),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(row.verdict.icon, color: row.verdict.color, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(row.detail, style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.4)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}
