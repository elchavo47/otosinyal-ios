import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/data/vehicle_brands.dart';
import 'package:otosinyal_obd2/data/brand_assets.dart';
import 'package:otosinyal_obd2/models/vehicle.dart';
import 'package:otosinyal_obd2/providers/garage_provider.dart';
import 'package:otosinyal_obd2/providers/obd_provider.dart';
import 'package:otosinyal_obd2/providers/dtc_history_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class CarScreen extends StatelessWidget {
  const CarScreen({super.key, this.showBack = true});

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GarageHeader(showBack: showBack),
            Padding(padding:EdgeInsets.fromLTRB(16,0,16,8),child:Text(tx('Araç seçimi bağlantı için zorunlu değildir. VIN okununca eşleşen araç otomatik aktif olur ve geçmiş kayıtları kendi profilinde tutulur.'),style:TextStyle(color:Colors.white54,fontSize:10,height:1.35))),
            Expanded(
              child: Consumer<GarageProvider>(
                builder: (context, garage, _) {
                  if (garage.vehicles.isEmpty) {
                    return Center(
                      child: _EmptyGarageCard(
                        onAdd: () => _openAddVehicleSheet(context),
                      ),
                    );
                  }
                  return _VehicleList(
                    garage: garage,
                    onAdd: () => _openAddVehicleSheet(context),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddVehicleSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddVehicleSheet(),
    );
  }
}

class _GarageHeader extends StatelessWidget {
  const _GarageHeader({required this.showBack});

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            if (showBack)
              IconButton(padding:EdgeInsets.zero,constraints:const BoxConstraints.tightFor(width:38,height:38),onPressed:()=>Navigator.of(context).pop(),icon:const Icon(Icons.arrow_back_ios_new_rounded,size:17,color:Colors.white70))
            else
              const SizedBox(width: 38, height: 38),
            const Spacer(),
            Text(tx('Garajım'), style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _AddVehicleSheet(),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleList extends StatelessWidget {
  final GarageProvider garage;
  final VoidCallback onAdd;

  const _VehicleList({required this.garage, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      itemCount: garage.vehicles.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == garage.vehicles.length) {
          return SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(tx('YENİ ARAÇ EKLE'), style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          );
        }
        final vehicle = garage.vehicles[index];
        final isActive = vehicle.id == garage.activeVehicleId;
        final scans = context.watch<DtcHistoryProvider>().forVehicle(vehicle.id);
        final latestCodeCount = scans.isEmpty ? 0 : scans.first.stored.length + scans.first.pending.length + scans.first.permanent.length;

        return Dismissible(
          key: ValueKey(vehicle.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
          confirmDismiss: (_) => _confirmDelete(context, vehicle),
          onDismissed: (_) => garage.removeVehicle(vehicle.id),
          child: GestureDetector(
            onTap: () => garage.setActiveVehicle(vehicle.id),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isActive
                      ? const [Color(0xFF2A0B0E), Color(0xFF110D0E)]
                      : const [Color(0xFF121212), Color(0xFF0C0C0C)],
                ),
                border: Border.all(
                  width: 1,
                  color: isActive ? AppColors.accentBorder : const Color(0xFF2C2728),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF1B1112),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: BrandAssets.logoFor(vehicle.brand) == null
                          ? const Icon(Icons.directions_car_filled_rounded, color: AppColors.accentBright, size: 32)
                          : Image.asset(
                              BrandAssets.logoFor(vehicle.brand)!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_filled_rounded, color: AppColors.accentBright, size: 32),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.displayName.isEmpty
                              ? tx('İsimsiz Araç')
                              : vehicle.displayName,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(tx('{0} arıza taraması • Son kayıtta {1} kod', [scans.length, latestCodeCount]),style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w600,color:latestCodeCount>0?AppColors.danger:Colors.white38)),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (vehicle.plate.isNotEmpty) vehicle.plate,
                            if (vehicle.year != null) vehicle.year.toString(),
                          ].join(' · '),
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        tx('AKTİF'),
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Vehicle vehicle) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151011),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tx('Aracı sil?'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          tx('{0} garajdan kaldırılacak.', [vehicle.displayName.isEmpty ? tx('Bu araç') : vehicle.displayName]),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tx('Vazgeç'), style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tx('Sil'), style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _EmptyGarageCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyGarageCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          color: Theme.of(context).colorScheme.surfaceContainer,
          border: Border.all(
            width: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(36)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAdd,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tx('Araç yok'),
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tx('İlk aracınızı\nekleyin'),
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(180),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: 250,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: Text(
                      tx('Araç Ekle'),
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddVehicleSheet extends StatefulWidget {
  const _AddVehicleSheet();

  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  final _generationController = TextEditingController();
  final _engineController = TextEditingController();
  final _engineCodeController = TextEditingController();

  String? _selectedBrand;
  String? _selectedModel;
  FuelType _fuelType = FuelType.gasoline;

  @override
  void initState() {
    super.initState();
    // Bağlıysan ve VIN'den marka tahmin edildiyse formu otomatik doldur.
    final detected = context.read<ObdProvider>().detectedBrand;
    if (detected != null && vehicleBrands.containsKey(detected)) {
      _selectedBrand = detected;
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _yearController.dispose();
    _generationController.dispose();
    _engineController.dispose();
    _engineCodeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrand == null || _selectedModel == null) return;

    context.read<GarageProvider>().addVehicle(
      brand: _selectedBrand!,
      model: _selectedModel!,
      plate: _plateController.text,
      year: int.tryParse(_yearController.text),
      fuelType: _fuelType,
      generation: _generationController.text,
      engine: _engineController.text,
      engineCode: _engineCodeController.text,
    );

    Navigator.of(context).pop();
  }

  Future<void> _pickBrand() async {
    final result = await _openPicker(
      context: context,
      title: tx('Marka Seç'),
      items: vehicleBrands.keys.toList()..sort(),
      showBrandLogos: true,
    );
    if (result != null && result != _selectedBrand) {
      setState(() {
        _selectedBrand = result;
        _selectedModel = null; // marka değişince model sıfırlanır
      });
    }
  }

  Future<void> _pickModel() async {
    if (_selectedBrand == null) return;
    final models = List<String>.from(vehicleBrands[_selectedBrand] ?? []);
    final result = await _openPicker(
      context: context,
      title: tx('{0} — Model Seç', [_selectedBrand]),
      items: models,
    );
    if (result != null) {
      setState(() => _selectedModel = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final wasAutoDetected = context.watch<ObdProvider>().detectedBrand ==
        _selectedBrand &&
        _selectedBrand != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151011),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Text(
                tx('Araç Ekle'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (wasAutoDetected) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    Text(
                      tx('Marka VIN\'den otomatik tahmin edildi'),
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              _PickerField(
                label: tx('Marka'),
                value: _selectedBrand,
                placeholder: tx('Marka seç'),
                onTap: _pickBrand,
                errorText: _selectedBrand == null ? null : null,
              ),
              const SizedBox(height: 12),
              _PickerField(
                label: 'Model',
                value: _selectedModel,
                placeholder: _selectedBrand == null
                    ? tx('Önce marka seç')
                    : tx('Model seç'),
                onTap: _selectedBrand == null ? null : _pickModel,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _generationController,
                      label: tx('Nesil / Kasa'),
                      hint: 'Golf 7, E90...',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormField(
                      controller: _engineController,
                      label: 'Motor',
                      hint: '1.6 TDI',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FormField(
                controller: _engineCodeController,
                label: tx('Motor Kodu (opsiyonel)'),
                hint: 'CLHA, CXXB, N47...',
              ),
              const SizedBox(height: 12),

              // Yakıt tipi — DTC yorumlamasında (EGR/DPF kodları vb.) kullanılır
              Text(
                tx('Yakıt Tipi'),
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: FuelType.values.map((type) {
                  final isSelected = _fuelType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _fuelType = type),
                      child: Container(
                        margin: EdgeInsets.only(
                          right: type == FuelType.values.first ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          type.label,
                          style: TextStyle(
                            color: isSelected ? colorScheme.primary : Colors.white54,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      controller: _plateController,
                      label: tx('Plaka'),
                      hint: '34 ABC 123',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormField(
                      controller: _yearController,
                      label: tx('Yıl'),
                      hint: '2021',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_selectedBrand != null && _selectedModel != null)
                      ? _save
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    disabledBackgroundColor: colorScheme.primary.withValues(
                      alpha: 0.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text(
                    tx('Kaydet'),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arama kutulu, tam ekrana yakın bir seçim listesi açar ve seçilen
/// değeri döner (iptal edilirse null).
Future<String?> _openPicker({
  required BuildContext context,
  required String title,
  required List<String> items,
  bool showBrandLogos = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SearchablePicker(title: title, items: items, showBrandLogos: showBrandLogos),
  );
}

class _SearchablePicker extends StatefulWidget {
  final String title;
  final List<String> items;
  final bool showBrandLogos;

  const _SearchablePicker({required this.title, required this.items, this.showBrandLogos = false});

  @override
  State<_SearchablePicker> createState() => _SearchablePickerState();
}

class _SearchablePickerState extends State<_SearchablePicker> {
  late List<String> _filtered = widget.items;
  final _searchController = TextEditingController();

  void _onSearch(String query) {
    setState(() {
      _filtered = widget.items
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF151011),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: tx('Ara...'),
                        hintStyle: const TextStyle(color: Colors.white24),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          tx('Sonuç bulunamadı'),
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          return ListTile(
                            leading: widget.showBrandLogos ? SizedBox(width:42,height:42,child:BrandAssets.logoFor(item)==null ? const Icon(Icons.directions_car_rounded,color:Colors.white38) : Padding(padding:const EdgeInsets.all(6),child:Image.asset(BrandAssets.logoFor(item)!,fit:BoxFit.contain))) : null,
                            title: Text(item,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),
                            onTap:()=>Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final String? errorText;

  const _PickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isDisabled ? 0.02 : 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? placeholder,
                    style: TextStyle(
                      color: value != null
                          ? Colors.white
                          : Colors.white24,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDisabled ? Colors.white12 : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
