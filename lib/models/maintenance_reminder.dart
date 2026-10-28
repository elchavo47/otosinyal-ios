import 'package:otosinyal_obd2/l10n/tx.dart';
class MaintenanceReminder {
  final String id;
  final String title;
  final int intervalDays;
  final DateTime? lastCompleted;
  const MaintenanceReminder({required this.id, required this.title, required this.intervalDays, this.lastCompleted});
  bool get isDue => lastCompleted == null || DateTime.now().isAfter(lastCompleted!.add(Duration(days: intervalDays)));
  int get remainingDays => lastCompleted == null ? 0 : lastCompleted!.add(Duration(days: intervalDays)).difference(DateTime.now()).inDays;
  /// Ekranda gösterilecek başlık. Varsayılan bakım kalemleri her zaman etkin
  /// dilde gösterilir (kayıtlı başlık eski dilde kalmış olabilir).
  String get displayTitle => switch (id) {
        'oil' => tx('Motor yağı ve filtre'),
        'brake' => tx('Fren ve lastik kontrolü'),
        'air' => tx('Hava filtresi'),
        'coolant' => tx('Soğutma sıvısı'),
        'timing' => tx('Triger / zincir kontrolü'),
        _ => title,
      };
  /// Bir sonraki bakımın zamanı; hiç yapılmadıysa null.
  DateTime? get nextDue => lastCompleted?.add(Duration(days: intervalDays));
  MaintenanceReminder complete() => MaintenanceReminder(id: id, title: title, intervalDays: intervalDays, lastCompleted: DateTime.now());
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'intervalDays': intervalDays, 'lastCompleted': lastCompleted?.toIso8601String()};
  factory MaintenanceReminder.fromMap(Map<String, dynamic> map) => MaintenanceReminder(id: map['id']?.toString() ?? '', title: map['title']?.toString() ?? tx('Bakım'), intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 365, lastCompleted: DateTime.tryParse(map['lastCompleted']?.toString() ?? ''));
}
