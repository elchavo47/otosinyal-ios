import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/coding_history_provider.dart';
import '../providers/obd_provider.dart';
import '../services/recovered_vag_adaptation_service.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class VagDpfServiceRegenScreen extends StatefulWidget {
  const VagDpfServiceRegenScreen({super.key});

  @override
  State<VagDpfServiceRegenScreen> createState() => _VagDpfServiceRegenScreenState();
}

class _VagDpfServiceRegenScreenState extends State<VagDpfServiceRegenScreen> {
  static const _supportedPlatforms = ['MQB', 'MLB-A4B9', 'PQ35'];
  String _platform = 'MQB';
  bool _busy = false;
  RecoveredVagAdaptation? _routine;
  RecoveredVagAdaptationReadResult? _lastRead;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    setState(() {
      _busy = true;
      _routine = null;
      _lastRead = null;
      _status = null;
    });
    try {
      final rows = await RecoveredVagAdaptationService.loadPlatform(_platform);
      final found = rows.where((r) {
        final name = '${r.name} ${r.description} ${r.innerDescription}'.toLowerCase();
        return r.did.toUpperCase() == '0316' &&
            r.requestId.toUpperCase() == '7E0' &&
            r.responseId.toUpperCase() == '7E8' &&
            (name.contains('dpfserviceregeneration') || name.contains('serviceregenerationofparticulate'));
      }).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _routine = found.isEmpty ? null : found.first;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = tx('Recovery kaydı yüklenemedi: {0}', [e]);
      });
    }
  }

  Future<void> _readState() async {
    final item = _routine;
    if (item == null || _busy) return;
    setState(() { _busy = true; _status = null; });
    final result = await context.read<ObdProvider>().readRecoveredVagAdaptation(item);
    if (!mounted) return;
    setState(() { _busy = false; _lastRead = result; _status = result.message; });
  }

  Future<void> _startRegen() async {
    final item = _routine;
    if (item == null || _busy) return;
    final startOptions = item.options.where((o) => o.valueSpec.trim().toUpperCase() == '01').toList(growable: false);
    if (startOptions.isEmpty) {
      setState(() => _status = tx('Recovery kaydında START=01 seçeneği bulunamadı; işlem başlatılmadı.'));
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(tx('DPF servis rejenerasyonu başlatılsın mı?')),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(tx('Bu işlem sürüş sırasında servis rejenerasyonu içindir ve egzoz sıcaklığını ciddi biçimde yükseltir.'), style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text(tx('Recovery uygulamasındaki prosedür notları:'), style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 11)),
            SizedBox(height: 6),
            Text(tx('• Yakıt en az 1/4 dolu olsun.\n• Güvenli ve kesintisiz bir yolda en az 60 km/h civarında sürüş yapılabilsin.\n• Motoru yaklaşık 2000–2500 rpm aralığında tut.\n• İşlem yaklaşık 10–30 dakika sürebilir.\n• Yanıcı yüzeylerde veya kapalı alanda rejenerasyon yapma.'), style: TextStyle(height: 1.5, color: Colors.white70)),
            SizedBox(height: 10),
            Text(tx('OtoSinyal sadece recovery DB’de doğrulanmış VAG DID 0316 / START 01 akışını kullanır. Araç/ECU desteklemiyorsa yazma reddedilir.'), style: TextStyle(fontSize: 10, height: 1.4, color: Colors.white54)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx('VAZGEÇ'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tx('BAŞLAT'))),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() { _busy = true; _status = tx('Servis rejenerasyonu isteği gönderiliyor…'); });
    final result = await context.read<ObdProvider>().applyRecoveredVagAdaptation(
      item: item,
      option: startOptions.first,
      history: context.read<CodingHistoryProvider>(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = result.success
          ? tx('DPF servis rejenerasyonu ECU tarafından kabul edildi. Sürüş şartlarını koru ve DPF/EGT canlı verilerini takip et.')
          : result.message;
    });
    if (result.success) await _readState();
  }

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    final item = _routine;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tx('DPF Servis Rejenerasyonu'), style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.orange.withValues(alpha: .35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.local_fire_department_rounded, color: Colors.orange), SizedBox(width: 8), Text(tx('SERVİS REJENERASYONU • SÜRÜŞ SIRASINDA'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))]),
              SizedBox(height: 7),
              Text(tx('Bu bölüm DPF’yi kalıcı olarak devre dışı bırakmaz. Recovery DB’de bulunan servis rejenerasyon komutunu motor ECU’suna gönderir.'), style: TextStyle(color: Colors.white60, fontSize: 9.5, height: 1.45)),
            ]),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            value: _platform,
            decoration: InputDecoration(labelText: tx('VAG platformu')),
            items: _supportedPlatforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: _busy ? null : (v) {
              if (v == null || v == _platform) return;
              setState(() => _platform = v);
              _loadRoutine();
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
            child: item == null
                ? Text(_busy ? tx('Recovery kaydı aranıyor…') : tx('Bu platform için doğrulanmış DPF servis rejenerasyon kaydı bulunamadı.'), style: const TextStyle(color: Colors.white60, fontSize: 10))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tx('DOĞRULANMIŞ RECOVERY AKIŞI'), style: TextStyle(color: AppColors.info, fontSize: 9, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('ECU ${item.requestId}/${item.responseId} • DID ${item.did} • Security ${item.password} • Start 01', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70)),
                    const SizedBox(height: 5),
                    Text('UID ${item.uid} • $_platform', style: const TextStyle(fontSize: 8.5, color: Colors.white38)),
                  ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _busy || item == null || !obd.canQueryDtc ? null : _readState, icon: const Icon(Icons.download_rounded), label: Text(tx('DURUMU OKU')))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(onPressed: _busy || item == null || !obd.canQueryDtc ? null : _startRegen, icon: const Icon(Icons.local_fire_department_rounded), label: Text(_busy ? tx('İŞLEM…') : tx('REJENERASYONU BAŞLAT')))),
          ]),
          if (_lastRead != null || _status != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
              child: Text(_status ?? '-', style: TextStyle(fontSize: 10, height: 1.45, color: _lastRead?.success == false ? Colors.amber : Colors.white70)),
            ),
          ],
          const SizedBox(height: 14),
          Text(tx('Not: Recovery DB’de ayrıca “DPF rejenerasyonlarını engelle” kaydı da bulundu; emisyon sistemini devre dışı bırakmaya yaradığı için OtoSinyal bu seçeneği kullanıcıya açmaz.'), style: TextStyle(fontSize: 8.5, height: 1.4, color: Colors.white38)),
        ],
      ),
    );
  }
}
