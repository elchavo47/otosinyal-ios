import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/vag_light_configuration.dart';
import '../providers/coding_history_provider.dart';
import '../providers/obd_provider.dart';
import '../services/recovered_vag_catalog_service.dart';
import '../services/vag_light_configuration_service.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class VagLightAdaptationScreen extends StatefulWidget {
  const VagLightAdaptationScreen({super.key});

  @override
  State<VagLightAdaptationScreen> createState() => _VagLightAdaptationScreenState();
}

class _VagLightAdaptationScreenState extends State<VagLightAdaptationScreen> {
  late final Future<_LightCatalog> _catalogFuture = _loadCatalog();
  VagLightChannel _channel = VagLightConfigurationService.channels[18];
  VagLightConfiguration? _original;
  VagLightConfiguration? _edited;
  bool _reading = false;
  bool _writing = false;
  String? _status;

  Future<_LightCatalog> _loadCatalog() async {
    final functions = await RecoveredVagCatalogService.loadMqbLightFunctions();
    final types = await RecoveredVagCatalogService.loadMqbLightTypes();
    return _LightCatalog(functions, types);
  }

  int _hexInt(String value) => int.tryParse(value, radix: 16) ?? 0;

  bool get _changed {
    final a = _original;
    final b = _edited;
    if (a == null || b == null) return false;
    final ah = VagLightConfigurationService.hex(a.toPayload());
    final bh = VagLightConfigurationService.hex(b.toPayload());
    return ah != bh;
  }

  Future<void> _readChannel() async {
    setState(() {
      _reading = true;
      _status = tx('ECU kanalı okunuyor...');
      _original = null;
      _edited = null;
    });
    final result = await context.read<ObdProvider>().readMqbLightConfiguration(_channel);
    if (!mounted) return;
    setState(() {
      _reading = false;
      _status = result.message;
      _original = result.configuration;
      _edited = result.configuration;
    });
  }

  Future<void> _save() async {
    final edited = _edited;
    final original = _original;
    if (edited == null || original == null || !_changed) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx('Lamba adaptasyonu yazılsın mı?')),
        content: Text(
          tx('{0}\n{1}\n\nDID {2} • 09 BCM\n\nMevcut kanal önce yedeklenecek, sadece bu Leuchte payloadı yazılacak ve ECU’dan tekrar okunup doğrulanacak. Doğrulama tutmazsa eski değer otomatik geri alınacak.', [edited.channel.name, edited.channel.hint, edited.channel.did]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx('VAZGEÇ'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx('YEDEKLE VE YAZ'))),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _writing = true;
      _status = tx('Yedek alınıyor ve ECU yazılıyor...');
    });
    final result = await context.read<ObdProvider>().writeMqbLightConfiguration(
      configuration: edited,
      history: context.read<CodingHistoryProvider>(),
    );
    if (!mounted) return;
    setState(() {
      _writing = false;
      _status = result.message;
    });
    if (result.success) {
      await _readChannel();
    }
  }

  void _update(VagLightConfiguration Function(VagLightConfiguration current) update) {
    final current = _edited;
    if (current == null) return;
    setState(() => _edited = update(current));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tx('Leuchte • Lamba Adaptasyonu'), style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<_LightCatalog>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text(tx('MQB lamba kataloğu yüklenemedi.')));
          }
          final catalog = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              _infoCard(),
              const SizedBox(height: 12),
              _channelPicker(),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _reading || _writing ? null : _readChannel,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(_reading ? tx('OKUNUYOR...') : tx('ECU\'DAN OKU')),
                  ),
                ),
                if (_edited != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: tx('Değişiklikleri geri al'),
                    onPressed: _writing || !_changed ? null : () => setState(() => _edited = _original),
                    icon: const Icon(Icons.undo_rounded),
                  ),
                ],
              ]),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(_status!, style: TextStyle(fontSize: 9, height: 1.35, color: _edited != null ? Colors.greenAccent : Colors.amber)),
              ],
              if (_edited != null) ...[
                const SizedBox(height: 14),
                _channelSummary(catalog),
                const SizedBox(height: 12),
                _sectionTitle(tx('LAMBA TİPİ')),
                _selectField(
                  title: tx('Lamba Tipi (Lasttyp)'),
                  value: _edited!.lampType,
                  entries: catalog.types,
                  onChanged: (v) => _update((c) => c.copyWith(lampType: v)),
                ),
                const SizedBox(height: 12),
                _sectionTitle(tx('ANA / YEDEK FONKSİYONLAR')),
                _functionField(tx('Ana Fonksiyon (Lichtfunktion A)'), _edited!.functionA, catalog.functions, (v) => _update((c) => c.copyWith(functionA: v))),
                _functionField(tx('Boş / Yedek Fonksiyon 1 (Lichtfunktion B)'), _edited!.functionB, catalog.functions, (v) => _update((c) => c.copyWith(functionB: v))),
                _dimmField(tx('Parlaklık A/B (Dimmwert AB)'), _edited!.dimmwertAB, (v) => _update((c) => c.copyWith(dimmwertAB: v))),
                _rawByteField(tx('Kontrol Baytı A/B (Light Control AB)'), _edited!.lightControlAB, (v) => _update((c) => c.copyWith(lightControlAB: v))),
                const SizedBox(height: 12),
                _sectionTitle(tx('EK FONKSİYONLAR C / D')),
                _functionField(tx('Boş / Yedek Fonksiyon 2 (Lichtfunktion C)'), _edited!.functionC, catalog.functions, (v) => _update((c) => c.copyWith(functionC: v))),
                _functionField(tx('Boş / Yedek Fonksiyon 3 (Lichtfunktion D)'), _edited!.functionD, catalog.functions, (v) => _update((c) => c.copyWith(functionD: v))),
                _dimmField(tx('Parlaklık C/D (Dimmwert CD)'), _edited!.dimmwertCD, (v) => _update((c) => c.copyWith(dimmwertCD: v))),
                _rawByteField(tx('Karartma Yönü C/D (Dimming Direction CD)'), _edited!.dimmingDirectionCD, (v) => _update((c) => c.copyWith(dimmingDirectionCD: v))),
                const SizedBox(height: 12),
                _sectionTitle(tx('EK FONKSİYONLAR E / F')),
                _functionField(tx('Boş / Yedek Fonksiyon 4 (Lichtfunktion E)'), _edited!.functionE, catalog.functions, (v) => _update((c) => c.copyWith(functionE: v))),
                _functionField(tx('Boş / Yedek Fonksiyon 5 (Lichtfunktion F)'), _edited!.functionF, catalog.functions, (v) => _update((c) => c.copyWith(functionF: v))),
                _dimmField(tx('Parlaklık E/F (Dimmwert EF)'), _edited!.dimmwertEF, (v) => _update((c) => c.copyWith(dimmwertEF: v))),
                _rawByteField(tx('Karartma Yönü E/F (Dimming Direction EF)'), _edited!.dimmingDirectionEF, (v) => _update((c) => c.copyWith(dimmingDirectionEF: v))),
                const SizedBox(height: 12),
                _sectionTitle(tx('EK FONKSİYONLAR G / H')),
                _functionField(tx('Boş / Yedek Fonksiyon 6 (Lichtfunktion G)'), _edited!.functionG, catalog.functions, (v) => _update((c) => c.copyWith(functionG: v))),
                _functionField(tx('Boş / Yedek Fonksiyon 7 (Lichtfunktion H)'), _edited!.functionH, catalog.functions, (v) => _update((c) => c.copyWith(functionH: v))),
                _dimmField(tx('Parlaklık G/H (Dimmwert GH)'), _edited!.dimmwertGH, (v) => _update((c) => c.copyWith(dimmwertGH: v))),
                _rawByteField(tx('Karartma Yönü G/H (Dimming Direction GH)'), _edited!.dimmingDirectionGH, (v) => _update((c) => c.copyWith(dimmingDirectionGH: v))),
                const SizedBox(height: 15),
                _hexPreview(),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _writing || !_changed ? null : _save,
                    icon: _writing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(_writing ? tx('YAZILIYOR...') : _changed ? tx('DEĞİŞİKLİKLERİ YEDEKLE VE YAZ') : tx('DEĞİŞİKLİK YOK')),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _infoCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentBright.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentBright.withValues(alpha: .42)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_rounded, color: AppColors.accentBright, size: 27),
          SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx('09 • MQB LEUCHTE EDITÖRÜ'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text(tx('Kanalı seç, ECU’dan mevcut değerleri oku; anlaşılır Türkçe alanlardan ana/boş fonksiyonları ve parlaklığı düzenle. Parantez içinde gerçek VAG adları korunur. Yazmadan önce otomatik yedek, yazma sonrası read-back doğrulama ve hata halinde rollback kullanılır.'), style: TextStyle(fontSize: 9, color: Colors.white60, height: 1.4)),
          ])),
        ]),
      );

  Widget _channelPicker() => DropdownButtonFormField<VagLightChannel>(
        value: _channel,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: tx('Leuchte kanalı'),
          prefixIcon: Icon(Icons.electrical_services_rounded),
          helperText: 'MQB • DID 0550–0572',
        ),
        items: VagLightConfigurationService.channels
            .map((c) => DropdownMenuItem(
                  value: c,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                    Text('${c.hint} • DID ${c.did}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.8, color: Colors.white54)),
                  ]),
                ))
            .toList(growable: false),
        onChanged: _reading || _writing
            ? null
            : (value) {
                if (value == null) return;
                setState(() {
                  _channel = value;
                  _original = null;
                  _edited = null;
                  _status = null;
                });
              },
      );

  Widget _channelSummary(_LightCatalog catalog) {
    final c = _edited!;
    String fn(int value) => catalog.functions[value.toRadixString(16).padLeft(2, '0').toUpperCase()] ?? '0x${value.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.channel.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          Text('DID ${c.channel.did}', style: const TextStyle(fontSize: 8, color: AppColors.accentBright, fontWeight: FontWeight.w800)),
        ]),
        if (c.channel.hint.isNotEmpty) Text(c.channel.hint, style: const TextStyle(fontSize: 8.5, color: Colors.white54)),
        const SizedBox(height: 7),
        Text('A: ${fn(c.functionA)}\nB: ${fn(c.functionB)}', style: const TextStyle(fontSize: 8.5, height: 1.45, color: Colors.white70)),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.accentBright, letterSpacing: .7)),
      );

  bool _looksInactiveLabel(String text) {
    final t = text.toLowerCase();
    return t.contains('not active') || t.contains('nicht aktiv') || t.contains('inactive') || t.contains('pasif');
  }

  Widget _functionField(String title, int value, Map<String, String> entries, ValueChanged<int> onChanged) {
    final key = value.toRadixString(16).padLeft(2, '0').toUpperCase();
    final label = entries[key] ?? '';
    final inactive = _looksInactiveLabel(label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inactive)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.greenAccent),
              SizedBox(width: 5),
              Text(tx('BOŞ FONKSİYON ALANI • yeni işlev atanabilir'), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.greenAccent)),
            ]),
          ),
        _selectField(title: title, value: value, entries: entries, onChanged: onChanged),
      ],
    );
  }

  Widget _selectField({required String title, required int value, required Map<String, String> entries, required ValueChanged<int> onChanged}) {
    final values = entries.entries.map((e) => MapEntry(_hexInt(e.key), e.value)).toList(growable: true);
    if (!values.any((e) => e.key == value)) {
      values.add(MapEntry(value, tx('Bilinmeyen / ECU değeri 0x{0}', [value.toRadixString(16).padLeft(2, '0').toUpperCase()])));
    }
    values.sort((a, b) => a.key.compareTo(b.key));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<int>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: title, isDense: true),
        items: values
            .map((e) => DropdownMenuItem<int>(
                  value: e.key,
                  child: Text('0x${e.key.toRadixString(16).padLeft(2, '0').toUpperCase()} • ${e.value}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.2)),
                ))
            .toList(growable: false),
        onChanged: _writing ? null : (v) { if (v != null) onChanged(v); },
      ),
    );
  }

  Widget _dimmField(String title, int value, ValueChanged<int> onChanged) {
    final raw = value.clamp(0, 127).toInt();
    final percent = ((raw / 127) * 100).round().clamp(0, 100);
    int percentToRaw(double p) => ((p.clamp(0, 100) / 100) * 127).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(tx('Kullanıcı değeri yüzde olarak gösterilir. ECU için gerekli ham Dimmwert otomatik hesaplanır.'), style: TextStyle(fontSize: 7.5, color: Colors.white60)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.accentBright.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Text('%$percent', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.accentBright)),
          ),
        ]),
        Slider(
          value: percent.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          label: '%$percent',
          onChanged: _writing ? null : (v) => onChanged(percentToRaw(v)),
        ),
        Text(tx('Ham ECU değeri: {0} / 127', [raw]), style: const TextStyle(fontSize: 7.5, color: Colors.white60)),
      ]),
    );
  }

  Widget _rawByteField(String title, int value, ValueChanged<int> onChanged) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(tx('Recovery motorundaki ham byte. Mevcut değeri bilmiyorsan değiştirme.'), style: TextStyle(fontSize: 7.5, color: Colors.white60)),
          ])),
          IconButton(onPressed: _writing || value <= 0 ? null : () => onChanged(value - 1), icon: const Icon(Icons.remove_circle_outline_rounded, size: 19)),
          Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          IconButton(onPressed: _writing || value >= 255 ? null : () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline_rounded, size: 19)),
        ]),
      );

  Widget _hexPreview() {
    final original = _original!;
    final edited = _edited!;
    final before = VagLightConfigurationService.hex(original.toPayload());
    final after = VagLightConfigurationService.hex(edited.toPayload());
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(_changed ? tx('Teknik veri • değişiklik var') : tx('Teknik veri'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _changed ? Colors.amber : Colors.white54)),
      children: [
        Align(alignment: Alignment.centerLeft, child: SelectableText(tx('ÖNCE  {0}\nSONRA {1}', [before, after]), style: const TextStyle(fontSize: 8, height: 1.5, color: Colors.white54))),
      ],
    );
  }
}

class _LightCatalog {
  const _LightCatalog(this.functions, this.types);
  final Map<String, String> functions;
  final Map<String, String> types;
}
