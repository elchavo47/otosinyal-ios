import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/providers/connection_mode_provider.dart';
import 'package:otosinyal_obd2/providers/usb_obd_provider.dart';
import 'package:otosinyal_obd2/providers/wifi_obd_provider.dart';
import 'package:otosinyal_obd2/widget/connection/bluetooth/bluetooth_tab.dart';
import 'package:otosinyal_obd2/widget/connection/bluetooth/bluetooth_waiting_widget.dart';
import 'package:otosinyal_obd2/widget/connection/connection_screen/custom_tab_bar.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  ConnectionTab _selectedTab = ConnectionTab.bluetooth;
  bool _isBluetoothActivated = false;

  @override
  void initState() {
    super.initState();
    final mode = context.read<ConnectionModeProvider>().mode;
    _selectedTab = switch (mode) {
      ConnectionMode.wifi => ConnectionTab.wifi,
      ConnectionMode.usb => Platform.isIOS ? ConnectionTab.bluetooth : ConnectionTab.usb,
      ConnectionMode.classic => ConnectionTab.bluetooth,
      ConnectionMode.ble => ConnectionTab.bluetooth,
    };
  }

  void _selectTab(ConnectionTab tab) {
    setState(() => _selectedTab = tab);
    final mode = context.read<ConnectionModeProvider>();
    switch (tab) {
      case ConnectionTab.bluetooth:
        if (mode.mode != ConnectionMode.ble && mode.mode != ConnectionMode.classic) {
          mode.setMode(ConnectionMode.ble);
        }
      case ConnectionTab.wifi:
        mode.setMode(ConnectionMode.wifi);
      case ConnectionTab.usb:
        mode.setMode(ConnectionMode.usb);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const _ConnectionHero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _AnimatedTabBar(selectedTab: _selectedTab, onTabSelected: _selectTab),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(
                  key: ValueKey(_selectedTab),
                  child: switch (_selectedTab) {
                    ConnectionTab.bluetooth => _BluetoothPanel(activated: _isBluetoothActivated, onActivate: () => setState(() => _isBluetoothActivated = true)),
                    ConnectionTab.wifi => const _WifiPanel(),
                    ConnectionTab.usb => const _UsbPanel(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(gradient: AppColors.vipGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .35), blurRadius: 22)]), child: const Icon(Icons.hub_rounded, color: Colors.white, size: 25)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx('BAĞLANTI MERKEZİ'), style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)), SizedBox(height: 3), Text(tx('ECU ile güvenli köprü kur'), style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))])),
        IconButton(tooltip:tx('Bağlantı yardımı'),onPressed:()=>_showConnectionGuide(context),icon:const Icon(Icons.help_outline_rounded,color:AppColors.textMuted)),
        const _LiveDot(),
      ]),
    );
  }

  void _showConnectionGuide(BuildContext context){
    showModalBottomSheet<void>(context:context,useRootNavigator:true,showDragHandle:true,builder:(sheetContext)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,4,20,24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(tx('OBD bağlantı sihirbazı'),style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:6),Text(tx('Bağlantı kurulmazsa sırayla bunları kontrol et.'),style:TextStyle(color:Theme.of(sheetContext).colorScheme.onSurfaceVariant,fontSize:11)),
      const SizedBox(height:14),
      _GuideStep(number:'1',title:tx('Adaptörü OBD portuna tak'),body:tx('Adaptör ışıklarının yandığını kontrol et.')),
      _GuideStep(number:'2',title:tx('Kontağı aç'),body:tx('Motoru çalıştırmak gerekmez; gösterge ışıkları açık olsun.')),
      _GuideStep(number:'3',title:tx('Doğru bağlantı türünü seç'),body:tx('Vgate BLE için Bluetooth LE, ELM Wi‑Fi için Wi‑Fi. iPhone standart Bluetooth Classic SPP ve USB ELM327 bağlantısını desteklemez.')),
      _GuideStep(number:'4',title:tx('Diğer OBD uygulamalarını kapat'),body:tx('Adaptöre aynı anda yalnız bir uygulama bağlanabilir.')),
      const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(sheetContext),child:Text(tx('TAMAM'),style:TextStyle(fontWeight:FontWeight.w900)))),
    ]))));
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number,required this.title,required this.body});
  final String number,title,body;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:11),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:27,height:27,alignment:Alignment.center,decoration:const BoxDecoration(color:AppColors.accent,shape:BoxShape.circle),child:Text(number,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:11))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:2),Text(body,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,fontSize: 11,height:1.35))]))]));
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween<double>(begin: .35, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)), child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)));
}

class _AnimatedTabBar extends StatelessWidget {
  const _AnimatedTabBar({required this.selectedTab, required this.onTabSelected});
  final ConnectionTab selectedTab;
  final ValueChanged<ConnectionTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .08))),
      child: Row(children: ConnectionTab.values.where((tab) => !Platform.isIOS || tab != ConnectionTab.usb).map((tab) {
        final active = selectedTab == tab;
        final icon = switch (tab) { ConnectionTab.bluetooth => Icons.bluetooth_rounded, ConnectionTab.wifi => Icons.wifi_rounded, ConnectionTab.usb => Icons.usb_rounded };
        final text = switch (tab) { ConnectionTab.bluetooth => 'Bluetooth', ConnectionTab.wifi => 'Wi‑Fi', ConnectionTab.usb => 'OTG USB' };
        return Expanded(child: GestureDetector(onTap: () => onTabSelected(tab), child: AnimatedContainer(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(gradient: active ? AppColors.vipGradient : null, color: active ? null : Colors.transparent, borderRadius: BorderRadius.circular(15), boxShadow: active ? [BoxShadow(color: AppColors.accent.withValues(alpha: .2), blurRadius: 14)] : null), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: active ? Colors.white : AppColors.textMuted), const SizedBox(width: 6), Text(text, style: TextStyle(color: active ? Colors.white : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900))]))));
      }).toList()),
    );
  }
}

class _BluetoothPanel extends StatelessWidget {
  const _BluetoothPanel({required this.activated, required this.onActivate});
  final bool activated;
  final VoidCallback onActivate;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: activated ? const BluetoothTab() : BluetoothWaitingWidget(onActivate: onActivate));
}

class _WifiPanel extends StatefulWidget {
  const _WifiPanel();
  @override
  State<_WifiPanel> createState() => _WifiPanelState();
}

class _WifiPanelState extends State<_WifiPanel> {
  late final TextEditingController _host = TextEditingController(text: context.read<WifiObdProvider>().host);
  late final TextEditingController _port = TextEditingController(text: '${context.read<WifiObdProvider>().port}');
  @override
  void dispose() { _host.dispose(); _port.dispose(); super.dispose(); }

  Future<void> _connect(WifiObdProvider provider) async {
    final port = int.tryParse(_port.text.trim());
    if (port == null) { _message(tx('Port numarası geçersiz')); return; }
    final ok = await provider.connect(host: _host.text, port: port);
    if (!ok && mounted) _message(provider.error ?? tx('Wi‑Fi bağlantısı kurulamadı'));
  }
  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Consumer<WifiObdProvider>(builder: (_, provider, __) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
    _TransportIntro(icon: Icons.wifi_tethering_rounded, title: 'Wi‑Fi OBD', subtitle: tx('Telefonu adaptörün oluşturduğu Wi‑Fi ağına bağla. OTOSİNYAL TCP üzerinden ELM327 komutlarını gönderir.')),
    const SizedBox(height: 14),
    _SectionCard(title: tx('ADAPTÖR AĞI'), icon: Icons.router_rounded, child: Column(children: [
      TextField(controller: _host, keyboardType: TextInputType.url, autocorrect: false, decoration: InputDecoration(labelText: tx('Adaptör IP adresi'), hintText: '192.168.0.10', prefixIcon: Icon(Icons.lan_rounded))),
      const SizedBox(height: 10),
      TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'TCP port', hintText: '35000', prefixIcon: Icon(Icons.settings_ethernet_rounded))),
      const SizedBox(height: 12),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _PresetChip(label: 'ELM Wi‑Fi', onTap: () => setState(() { _host.text = '192.168.0.10'; _port.text = '35000'; })),
        _PresetChip(label: 'ESP / 35000', onTap: () => setState(() { _host.text = '192.168.4.1'; _port.text = '35000'; })),
        _PresetChip(label: 'Port 23', onTap: () => setState(() => _port.text = '23')),
      ]),
    ])),
    const SizedBox(height: 12),
    _ConnectionStateCard(connected: provider.isConnected, connecting: provider.isConnecting, label: provider.isConnected ? tx('Wi‑Fi ECU köprüsü hazır') : tx('Wi‑Fi adaptör bekleniyor'), detail: provider.error),
    const SizedBox(height: 12),
    SizedBox(height: 54, child: ElevatedButton.icon(onPressed: provider.isConnecting ? null : (provider.isConnected ? provider.disconnect : () => _connect(provider)), icon: Icon(provider.isConnected ? Icons.link_off_rounded : Icons.link_rounded), label: Text(provider.isConnected ? tx('BAĞLANTIYI KES') : tx('Wİ‑Fİ OBD’YE BAĞLAN')))),
    const SizedBox(height: 12),
    _SafetyNote(text: tx('Bu katman yalnızca TCP ELM327 komutları gönderir. Araç modüllerinde yazma, kodlama veya aktüatör çalıştırma yapmaz.')),
  ]));
}

class _UsbPanel extends StatefulWidget {
  const _UsbPanel();
  @override
  State<_UsbPanel> createState() => _UsbPanelState();
}

class _UsbPanelState extends State<_UsbPanel> {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<UsbObdProvider>().refresh()); }
  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return Center(child: _SafetyNote(text: tx('OTG USB ELM bağlantısı Android USB Host içindir. iPhone/iPad üzerinde Bluetooth veya Wi‑Fi kullanmalısın.')));
    return Consumer<UsbObdProvider>(builder: (_, provider, __) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
      _TransportIntro(icon: Icons.usb_rounded, title: 'OTG USB OBD', subtitle: tx('FTDI, CDC, CP210x, CH34x ve benzeri USB‑serial ELM327 kablolarını tarar.')),
      const SizedBox(height: 14),
      _SectionCard(title: tx('SERİ İLETİŞİM HIZI'), icon: Icons.speed_rounded, child: DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: provider.preferredBaudRate ?? -1, dropdownColor: AppColors.cardElevated, icon: const Icon(Icons.expand_more_rounded), items: [DropdownMenuItem<int>(value: -1, child: Text(tx('Otomatik dene • 9600 / 38400 / 115200'))), ...UsbObdProvider.supportedBaudRates.map((baud) => DropdownMenuItem<int>(value: baud, child: Text('$baud baud')))], onChanged: provider.isConnecting ? null : (value) => provider.setBaudPreference(value == -1 ? null : value)))),
      const SizedBox(height: 12),
      _SectionCard(title: tx('USB CİHAZLARI'), icon: Icons.cable_rounded, trailing: IconButton(onPressed: provider.isConnecting ? null : provider.refresh, icon: const Icon(Icons.refresh_rounded)), child: provider.devices.isEmpty ? Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Column(children: [Icon(Icons.usb_off_rounded, color: AppColors.textMuted, size: 34), SizedBox(height: 8), Text(tx('USB OBD bulunamadı'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text(tx('OTG dönüştürücüyü ve aracı kontrol edip yenileye bas.'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11))])) : Column(children: provider.devices.map((device) => _UsbDeviceTile(device: device, provider: provider)).toList())),
      const SizedBox(height: 12),
      _ConnectionStateCard(connected: provider.isConnected, connecting: provider.isConnecting, label: provider.isConnected ? tx('USB seri köprüsü hazır') : tx('USB cihaz seçilmedi'), detail: provider.error),
      const SizedBox(height: 12),
      _SafetyNote(text: tx('USB izni Android tarafından her kablo için ayrı istenebilir. Uygulama yalnızca ELM/OBD ASCII komutları kullanır; flaşlama ve kodlama kapalıdır.')),
    ]));
  }
}

class _UsbDeviceTile extends StatelessWidget {
  const _UsbDeviceTile({required this.device, required this.provider});
  final dynamic device;
  final UsbObdProvider provider;
  @override
  Widget build(BuildContext context) {
    final selected = provider.selectedDevice == device;
    return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: selected ? AppColors.accent.withValues(alpha: .12) : Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.accent : Colors.white.withValues(alpha: .08))), child: ListTile(leading: const Icon(Icons.usb_rounded, color: AppColors.accentCyan), title: Text(provider.deviceLabel(device), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), subtitle: Text(tx('USB seri ELM327 • {0}', [provider.baudLabel]), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)), trailing: FilledButton(onPressed: provider.isConnecting ? null : (provider.isConnected && selected ? provider.disconnect : () => provider.connect(device)), child: Text(provider.isConnected && selected ? tx('KES') : tx('BAĞLAN'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)))));
  }
}

class _TransportIntro extends StatelessWidget {
  const _TransportIntro({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => _GlassCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: AppColors.accentBright, size: 25)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.45))]))]));
}

class _ConnectionStateCard extends StatelessWidget {
  const _ConnectionStateCard({required this.connected, required this.connecting, required this.label, this.detail});
  final bool connected;
  final bool connecting;
  final String label;
  final String? detail;
  @override
  Widget build(BuildContext context) => _GlassCard(child: Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 250), width: 12, height: 12, decoration: BoxDecoration(color: connecting ? AppColors.warning : connected ? AppColors.success : AppColors.textMuted, shape: BoxShape.circle, boxShadow: connected ? [BoxShadow(color: AppColors.success.withValues(alpha: .55), blurRadius: 13)] : null)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), if (detail != null) Text(detail!, style: const TextStyle(color: AppColors.warning, fontSize: 10))]))]));
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child, this.trailing});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: AppColors.accentCyan, size: 18), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8))), if (trailing != null) trailing!]), const SizedBox(height: 12), child]));
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(gradient: AppColors.glassGradient, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .08)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 20, offset: const Offset(0, 8))]), child: child);
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), onPressed: onTap, avatar: const Icon(Icons.bolt_rounded, size: 14));
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.info.withValues(alpha: .08), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.info.withValues(alpha: .25))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.verified_user_rounded, color: AppColors.info, size: 18), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.4)))]));
}
