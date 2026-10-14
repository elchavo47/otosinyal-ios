import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/obd_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class EcuModulesScreen extends StatelessWidget {
  const EcuModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final obd = context.watch<ObdProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(tx('ECU MODÜLLERİ'), style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _Hero(obd: obd),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: !obd.canQueryDtc || obd.isDiscoveringEcuModules
                  ? null
                  : () => context.read<ObdProvider>().discoverEcuModules(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: obd.isDiscoveringEcuModules
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.account_tree_rounded),
              label: Text(obd.isDiscoveringEcuModules ? tx('ECU’lar aranıyor...') : tx('ECU MODÜLLERİNİ KEŞFET'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            if (obd.ecuDiscoveryError != null) ...[
              const SizedBox(height: 12),
              _Banner(text: obd.ecuDiscoveryError!, color: AppColors.warning),
            ],
            const SizedBox(height: 18),
            Text(tx('YANIT VEREN OBD-II ECU’LAR'), style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            const SizedBox(height: 10),
            if (obd.ecuModules.isEmpty)
              const _EmptyState()
            else
              ...obd.ecuModules.map((module) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.white.withValues(alpha: .07)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.memory_rounded, color: AppColors.accentBright),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(module.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                                _IdBadge(module.canId),
                              ]),
                              const SizedBox(height: 7),
                              _line(tx('ECU adı'), module.ecuName),
                              _line(tx('Kalibrasyon ID'), module.calibrationId),
                              _line('CVN', module.cvn),
                              _line(tx('Protokol'), obd.protocolName ?? obd.adapterInfo.protocol),
                              _line(tx('CAN yanıt adresi'), module.canId),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 8),
            _Banner(
              text: tx('Bu tarama SAE Mode 09 üzerinden güvenli okuma yapar. Motor/şanzıman gibi OBD-II emisyon cevaplayıcılarını keşfeder; ABS, airbag ve gövde modüllerini varmış gibi uydurmaz.'),
              color: AppColors.info,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _line(String title, String? value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted),
            children: [
              TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: value == null || value.trim().isEmpty ? '—' : value, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.obd});
  final ObdProvider obd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2B0A0C), Color(0xFF111111)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentBorder),
        ),
        child: Row(children: [
          const Icon(Icons.hub_rounded, size: 33, color: AppColors.accentBright),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx('Elektronik güç aktarma haritası'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              obd.canQueryDtc ? tx('{0} • {1} ECU kimliği', [obd.protocolName ?? 'OBD-II', obd.ecuModules.length]) : tx('Önce gerçek OBD2 bağlantısını başlat.'),
              style: const TextStyle(color: Colors.white60, fontSize: 10.5),
            ),
          ])),
        ]),
      );
}

class _IdBadge extends StatelessWidget {
  const _IdBadge(this.id);
  final String id;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFF171719), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
        child: Text(id, style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Icon(Icons.memory_outlined, color: Colors.white24, size: 42),
          SizedBox(height: 10),
          Text(tx('Henüz modül keşfi yapılmadı'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          SizedBox(height: 5),
          Text(tx('Bağlandıktan sonra üstteki taramayı başlat.'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: .25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.45))),
        ]),
      );
}
