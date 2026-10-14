import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/garage_provider.dart';
import '../providers/obd_provider.dart';
import '../services/ai_mechanic_service.dart';
import '../services/diagnostic_ai_prompt_builder.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class AiMechanicScreen extends StatefulWidget {
  const AiMechanicScreen({super.key});

  @override
  State<AiMechanicScreen> createState() => _AiMechanicScreenState();
}

class _AiMechanicScreenState extends State<AiMechanicScreen> {
  final _controller = TextEditingController();
  final List<_Message> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = context.watch<GarageProvider>().activeVehicle;
    final obd = context.watch<ObdProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx('AI MEKANİK'), style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8)),
          Text(tx('Gerçek OBD verisiyle analiz'), style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w500)),
        ]),
        actions: [IconButton(onPressed: _configureEndpoint, tooltip: tx('AI sunucusu'), icon: const Icon(Icons.settings_ethernet_rounded))],
      ),
      body: SafeArea(
        child: Column(children: [
          if (vehicle == null)
            _InfoBanner(text: tx('Önce Garaj bölümünden aktif araç seç.'), color: AppColors.warning)
          else if (!obd.canQueryDtc)
            _InfoBanner(text: tx('OBD bağlı değil. Soru sorabilirsin ama canlı ECU bağlamı eksik olacak.'), color: AppColors.info),
          Expanded(
            child: _messages.isEmpty
                ? ListView(padding: const EdgeInsets.all(18), children: [
                    const SizedBox(height: 22),
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle, border: Border.all(color: AppColors.accentBorder)),
                      child: const Icon(Icons.psychology_alt_rounded, color: AppColors.accentBright, size: 38),
                    ),
                    const SizedBox(height: 18),
                    Text(tx('Aracına göre sor'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(tx('DTC, canlı sensörler, readiness ve keşfedilen ECU kimlikleri soruya otomatik eklenir. Olmayan veri uydurulmaz.'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, height: 1.5, fontSize: 11)),
                    const SizedBox(height: 22),
                    if (vehicle != null) _LocalPreAnalysis(text: DiagnosticAiPromptBuilder.localPreAnalysis(obd)),
                    const SizedBox(height: 12),
                    _QuickQuestion(text: tx('Bu arıza kodlarını öncelik sırasına koy'), onTap: _useQuestion),
                    _QuickQuestion(text: tx('Canlı verilerde anormal görünen ne var?'), onTap: _useQuestion),
                    _QuickQuestion(text: tx('Aracı kullanmaya devam etmek güvenli mi?'), onTap: _useQuestion),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _Bubble(message: _messages[i]),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: const BoxDecoration(color: Color(0xFF080808), border: Border(top: BorderSide(color: Color(0xFF211718)))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_sending && vehicle != null,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: vehicle == null ? tx('Önce araç seç...') : tx('AI Mekaniğe sor...'),
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending || vehicle == null ? null : _send,
                style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _useQuestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    final vehicle = context.read<GarageProvider>().activeVehicle;
    if (vehicle == null) return;
    final obd = context.read<ObdProvider>();
    final prompt = DiagnosticAiPromptBuilder.build(vehicle: vehicle, obd: obd, question: question);

    setState(() {
      _messages.add(_Message(question, true));
      _controller.clear();
      _sending = true;
    });
    try {
      final answer = await AiMechanicService.ask(prompt: prompt, question: question);
      if (!mounted) return;
      setState(() => _messages.add(_Message(answer, false)));
    } catch (e) {
      if (!mounted) return;
      final endpoint = await AiMechanicService.getEndpoint();
      if (!mounted) return;
      final fallback = endpoint.isEmpty
          ? tx('AI sunucusu henüz tanımlı değil. Sağ üstteki ağ ayarından kendi HTTPS backend adresini gir.\n\nYerel ön analiz:\n{0}', [DiagnosticAiPromptBuilder.localPreAnalysis(obd)])
          : tx('AI sunucusuna ulaşılamadı: {0}\n\nYerel ön analiz:\n{1}', [e, DiagnosticAiPromptBuilder.localPreAnalysis(obd)]);
      setState(() => _messages.add(_Message(fallback, false)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _configureEndpoint() async {
    final current = await AiMechanicService.getEndpoint();
    if (!mounted) return;
    final controller = TextEditingController(text: current);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151011),
        title: Text(tx('AI backend adresi'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx('API anahtarı uygulamaya gömülmez. HTTPS backend adresini gir; OTOSİNYAL teşhis bağlamını JSON POST ile yollar.'), style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
          const SizedBox(height: 12),
          TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'https://.../api/ai', hintStyle: TextStyle(color: Colors.white30))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('Vazgeç'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(tx('Kaydet'))),
        ],
      ),
    );
    controller.dispose();
    if (saved != null) {
      await AiMechanicService.setEndpoint(saved);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('AI backend adresi kaydedildi.'))));
    }
  }
}

class _Message {
  const _Message(this.text, this.user);
  final String text;
  final bool user;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _Message message;
  @override
  Widget build(BuildContext context) => Align(
        alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: message.user ? AppColors.accentDark : AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: message.user ? AppColors.accentBorder : Colors.white10),
          ),
          child: Text(message.text, style: const TextStyle(color: Colors.white, height: 1.45, fontSize: 12)),
        ),
      );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withValues(alpha: .25))),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
      );
}

class _LocalPreAnalysis extends StatelessWidget {
  const _LocalPreAnalysis({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx('YEREL ÖN ANALİZ'), style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 7),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.45)),
        ]),
      );
}

class _QuickQuestion extends StatelessWidget {
  const _QuickQuestion({required this.text, required this.onTap});
  final String text;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => onTap(text),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
            child: Row(children: [Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))), const Icon(Icons.chevron_right_rounded, color: AppColors.accentBright)]),
          ),
        ),
      );
}
