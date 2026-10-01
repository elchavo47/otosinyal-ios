class DiscoveredSignal {
  final String id;
  final String name;
  final String source;
  final String? unit;
  final double? numericValue;
  final String? textValue;
  final DateTime updatedAt;

  const DiscoveredSignal({
    required this.id,
    required this.name,
    required this.source,
    required this.updatedAt,
    this.unit,
    this.numericValue,
    this.textValue,
  });

  String get displayValue {
    if (textValue != null && textValue!.trim().isNotEmpty) return textValue!;
    if (numericValue == null) return '—';
    final v = numericValue!;
    final digits = v.abs() >= 100 ? 0 : v.abs() >= 10 ? 1 : 2;
    return '${v.toStringAsFixed(digits)}${unit == null || unit!.isEmpty ? '' : ' $unit'}';
  }
}
