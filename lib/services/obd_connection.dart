abstract class ObdConnection {
  Stream<String> get incoming;

  /// Stable transport identifier. ObdProvider uses this to avoid replacing
  /// the RX subscription every time a transport provider rebuilds.
  String get transportId;

  Future<void> send(String command);

  Future<void> connect();
  Future<void> disconnect();

  bool get isConnected;
  bool get isReconnecting;
}
