class ObdDevice {
  final String name;
  final String address;
  final bool isBle;
  /// BLE scan RSSI in dBm. Classic Bluetooth adapters generally do not expose it.
  final int? rssi;

  const ObdDevice({
    required this.name,
    required this.address,
    this.isBle = false,
    this.rssi,
  });

  @override
  String toString() {
    return 'ObdDevice(name: $name, address: $address, isBle: $isBle)';
  }
}
