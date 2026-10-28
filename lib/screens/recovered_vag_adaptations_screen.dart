import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/coding_history_provider.dart';
import '../providers/obd_provider.dart';
import '../services/recovered_vag_adaptation_service.dart';
import 'vag_light_adaptation_screen.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class RecoveredVagAdaptationsScreen extends StatefulWidget {
  const RecoveredVagAdaptationsScreen({super.key, this.initialPlatform = 'MQB', this.initialGroup, this.customTitle});
  final String initialPlatform;
  final int? initialGroup;
  final String? customTitle;

  @override
  State<RecoveredVagAdaptationsScreen> createState() => _RecoveredVagAdaptationsScreenState();
}

class _RecoveredVagAdaptationsScreenState extends State<RecoveredVagAdaptationsScreen> {
  late String _platform;
  String _query = '';
  bool _onlyWritable = false;
  int? _selectedGroup;
  late final Future<List<RecoveredVagAdaptation>> _platformFuture;
  bool _groupChosenHere = false;

  @override
  void initState() {
    super.initState();
    _platform = RecoveredVagAdaptationService.supportedPlatforms.contains(widget.initialPlatform.toUpperCase())
        ? widget.initialPlatform.toUpperCase()
        : 'MQB';
    // Load the platform catalog exactly once. Recreating this Future on every
    // setState (for example when opening a section) caused the UI to fall back
    // to the loading spinner repeatedly.
    _selectedGroup = widget.initialGroup;
    _platformFuture = RecoveredVagAdaptationService.loadPlatform(_platform);
  }

  bool _canUseGenericWriter(RecoveredVagAdaptation item) =>
      item.did.length == 4 && item.options.isNotEmpty;

  String _groupLabel(int g) => switch(g) {
    0 => tx('Destek / Genel'), 1 => tx('Asistan ve Direksiyon'), 2 => tx('Frenler (ABS, ESP, XDS vb.)'),
    3 => tx('Bagaj bölmesi'), 4 => tx('Klima ve Isıtma'), 5 => tx('Gösterge Paneli'),
    6 => tx('Motor ve Güç Aktarımı'), 7 => tx('Dış aydınlatma'), 8 => tx('İç mekan ışıkları'),
    9 => tx('Multimedya / Navigasyon'), 10 => tx('Aynalar'), 11 => tx('Çatı'), 12 => tx('Koltuklar'),
    13 => tx('Geri bildirim sinyalleri'), 14 => 'Silecekler', 15 => tx('Park / Kamera'),
    16 => tx('Servis ve Bakım'), 17 => tx('Konfor'), 18 => tx('Kapılar / Camlar / KESSY'),
    19 => tx('Lastik Basıncı (TPMS)'), 20 => tx('Hırsız alarmı'), 21 => tx('Şasi'),
    22 => tx('Gösterge Aydınlatması'), 23 => tx('Ses Sistemi'), 24 => tx('Römork'), 25 => tx('Şanzıman'),
    26 => tx('Servis Sıfırlama'), 27 => tx('Park Yardımı'), 28 => tx('Sürüş Profili'), 29 => tx('Akü'),
    30 => tx('Dört çeker (4WD)'), _ => tx('Diğer / Grup {0}', [g])
  };
  IconData _groupIcon(int g) => switch(g) {
    1=>Icons.assistant_navigation,2=>Icons.speed_rounded,3=>Icons.airport_shuttle_rounded,4=>Icons.ac_unit_rounded,
    5=>Icons.dashboard_rounded,6=>Icons.settings_rounded,7=>Icons.light_mode_rounded,8=>Icons.lightbulb_outline_rounded,
    9=>Icons.directions_car_filled_rounded,10=>Icons.flip_rounded,11=>Icons.roofing_rounded,12=>Icons.event_seat_rounded,
    13=>Icons.notifications_active_rounded,14=>Icons.water_drop_outlined,16=>Icons.build_circle_outlined,18=>Icons.lock_rounded,
    19=>Icons.tire_repair_rounded,22=>Icons.brightness_6_rounded,23=>Icons.volume_up_rounded,29=>Icons.battery_charging_full_rounded,
    30=>Icons.all_inclusive_rounded,_=>Icons.tune_rounded
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_groupChosenHere,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _groupChosenHere && _selectedGroup != null) {
          setState(() { _selectedGroup = null; _groupChosenHere = false; });
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: _groupChosenHere ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() { _selectedGroup = null; _groupChosenHere = false; })) : null,
        title: Text(widget.customTitle ?? (_selectedGroup == null ? tx('{0} Kodlama', [_platform]) : _groupLabel(_selectedGroup!)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: FutureBuilder<List<RecoveredVagAdaptation>>(
        future: _platformFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 34),
                const SizedBox(height: 10),
                Text(tx('Kodlama kataloğu açılamadı'), style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 9)),
              ]),
            ));
          }
          if (!snapshot.hasData) {
            return Center(child: Text(tx('Kodlama kataloğu boş.')));
          }
          var records = snapshot.data!;
          if (_selectedGroup == null) {
            final groups = <int, int>{};
            for (final item in records) { groups[item.group] = (groups[item.group] ?? 0) + 1; }
            final sorted = groups.keys.toList()..sort((a,b) => _groupLabel(a).compareTo(_groupLabel(b)));
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: [
                Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(14)),child:Text(tx('{0} • {1} kodlama/adaptasyon\nBir bölüm seç; içeride mevcut değeri okuyup desteklenen seçenekleri değiştirebilirsin.', [_platform, records.length]),style:const TextStyle(color:Colors.white70,fontSize:9.5,height:1.45))),
                const SizedBox(height:10),
                if (_platform == 'MQB') ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withValues(alpha: .40)),
                    ),
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VagLightAdaptationScreen()),
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber),
                      ),
                      title: Text(
                        tx('09 MERKEZİ ELEKTRİK • LEUCHTE EDİTÖRÜ'),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        tx('MQB için doğrulanmış Leuchte 0–34 • DID 0550–0572 • Lichtfunktion A–H • Lasttyp • Dimmwert'),
                        style: TextStyle(fontSize: 8.3, color: Colors.white60, height: 1.35),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.amber),
                    ),
                  ),
                ],
                ...sorted.map((g)=>_GroupTile(label:_groupLabel(g),count:groups[g]!,icon:_groupIcon(g),onTap:()=>setState(() { _selectedGroup=g; _groupChosenHere=true; }))),
              ],
            );
          }
          records = records.where((item) => item.group == _selectedGroup).toList(growable:false);
          final q = _query.trim().toLowerCase();
          if (q.isNotEmpty) {
            records = records.where((item) {
              final text = '${item.displayName} ${item.displayDescription} ${item.did} ${item.requestId} ${item.uid}'.toLowerCase();
              return text.contains(q);
            }).toList(growable: false);
          }
          if (_onlyWritable) records = records.where(_canUseGenericWriter).toList(growable: false);

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(children: [
                Row(children: [
                  Expanded(child:Text(_groupLabel(_selectedGroup!),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
                  FilterChip(selected:_onlyWritable,label:Text(tx('Yazılabilir')),onSelected:(value)=>setState(()=>_onlyWritable=value)),
                ]),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: tx('Özellik, DID, ECU adresi veya UID ara'),
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.restore_from_trash_outlined, size: 15, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tx('{0} kayıt • Eski DB okuyucusu kurtarıldı • Okuma tüm standart DID kayıtlarında açık', [records.length]),
                      style: const TextStyle(fontSize: 8.5, color: Colors.white54, fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: records.length,
                itemBuilder: (context, index) => _AdaptationTile(
                  item: records[index],
                  canWrite: _canUseGenericWriter(records[index]),
                ),
              ),
            ),
          ]);
        },
      ),
    ));
  }
}


class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.label,required this.count,required this.icon,required this.onTap});
  final String label; final int count; final IconData icon; final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainer,borderRadius:BorderRadius.circular(13),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),child:ListTile(onTap:onTap,leading:Icon(icon,color:AppColors.accentBright),title:Text(label,style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w700)),subtitle:Text(tx('{0} özellik', [count]),style:const TextStyle(fontSize:8,color:Colors.white54)),trailing:const Icon(Icons.chevron_right_rounded,color:AppColors.accentBright)));
}

class _AdaptationTile extends StatefulWidget {
  const _AdaptationTile({required this.item, required this.canWrite});
  final RecoveredVagAdaptation item;
  final bool canWrite;

  @override
  State<_AdaptationTile> createState() => _AdaptationTileState();
}

class _AdaptationTileState extends State<_AdaptationTile> {
  RecoveredVagAdaptationReadResult? _lastRead;
  bool _busy = false;

  String _groupLabel(int g) => switch(g) {
    0 => tx('Destek / Genel'), 1 => tx('Asistan ve Direksiyon'), 2 => tx('Frenler (ABS, ESP, XDS vb.)'),
    3 => tx('Bagaj bölmesi'), 4 => tx('Klima ve Isıtma'), 5 => tx('Gösterge Paneli'),
    6 => tx('Motor ve Güç Aktarımı'), 7 => tx('Dış aydınlatma'), 8 => tx('İç mekan ışıkları'),
    9 => tx('Multimedya / Navigasyon'), 10 => tx('Aynalar'), 11 => tx('Çatı'), 12 => tx('Koltuklar'),
    13 => tx('Geri bildirim sinyalleri'), 14 => 'Silecekler', 15 => tx('Park / Kamera'),
    16 => tx('Servis ve Bakım'), 17 => tx('Konfor'), 18 => tx('Kapılar / Camlar / KESSY'),
    19 => tx('Lastik Basıncı (TPMS)'), 20 => tx('Hırsız alarmı'), 21 => tx('Şasi'),
    22 => tx('Gösterge Aydınlatması'), 23 => tx('Ses Sistemi'), 24 => tx('Römork'), 25 => tx('Şanzıman'),
    26 => tx('Servis Sıfırlama'), 27 => tx('Park Yardımı'), 28 => tx('Sürüş Profili'), 29 => tx('Akü'),
    30 => tx('Dört çeker (4WD)'), _ => tx('Diğer / Grup {0}', [g])
  };
  IconData _groupIcon(int g) => switch(g) {
    1=>Icons.assistant_navigation,2=>Icons.speed_rounded,3=>Icons.airport_shuttle_rounded,4=>Icons.ac_unit_rounded,
    5=>Icons.dashboard_rounded,6=>Icons.settings_rounded,7=>Icons.light_mode_rounded,8=>Icons.lightbulb_outline_rounded,
    9=>Icons.directions_car_filled_rounded,10=>Icons.flip_rounded,11=>Icons.roofing_rounded,12=>Icons.event_seat_rounded,
    13=>Icons.notifications_active_rounded,14=>Icons.water_drop_outlined,16=>Icons.build_circle_outlined,18=>Icons.lock_rounded,
    19=>Icons.tire_repair_rounded,22=>Icons.brightness_6_rounded,23=>Icons.volume_up_rounded,29=>Icons.battery_charging_full_rounded,
    30=>Icons.all_inclusive_rounded,_=>Icons.tune_rounded
  };

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final locked = !widget.canWrite;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(item.displayName.isEmpty ? 'UID ${item.uid}' : item.displayName,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          _StatusBadge(
            text: locked ? _lockReason(item) : '0x22 / 0x2E',
            active: !locked,
          ),
        ]),
        if (item.displayDescription.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(item.displayDescription, style: const TextStyle(fontSize: 8.5, height: 1.35, color: Colors.white54)),
        ],
        const SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 5, children: [
          _Meta('DID', item.did.isEmpty ? tx('ÖZEL') : item.did),
          _Meta('TX', item.requestId),
          _Meta('RX', item.responseId),
          _Meta('UID', '${item.uid}'),
          if (item.startByteIndex > 0) _Meta('BYTE', '${item.startByteIndex}'),
          if (item.password.isNotEmpty) _Meta('SA', item.password),
        ]),
        if (_lastRead != null) ...[
          const SizedBox(height: 8),
          if (_lastRead!.success && _lastRead!.payload != null) ...[
            Text(tx('MEVCUT DURUM'), style: TextStyle(fontSize: 7, color: Colors.white60, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              RecoveredVagAdaptationService.humanReadableValue(_lastRead!.payload!, item),
              style: const TextStyle(fontSize: 12, height: 1.3, color: Colors.greenAccent, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(_lastRead!.message, style: const TextStyle(fontSize: 8, color: Colors.white54)),
            ExpansionTile(
              tilePadding: EdgeInsets.zero, childrenPadding: EdgeInsets.zero, dense: true,
              title: Text(tx('Teknik ayrıntılar'), style: TextStyle(fontSize: 8, color: Colors.white60)),
              children: [Align(alignment: Alignment.centerLeft, child: Text('HEX ${_lastRead!.currentHex ?? '-'} • DID ${item.did} • TX ${item.requestId} • RX ${item.responseId}', style: const TextStyle(fontSize: 7.5, color: Colors.white60)))],
            ),
          ] else
            Text(_lastRead!.message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.2, height: 1.35, color: Colors.amber)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton.icon(
            onPressed: _busy || item.did.length != 4 ? null : _read,
            icon: const Icon(Icons.download_rounded, size: 14),
            label: Text(_busy ? tx('OKUNUYOR') : tx('OKU'), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 7),
          if (item.options.isNotEmpty)
            FilledButton.icon(
              onPressed: _busy || locked ? null : _chooseOption,
              icon: Icon(locked ? Icons.lock_outline_rounded : Icons.tune_rounded, size: 14),
              label: Text(locked ? tx('YAZMA KİLİTLİ') : tx('DEĞİŞTİR'), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
            ),
        ]),
      ]),
    );
  }

  String _lockReason(RecoveredVagAdaptation item) {
    if (item.hasCustomProcedure && item.password.trim().isEmpty) return tx('ÖZEL PROSEDÜR');
    if (item.hasPasswordRequirement && item.password.trim().isEmpty) return tx('SECURITY KODU BELİRSİZ');
    if (item.did.length != 4) return tx('ÖZEL DID');
    if (item.options.isEmpty) return tx('SAYISAL');
    return tx('GÜVENLİK ECU');
  }

  Future<void> _read() async {
    setState(() => _busy = true);
    final result = await context.read<ObdProvider>().readRecoveredVagAdaptation(widget.item);
    if (mounted) setState(() { _lastRead = result; _busy = false; });
  }

  Future<void> _chooseOption() async {
    final item = widget.item;
    final option = await showModalBottomSheet<RecoveredVagOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          children: [
            Text(item.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(tx('ECU mevcut değeri önce okunacak, otomatik yedek alınacak ve yazma sonrası tekrar doğrulanacak.'),
                style: TextStyle(fontSize: 9, color: Colors.white54, height: 1.4)),
            const SizedBox(height: 10),
            ...item.options.map((opt) => ListTile(
                  dense: true,
                  title: Text(opt.title.isEmpty ? opt.valueSpec : opt.title),
                  subtitle: Text(opt.valueSpec, style: const TextStyle(fontSize: 8, color: Colors.white60)),
                  onTap: () => Navigator.pop(context, opt),
                )),
          ],
        ),
      ),
    );
    if (option == null || !mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx('Adaptasyon yazılsın mı?')),
        content: Text(tx('{0}\n\nYeni değer: {1}\nDID {2} • ECU {3}', [item.displayName, option.title, item.did, item.requestId])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx('VAZGEÇ'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx('YEDEKLE VE YAZ'))),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    String? manualAccessCode;
    if (item.hasPasswordRequirement || item.password.isNotEmpty || item.passwordHints.isNotEmpty) {
      final controller = TextEditingController(text: item.password);
      manualAccessCode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Security Access'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx('Bu ECU erişim anahtarı istiyor. Kayıttaki değer kullanılabilir veya yetkili olduğun anahtarı elle girebilirsin.'), style: TextStyle(fontSize: 9, color: Colors.white70)),
            if (item.passwordHints.isNotEmpty) ...[const SizedBox(height: 6), Text(tx('İpucu: {0}', [item.passwordHints]), style: const TextStyle(fontSize: 8, color: Colors.amber))],
            const SizedBox(height: 10),
            TextField(controller: controller, keyboardType: TextInputType.text, decoration: InputDecoration(labelText: tx('Erişim anahtarı'), hintText: tx('Örn. 20103'))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tx('VAZGEÇ'))),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(tx('DEVAM'))),
          ],
        ),
      );
      controller.dispose();
      if (manualAccessCode == null || manualAccessCode!.trim().isEmpty || !mounted) return;
    }
    setState(() => _busy = true);
    final result = await context.read<ObdProvider>().applyRecoveredVagAdaptation(
          item: item,
          option: option,
          history: context.read<CodingHistoryProvider>(),
          manualAccessCode: manualAccessCode,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), behavior: SnackBarBehavior.floating));
    if (result.success) await _read();
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(7)),
        child: Text('$label $value', style: const TextStyle(fontSize: 7, color: Colors.white54, fontWeight: FontWeight.w600)),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.active});
  final String text;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: (active ? Colors.green : Colors.amber).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(text, style: TextStyle(fontSize: 6.8, color: active ? Colors.green : Colors.amber, fontWeight: FontWeight.w700)),
      );
}
