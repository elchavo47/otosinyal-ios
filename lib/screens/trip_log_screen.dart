import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:otosinyal_obd2/core/app_colors.dart';
import 'package:otosinyal_obd2/models/trip_log.dart';
import 'package:otosinyal_obd2/providers/garage_provider.dart';
import 'package:otosinyal_obd2/providers/trip_log_provider.dart';
import 'package:otosinyal_obd2/providers/units_provider.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class TripLogScreen extends StatelessWidget {
  const TripLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripLogProvider>().trips;
    final garage = context.watch<GarageProvider>();
    final units = context.watch<UnitsProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          tx('Sürüş Geçmişi'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (trips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
              tooltip: tx('Geçmişi Temizle'),
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: SafeArea(
        child: trips.isEmpty
            ? const _EmptyTripState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  final vehicleName = _vehicleNameFor(garage, trip.vehicleId);
                  return _TripTile(trip: trip, vehicleName: vehicleName, units: units);
                },
              ),
      ),
    );
  }

  String? _vehicleNameFor(GarageProvider garage, String? vehicleId) {
    if (vehicleId == null) return null;
    for (final v in garage.vehicles) {
      if (v.id == vehicleId) return v.displayName;
    }
    return null;
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151011),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tx('Geçmişi temizle?'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          tx('Tüm sürüş kayıtları silinecek. Bu işlem geri alınamaz.'),
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tx('Vazgeç'), style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              dialogContext.read<TripLogProvider>().clearAll();
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tx('Temizle'), style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final TripLog trip;
  final String? vehicleName;
  final UnitsProvider units;

  const _TripTile({required this.trip, required this.vehicleName, required this.units});

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return tx('{0}sn', [s]);
    return tx('{0}dk {1}sn', [m, s]);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_filled_rounded,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  vehicleName ?? tx('Bilinmeyen Araç'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                _formatDate(trip.startTime),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TripStat(
                icon: Icons.timer_outlined,
                label: tx('Süre'),
                value: _formatDuration(trip.durationSeconds),
              ),
              _TripStat(
                icon: Icons.speed_rounded,
                label: tx('Maks. Hız'),
                value: '${units.displaySpeed(trip.maxSpeed)} ${units.speedUnit}',
              ),
              _TripStat(
                icon: Icons.settings_input_component_rounded,
                label: 'Maks. RPM',
                value: '${trip.maxRpm}',
              ),
              if (trip.maxBoostKpa != null)
                _TripStat(
                  icon: Icons.compress_rounded,
                  label: tx('Maks. Basınç'),
                  value: '${trip.maxBoostKpa} kPa',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TripStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 15),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _EmptyTripState extends StatelessWidget {
  const _EmptyTripState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 64,
            color: AppColors.accent.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            tx('Henüz sürüş kaydı yok'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              tx('Araca bağlanıp en az 10 saniye canlı veri okuduğunda sürüş özeti burada görünecek.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
