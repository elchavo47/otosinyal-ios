import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/obd_data.dart';
import '../models/trip_log.dart';
import '../models/dtc_scan_record.dart';
import '../services/demo_data_generator.dart';
import '../services/obd_connection.dart';
import '../services/elm_adapter_profile_service.dart';
import '../services/vin_decoder.dart';
import '../services/oem_diagnostic_catalog.dart';
import '../services/uds_diagnostic.dart';
import '../services/diagnostic_flight_recorder.dart';
import '../models/oem_diagnostics.dart';
import '../models/ecu_module_info.dart';
import '../models/discovered_signal.dart';
import '../models/diagnostic_units.dart';
import '../models/oem_module_profile.dart';
import '../models/coding_backup_record.dart';
import '../models/vag_coding.dart';
import '../models/vag_long_coding.dart';
import '../models/vag_light_configuration.dart';
import '../providers/coding_history_provider.dart';
import '../services/coding_transaction_service.dart';
import '../services/doip_diagnostic_client.dart';
import '../services/oem_module_profile_service.dart';
import '../services/recovered_vag_adaptation_service.dart';
import '../services/wifi_obd_connection.dart';
import '../services/vag_live_did_catalog.dart';
import '../services/vag_long_coding_service.dart';
import '../services/vag_light_configuration_service.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

enum ObdConnectionState { disconnected, initializing, ready, error }

enum DtcStatus { stored, pending, permanent }

extension DtcStatusLabel on DtcStatus {
  String get label {
    switch (this) {
      case DtcStatus.stored:
        return tx('KAYITLI');
      case DtcStatus.pending:
        return tx('BEKLEYEN');
      case DtcStatus.permanent:
        return tx('KALICI');
    }
  }
}


class ObdAdapterInfo {
  final String identity;
  final String description;
  final String protocol;
  final double? voltage;
  const ObdAdapterInfo({this.identity = '-', this.description = '-', this.protocol = '-', this.voltage});
}

class AdapterQualityResult {
  final int successful;
  final int total;
  final int averageMs;
  final String verdict;
  final Map<String, bool> capabilities;
  final int packetLossPercent;
  const AdapterQualityResult({required this.successful, required this.total, required this.averageMs, required this.verdict, this.capabilities = const {}, this.packetLossPercent = 0});
  double get successRate => total == 0 ? 0 : successful / total;
  bool get codingSuitable => capabilities.values.every((value) => value) && packetLossPercent == 0 && averageMs < 1200;
  int get score {
    if(total<=0)return 0;
    final command=(successRate*55).round();
    final capability=capabilities.isEmpty?0:(capabilities.values.where((value)=>value).length/capabilities.length*30).round();
    final latency=averageMs<=150?15:averageMs<=500?12:averageMs<=1200?8:averageMs<=1800?4:0;
    return (command+capability+latency-packetLossPercent.clamp(0,20)).clamp(0,100).toInt();
  }
}

class CodingPreflightCheck {
  final String label;
  final String detail;
  final bool passed;
  final bool required;

  const CodingPreflightCheck({
    required this.label,
    required this.detail,
    required this.passed,
    this.required = true,
  });
}

class CodingPreflightResult {
  final List<CodingPreflightCheck> checks;
  final String? moduleName;
  final String? requestId;
  final String? responseId;
  final DateTime completedAt;

  const CodingPreflightResult({
    required this.checks,
    required this.completedAt,
    this.moduleName,
    this.requestId,
    this.responseId,
  });

  bool get ready => checks.where((item) => item.required).every((item) => item.passed);
}

class CodingRollbackResult {
  final bool success;
  final String message;
  final String? verifiedHex;
  const CodingRollbackResult(this.success, this.message, {this.verifiedHex});
}

class ObdReadinessStatus {
  final int completed;
  final int supported;
  final List<String> incomplete;
  const ObdReadinessStatus({this.completed = 0, this.supported = 0, this.incomplete = const []});
  bool get allReady => supported > 0 && incomplete.isEmpty;
}

class FreezeFrameSnapshot {
  final String? triggerDtc;
  final int? rpm;
  final int? speedKmh;
  final int? coolantC;
  final int? loadPercent;
  final int? mapKpa;
  const FreezeFrameSnapshot({this.triggerDtc, this.rpm, this.speedKmh, this.coolantC, this.loadPercent, this.mapKpa});
  bool get hasData => triggerDtc != null || rpm != null || speedKmh != null || coolantC != null || loadPercent != null || mapKpa != null;
}

class DtcEntry {
  final String code;
  final DtcStatus status;
  const DtcEntry(this.code, this.status);
}

class ObdProvider extends ChangeNotifier {
  final ObdConnection currentConnection;
  late ObdConnection _connection;
  String _transportId = '';
  ElmAdapterProfile? _adapterProfile;
  ElmAdapterProfile? get adapterProfile => _adapterProfile;

  final _errorEventController = StreamController<String>.broadcast();
  Stream<String> get errorEvents => _errorEventController.stream;

  bool get isDeviceConnected => _connection.isConnected;

  final DemoDataGenerator _demoGenerator = DemoDataGenerator();
  StreamSubscription<String>? _rxSubscription;
  Completer<String>? _commandCompleter;
  final StringBuffer _commandBuffer = StringBuffer();
  Future<void> _commandChain = Future.value();
  bool _exclusiveDiagnosticOperation = false;
  bool get isDiagnosticOperationExclusive => _exclusiveDiagnosticOperation;

  int _commandCount = 0;
  int _commandTimeoutCount = 0;
  int _commandErrorCount = 0;
  int _commandLatencyTotalMs = 0;
  int get commandCount => _commandCount;
  int get commandTimeoutCount => _commandTimeoutCount;
  double get averageCommandLatencyMs => _commandCount == 0 ? 0 : _commandLatencyTotalMs / _commandCount;
  int get adapterQualityScore {
    if (_commandCount < 3) return 0;
    final success = ((_commandCount - _commandTimeoutCount - _commandErrorCount) / _commandCount).clamp(0.0, 1.0);
    final latency = averageCommandLatencyMs;
    final latencyScore = latency <= 120 ? 1.0 : latency <= 300 ? .9 : latency <= 650 ? .72 : latency <= 1200 ? .5 : .25;
    return ((success * .72 + latencyScore * .28) * 100).round().clamp(0, 100).toInt();
  }

  ObdConnectionState _state = ObdConnectionState.disconnected;
  ObdConnectionState get state => _state;

  ObdData _data = const ObdData();
  ObdData get data => _data;

  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  bool _isRealMode = false;
  bool get isRealMode => _isRealMode;

  String _initMessage = tx('Başlatılıyor');
  String get initMessage => _initMessage;

  bool _prevIsConnected = false;
  bool _prevIsReconnecting = false;

  final List<DtcEntry> _dtcEntries = [];
  List<DtcEntry> get dtcEntries => List.unmodifiable(_dtcEntries);
  List<String> get troubleCodes =>
      _dtcEntries.map((e) => e.code).toSet().toList(growable: false);

  bool _isReadingCodes = false;
  bool get isReadingCodes => _isReadingCodes;

  bool _isClearingCodes = false;
  bool get isClearingCodes => _isClearingCodes;

  String? _dtcError;
  String? get dtcError => _dtcError;

  DateTime? _lastDtcCheck;
  DateTime? get lastDtcCheck => _lastDtcCheck;

  bool get canQueryDtc => _isDemoMode || _isRealMode;

  String? _detectedVin;
  String? get detectedVin => _detectedVin;

  String? _detectedBrand;
  String? get detectedBrand => _detectedBrand;

  bool? _milOn;
  bool? get milOn => _milOn;

  int? _milDtcCount;
  int? get milDtcCount => _milDtcCount;

  int? _barometricKpa;
  int? get barometricKpa => _barometricKpa;

  // SAE J1979 Mode 01 PID 70 - Boost Pressure Control.
  // These are ECU-reported ABSOLUTE pressures. This is important for tuned
  // vehicles: commanded pressure comes from the currently running ECU
  // calibration rather than a stock lookup table.
  double? _commandedBoostAbsKpa;
  double? get commandedBoostAbsKpa => _commandedBoostAbsKpa;
  double? _actualBoostAbsKpa;
  double? get actualBoostAbsKpa => _actualBoostAbsKpa;
  int? _boostControlStatus;
  int? get boostControlStatus => _boostControlStatus;
  bool _pid70CommandedSupported = false;
  bool _pid70ActualSupported = false;
  bool get supportsCommandedBoost => _isDemoMode || _pid70CommandedSupported;
  bool get supportsActualBoostPid70 => _isDemoMode || _pid70ActualSupported;

  double? get commandedBoostGaugeBar {
    if (_commandedBoostAbsKpa == null || _barometricKpa == null) return null;
    return (_commandedBoostAbsKpa! - _barometricKpa!) / 100.0;
  }

  double? get actualBoostGaugeBarPid70 {
    if (_actualBoostAbsKpa == null || _barometricKpa == null) return null;
    return (_actualBoostAbsKpa! - _barometricKpa!) / 100.0;
  }

  double? get boostTrackingErrorKpa {
    if (_commandedBoostAbsKpa == null || _actualBoostAbsKpa == null) return null;
    return _actualBoostAbsKpa! - _commandedBoostAbsKpa!;
  }

  String get boostControlStatusLabel {
    switch (_boostControlStatus) {
      case 1: return tx('Açık çevrim');
      case 2: return tx('Kapalı çevrim');
      case 3: return tx('ECU boost verisini güvenilmez işaretledi');
      default: return tx('Durum bildirilmedi');
    }
  }

  final Set<int> _supportedMode01Pids = <int>{};
  final Set<int> _runtimeConfirmedPids = <int>{};
  final Set<int> _runtimeRejectedPids = <int>{};
  final Map<int, int> _runtimePidMisses = <int, int>{};
  bool _hasReliableMode01Bitmap = false;
  bool _pidDiscoveryComplete = false;
  String _activeProtocolSelector = '0';
  int _slowPollTick = 0;
  int _advancedPollIndex = 0;
  static const List<int> _advancedPollPids = <int>[0x11, 0x2C, 0x2D, 0x23, 0x42, 0x46, 0x5E, 0x5C, 0x10, 0x04, 0x61, 0x62, 0x63, 0x1F, 0x21, 0x3C];
  Set<int> get supportedMode01Pids => Set.unmodifiable({..._supportedMode01Pids, ..._runtimeConfirmedPids});

  String? _protocolName;
  String? get protocolName => _protocolName;

  double? _throttlePositionPercent;
  double? get throttlePositionPercent => _throttlePositionPercent;
  double? _egrCommandedPercent;
  double? get egrCommandedPercent => _egrCommandedPercent;
  double? _egrErrorPercent;
  double? get egrErrorPercent => _egrErrorPercent;
  int? _fuelRailPressureKpa;
  int? get fuelRailPressureKpa => _fuelRailPressureKpa;
  double? _fuelRateLph;
  double? get fuelRateLph => _fuelRateLph;
  int? _ambientTempC;
  int? get ambientTempC => _ambientTempC;
  double? _controlModuleVoltage;
  double? get controlModuleVoltage => _controlModuleVoltage;
  int? _oilTempC;
  int? get oilTempC => _oilTempC;
  double? _mafGps;
  double? get mafGps => _mafGps;
  int? _engineLoadPercent;
  int? get engineLoadPercent => _engineLoadPercent;
  int? _actualTorquePercent;
  int? get actualTorquePercent => _actualTorquePercent;
  int? _driverDemandTorquePercent;
  int? get driverDemandTorquePercent => _driverDemandTorquePercent;
  int? _referenceTorqueNm;
  int? get referenceTorqueNm => _referenceTorqueNm;
  int? _runtimeSeconds;
  int? get runtimeSeconds => _runtimeSeconds;
  int? _distanceWithMilKm;
  int? get distanceWithMilKm => _distanceWithMilKm;
  double? _catalystTempC;
  double? get catalystTempC => _catalystTempC;
  DateTime? _lastAdvancedRefresh;
  DateTime? get lastAdvancedRefresh => _lastAdvancedRefresh;
  bool _advancedRefreshBusy = false;

  final List<DiscoveredSignal> _discoveredSignals = <DiscoveredSignal>[];
  List<DiscoveredSignal> get discoveredSignals => List.unmodifiable(_discoveredSignals);
  final Map<int, VagLiveDidDefinition> _supportedVagLiveDids = <int, VagLiveDidDefinition>{};
  Map<int, VagLiveDidDefinition> get supportedVagLiveDids => Map.unmodifiable(_supportedVagLiveDids);
  bool _liveSignalDiscoveryBusy = false;
  bool get liveSignalDiscoveryBusy => _liveSignalDiscoveryBusy;
  DateTime? _lastLiveSignalDiscovery;
  DateTime? get lastLiveSignalDiscovery => _lastLiveSignalDiscovery;

  ObdAdapterInfo _adapterInfo = const ObdAdapterInfo();
  ObdAdapterInfo get adapterInfo => _adapterInfo;
  ObdReadinessStatus _readiness = const ObdReadinessStatus();
  ObdReadinessStatus get readiness => _readiness;
  FreezeFrameSnapshot _freezeFrame = const FreezeFrameSnapshot();
  FreezeFrameSnapshot get freezeFrame => _freezeFrame;
  List<String> _mode06Raw = const [];
  List<String> get mode06Raw => List.unmodifiable(_mode06Raw);
  bool _isFullScanning = false;
  bool get isFullScanning => _isFullScanning;
  DateTime? _lastFullScan;
  DateTime? get lastFullScan => _lastFullScan;

  final List<EcuModuleInfo> _ecuModules = <EcuModuleInfo>[];
  List<EcuModuleInfo> get ecuModules => List.unmodifiable(_ecuModules);
  bool _isDiscoveringEcuModules = false;
  bool get isDiscoveringEcuModules => _isDiscoveringEcuModules;
  String? _ecuDiscoveryError;
  String? get ecuDiscoveryError => _ecuDiscoveryError;
  AdapterQualityResult? _adapterQuality;
  AdapterQualityResult? get adapterQuality => _adapterQuality;
  bool _isAdapterTesting = false;
  bool get isAdapterTesting => _isAdapterTesting;
  bool _isCodingPreflight = false;
  bool get isCodingPreflight => _isCodingPreflight;
  CodingPreflightResult? _codingPreflight;
  CodingPreflightResult? get codingPreflight => _codingPreflight;
  bool _isCodingCompatibilityScanning = false;
  bool get isCodingCompatibilityScanning => _isCodingCompatibilityScanning;
  final Map<String, VagModuleIdentity> _codingModules = {};
  Map<String, VagModuleIdentity> get codingModules => Map.unmodifiable(_codingModules);
  final Map<String, CodingFeatureState> _codingFeatureStates = {};
  Map<String, CodingFeatureState> get codingFeatureStates => Map.unmodifiable(_codingFeatureStates);

  OemDiscoveryState _oemDiscovery = const OemDiscoveryState();
  OemDiscoveryState get oemDiscovery => _oemDiscovery;
  bool _isOemScanning = false;
  bool get isOemScanning => _isOemScanning;

  bool _isModuleScanning = false;
  bool get isModuleScanning => _isModuleScanning;
  final Map<DiagnosticUnit, DiagnosticUnitScanResult> _moduleScanResults =
      <DiagnosticUnit, DiagnosticUnitScanResult>{};
  Map<DiagnosticUnit, DiagnosticUnitScanResult> get moduleScanResults =>
      Map.unmodifiable(_moduleScanResults);

  /// Yazma işlemleri yalnız araç dururken yapılır (son okunan OBD hızı).
  bool get _isVehicleMoving => !_isDemoMode && _data.speed > 0;

  bool get isVagVehicle {
    final b = (_detectedBrand ?? '').toLowerCase();
    return b.contains('volkswagen') ||
        b.contains('audi') ||
        b.contains('skoda') ||
        b.contains('škoda') ||
        b.contains('seat') ||
        b.contains('cupra') ||
        b.contains('porsche');
  }

  double? get boostGaugeBar {
    if (_data.boostKpa == null || _barometricKpa == null) return null;
    return (_data.boostKpa! - _barometricKpa!) / 100.0;
  }

  String get batteryAnalysis {
    final v = _controlModuleVoltage ?? _data.voltage;
    if (v <= 0) return tx('Veri bekleniyor');
    if (_data.rpm > 500) {
      if (v < 13.2) return tx('Şarj voltajı düşük');
      if (v > 15.0) return tx('Şarj voltajı yüksek');
      return tx('Şarj sistemi normal');
    }
    if (v < 11.8) return tx('Akü voltajı kritik düşük');
    if (v < 12.2) return tx('Akü zayıf görünüyor');
    return tx('Akü voltajı normal');
  }

  /// Akü/şarj değeri uyarı gerektiriyor mu (metinden bağımsız, dil güvenli).
  bool get batteryAlert {
    final v = _controlModuleVoltage ?? _data.voltage;
    if (v <= 0) return false;
    if (_data.rpm > 500) return v < 13.2 || v > 15.0;
    return v < 11.8;
  }

  /// Akü/şarj değeri normal aralıkta mı.
  bool get batteryNormal {
    final v = _controlModuleVoltage ?? _data.voltage;
    if (v <= 0) return false;
    if (_data.rpm > 500) return v >= 13.2 && v <= 15.0;
    return v >= 12.2;
  }

  List<String> get healthWarnings {
    final w = <String>[];
    if (_data.engineTemp > 110) w.add(tx('Motor soğutma suyu sıcaklığı yüksek: {0} °C', [_data.engineTemp]));
    final v = _controlModuleVoltage ?? _data.voltage;
    if (v > 0 && _data.rpm > 500 && v < 13.2) w.add(tx('Alternatör/şarj voltajı düşük: {0} V', [v.toStringAsFixed(1)]));
    if (v > 15.0) w.add(tx('Şarj voltajı normal aralığın üzerinde: {0} V', [v.toStringAsFixed(1)]));
    if (_egrErrorPercent != null && _egrErrorPercent!.abs() > 35) w.add(tx('EGR gerçek/komut sapması yüksek: {0}%', [_egrErrorPercent!.toStringAsFixed(0)]));
    if (boostGaugeBar != null && boostGaugeBar! > 2.0) w.add(tx('Emme manifoldu basıncı yüksek görünüyor: {0} bar', [boostGaugeBar!.toStringAsFixed(2)]));
    if (_milOn == true) w.add(tx('Check Engine/MIL aktif'));
    if (_dtcEntries.any((e) => e.status == DtcStatus.stored)) w.add(tx('ECU hafızasında kayıtlı arıza kodu var'));
    return w;
  }

  int get vehicleHealthScore {
    if (_isDemoMode) return 92;
    if (!canQueryDtc) return 0;
    var score = 100;
    if (_milOn == true) score -= 25;
    score -= _dtcEntries.where((e) => e.status == DtcStatus.stored).length * 8;
    score -= _dtcEntries.where((e) => e.status == DtcStatus.pending).length * 4;
    score -= _dtcEntries.where((e) => e.status == DtcStatus.permanent).length * 5;
    if (_data.engineTemp > 110) score -= 15;
    final voltage = _controlModuleVoltage ?? _data.voltage;
    if (voltage > 0 && (voltage < 11.8 || voltage > 15.0)) score -= 15;
    if (_egrErrorPercent != null && _egrErrorPercent!.abs() > 35) score -= 8;
    return (score.clamp(0, 100) as num).toInt();
  }

  String get vehicleHealthLabel {
    final score = vehicleHealthScore;
    if (score == 0) return tx('Veri bekleniyor');
    if (score >= 85) return tx('Çok iyi');
    if (score >= 65) return tx('Dikkat gerekli');
    return tx('Servis kontrolü gerekli');
  }

  DateTime? _sessionStart;
  int _sessionMaxSpeed = 0;
  int _sessionMaxRpm = 0;
  int _sessionMaxBoost = 0;

  void Function(TripLog trip)? onTripEnd;
  void Function(DtcScanRecord scan)? onDtcScan;
  String? Function()? getActiveVehicleId;
  bool Function()? hasActiveVehicle;
  Future<void> Function(String vin, String? brand)? onVehicleDetected;

  set state(ObdConnectionState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  ObdProvider(this.currentConnection) {
    _connection = currentConnection;
    _transportId = currentConnection.transportId;
    unawaited(_loadAdapterProfile());
    _listen();
  }

  void updateConnection(ObdConnection newConnection) {
    if (_transportId == newConnection.transportId) {
      _connection = newConnection;
      final currentIsConnected = _connection.isConnected;
      final currentIsReconnecting = _connection.isReconnecting;
      final wasDisconnectedOrReconnecting =
          !_prevIsConnected || _prevIsReconnecting;

      if (_isRealMode &&
          wasDisconnectedOrReconnecting &&
          currentIsConnected &&
          !currentIsReconnecting) {
        unawaited(_recoverEcuConnection());
      }
      if (_isRealMode && !currentIsConnected && !currentIsReconnecting) {
        stopRealData();
      }

      _prevIsConnected = currentIsConnected;
      _prevIsReconnecting = currentIsReconnecting;
      notifyListeners();
      return;
    }

    if (_isRealMode) stopRealData();
    _connection = newConnection;
    _transportId = newConnection.transportId;
    unawaited(_loadAdapterProfile());
    _listen();

    final currentIsConnected = _connection.isConnected;
    final currentIsReconnecting = _connection.isReconnecting;
    final wasDisconnectedOrReconnecting =
        !_prevIsConnected || _prevIsReconnecting;

    if (_isRealMode &&
        wasDisconnectedOrReconnecting &&
        currentIsConnected &&
        !currentIsReconnecting) {
      unawaited(_recoverEcuConnection());
    }

    if (_isRealMode && !currentIsConnected && !currentIsReconnecting) {
      stopRealData();
    }

    _prevIsConnected = currentIsConnected;
    _prevIsReconnecting = currentIsReconnecting;
    notifyListeners();
  }

  Future<void> _loadAdapterProfile() async {
    final id = _transportId;
    try {
      final profile = await ElmAdapterProfileService.load(id);
      if (id == _transportId) {
        _adapterProfile = profile;
        notifyListeners();
      }
    } catch (error) {
      developer.log('Adaptör profili okunamadı: $error', name: 'ObdLogic');
    }
  }

  void _listen() {
    _rxSubscription?.cancel();
    _rxSubscription = _connection.incoming.listen(_handleIncomingData);
  }

  void _handleIncomingData(String rawData) {
    if (_isDemoMode) return;
    developer.log('RX RAW: ${rawData.replaceAll('\r', '<CR>').replaceAll('\n', '<LF>')}', name: 'ObdRaw');
    DiagnosticFlightRecorder.instance.event('RX_CHUNK', raw: rawData);
    _commandBuffer.write(rawData);
    if (rawData.contains('>') && _commandCompleter?.isCompleted == false) {
      _commandCompleter?.complete(_commandBuffer.toString());
    }
  }

  Future<String> _sendAndWait(
    String command, {
    Duration timeout = const Duration(milliseconds: 4500),
  }) {
    final completer = Completer<String>();
    _commandChain = _commandChain.then((_) async {
      try {
        final result = await _sendAndWaitRaw(command, timeout: timeout);
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<String> _sendAndWaitRaw(
    String command, {
    Duration timeout = const Duration(milliseconds: 4500),
  }) async {
    _commandBuffer.clear();
    _commandCompleter = Completer<String>();
    final sw = Stopwatch()..start();
    DiagnosticFlightRecorder.instance.event('TX', command: command.trim(), data: {'timeout_ms': timeout.inMilliseconds});
    try {
      await _connection.send(command.trim());
      final response = await _commandCompleter!.future.timeout(timeout);
      sw.stop();
      _commandCount++;
      _commandLatencyTotalMs += sw.elapsedMilliseconds;
      DiagnosticFlightRecorder.instance.event('RX_COMPLETE', command: command.trim(), raw: response, elapsedMs: sw.elapsedMilliseconds);
      return response;
    } on TimeoutException {
      sw.stop();
      _commandCount++;
      _commandTimeoutCount++;
      _commandLatencyTotalMs += sw.elapsedMilliseconds;
      final partial = _commandBuffer.toString();
      developer.log('Komut zaman aşımı: $command', name: 'ObdLogic');
      DiagnosticFlightRecorder.instance.event('TIMEOUT', command: command.trim(), raw: partial, elapsedMs: sw.elapsedMilliseconds);
      return partial;
    } catch (e) {
      sw.stop();
      _commandCount++;
      _commandErrorCount++;
      _commandLatencyTotalMs += sw.elapsedMilliseconds;
      DiagnosticFlightRecorder.instance.event('COMMAND_ERROR', command: command.trim(), elapsedMs: sw.elapsedMilliseconds, data: {'error': e.toString()});
      rethrow;
    }
  }

  bool _shouldRetryDiagnosticResponse(String raw) {
    final clean = raw
        .replaceAll('>', '')
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    return clean.isEmpty ||
        clean == '?' ||
        clean.contains('STOPPED') ||
        clean.contains('BUFFERFULL') ||
        clean.contains('RXERROR') ||
        clean.contains('DATAERROR');
  }

  /// Direct diagnostic requests can collide with an ELM adapter that is just
  /// leaving a polling/search state. OBD-Droid retries STOPPED/?/empty answers;
  /// doing the same here removes a large class of false "unsupported" results.
  Future<String> _sendDiagnosticWithRetry(
    String command, {
    Duration timeout = const Duration(milliseconds: 4500),
    int retries = 2,
  }) async {
    String last = '';
    for (var attempt = 0; attempt <= retries; attempt++) {
      last = await _sendAndWait(command, timeout: timeout);
      if (!_shouldRetryDiagnosticResponse(last)) return last;
      if (attempt < retries) {
        await Future<void>.delayed(Duration(milliseconds: 350 + (attempt * 250)));
      }
    }
    return last;
  }

  Future<void> _acquireExclusiveDiagnosticOperation() async {
    while (_exclusiveDiagnosticOperation && _isRealMode) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    _exclusiveDiagnosticOperation = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  void _releaseExclusiveDiagnosticOperation() {
    _exclusiveDiagnosticOperation = false;
    notifyListeners();
  }

  String _normalize(String raw, {String? echoCommand}) {
    var value = raw
        .replaceAll('>', '\n')
        .replaceAll('\r', '\n')
        .toUpperCase();

    final lines = value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) => !e.startsWith('SEARCHING'))
        .where((e) => e != 'STOPPED')
        .where((e) => e != 'BUS INIT: OK')
        .toList();

    if (echoCommand != null) {
      final echo = echoCommand.replaceAll(' ', '').toUpperCase();
      lines.removeWhere((line) => line.replaceAll(' ', '') == echo);
    }
    return lines.join('\n');
  }

  bool _isNoData(String raw) {
    final upper = raw.toUpperCase();
    return upper.trim().isEmpty ||
        upper.contains('NO DATA') ||
        upper.contains('UNABLE TO CONNECT') ||
        upper.contains('BUS ERROR') ||
        upper.contains('CAN ERROR') ||
        upper.contains('ERROR');
  }

  List<int> _hexBytes(String line) => UdsDiagnostic.hexBytes(line);

  List<List<int>> _responsePayloads(String raw, int responseService) {
    final normalized = _normalize(raw);
    final payloads = <List<int>>[];

    for (final line in normalized.split('\n')) {
      final bytes = _hexBytes(line);
      final serviceIndex = bytes.indexOf(responseService);
      if (serviceIndex >= 0 && serviceIndex < bytes.length - 1) {
        payloads.add(bytes.sublist(serviceIndex + 1));
      }
    }

    // Bazı adaptörler tüm cevabı tek satır/ayraçsız döndürebilir.
    if (payloads.isEmpty) {
      final compact = normalized.replaceAll(RegExp(r'[^0-9A-F]'), '');
      final marker = responseService.toRadixString(16).padLeft(2, '0').toUpperCase();
      final idx = compact.indexOf(marker);
      if (idx >= 0 && compact.length >= idx + 4) {
        final tail = compact.substring(idx + 2);
        final bytes = <int>[];
        for (var i = 0; i + 2 <= tail.length; i += 2) {
          bytes.add(int.parse(tail.substring(i, i + 2), radix: 16));
        }
        if (bytes.isNotEmpty) payloads.add(bytes);
      }
    }

    return payloads;
  }

  ObdData _parsePidResponse(String raw, ObdData current) {
    if (_isNoData(raw)) return current;
    final payloads = _responsePayloads(raw, 0x41);

    for (final p in payloads) {
      if (p.isEmpty) continue;
      final pid = p[0];
      _markPidConfirmed(pid);
      try {
        switch (pid) {
          case 0x0D:
            if (p.length >= 2) return current.copyWith(speed: p[1]);
            break;
          case 0x0C:
            if (p.length >= 3) {
              return current.copyWith(rpm: ((p[1] * 256) + p[2]) ~/ 4);
            }
            break;
          case 0x05:
            if (p.length >= 2) return current.copyWith(engineTemp: p[1] - 40);
            break;
          case 0x0B:
            if (p.length >= 2) return current.copyWith(boostKpa: p[1]);
            break;
        }
      } catch (_) {}
    }

    final normalized = _normalize(raw);
    final voltMatch = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*V').firstMatch(normalized);
    if (voltMatch != null) {
      final volts = double.tryParse(voltMatch.group(1)!);
      if (volts != null) return current.copyWith(voltage: volts);
    }
    return current;
  }

  bool _supportsPid(int pid) =>
      _runtimeConfirmedPids.contains(pid) ||
      !_hasReliableMode01Bitmap ||
      _supportedMode01Pids.contains(pid);

  bool _shouldProbePid(int pid) {
    if (_runtimeConfirmedPids.contains(pid)) return true;
    // OBDium'daki destek-bitmap yaklaşımı gibi: gerçek 0100/0120/... bitmap'i
    // başarıyla geldiyse ECU'nun cevabına güven. Aksi halde her unsupported PID'i
    // 3 kez timeout'a sürüklemek canlı akışı saniyelerce kilitliyordu.
    if (_hasReliableMode01Bitmap) return _supportedMode01Pids.contains(pid);
    return (_runtimePidMisses[pid] ?? 0) < 3;
  }

  void _markPidConfirmed(int pid) {
    if (pid <= 0 || pid > 0xFF || pid % 0x20 == 0) return;
    _runtimeConfirmedPids.add(pid);
    _runtimeRejectedPids.remove(pid);
    _runtimePidMisses.remove(pid);
  }

  Future<List<int>?> _queryPidPayload(
    int pid, {
    Duration timeout = const Duration(milliseconds: 1200),
    bool forceProbe = false,
  }) async {
    if (_isDemoMode) return null;
    if (!forceProbe && !_shouldProbePid(pid)) return null;
    final cmd = '01${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final raw = await _sendDiagnosticWithRetry(
      cmd,
      timeout: timeout,
      retries: forceProbe ? 1 : 0,
    );
    for (final payload in _responsePayloads(raw, 0x41)) {
      if (payload.isNotEmpty && payload.first == pid) {
        _markPidConfirmed(pid);
        return payload;
      }
    }

    // Tek bir kaçan BLE paketi veya ECU'nun o an meşgul olması PID'yi bütün
    // oturum boyunca "desteklenmiyor" yapmamalı. iOS BLE kaynaklarındaki
    // retry/tek-komut yaklaşımıyla uyumlu olarak ancak 3 ayrı başarısız okumadan
    // sonra runtime reddi uygula. Bitmap'te destekli görünen PID asla bu nedenle
    // kalıcı olarak gizlenmez.
    if (!_supportedMode01Pids.contains(pid)) {
      final misses = (_runtimePidMisses[pid] ?? 0) + 1;
      _runtimePidMisses[pid] = misses;
      if (misses >= 3) _runtimeRejectedPids.add(pid);
    }
    return null;
  }

  Future<double?> _readPercentPid(int pid, {bool forceProbe = false}) async {
    final p = await _queryPidPayload(pid, forceProbe: forceProbe);
    if (p != null && p.length >= 2) return p[1] * 100.0 / 255.0;
    return null;
  }

  Future<void> _readAdvancedPidOnce(int pid, {bool forceProbe = false}) async {
    final p = await _queryPidPayload(pid, forceProbe: forceProbe);
    if (p == null) return;
    try {
      switch (pid) {
        case 0x11:
          if (p.length >= 2) _throttlePositionPercent = p[1] * 100.0 / 255.0;
          break;
        case 0x2C:
          if (p.length >= 2) _egrCommandedPercent = p[1] * 100.0 / 255.0;
          break;
        case 0x2D:
          if (p.length >= 2) _egrErrorPercent = (p[1] - 128) * 100.0 / 128.0;
          break;
        case 0x23:
          if (p.length >= 3) _fuelRailPressureKpa = ((p[1] << 8) | p[2]) * 10;
          break;
        case 0x42:
          if (p.length >= 3) _controlModuleVoltage = ((p[1] << 8) | p[2]) / 1000.0;
          break;
        case 0x46:
          if (p.length >= 2) _ambientTempC = p[1] - 40;
          break;
        case 0x5E:
          if (p.length >= 3) _fuelRateLph = ((p[1] << 8) | p[2]) / 20.0;
          break;
        case 0x5C:
          if (p.length >= 2) _oilTempC = p[1] - 40;
          break;
        case 0x10:
          if (p.length >= 3) _mafGps = ((p[1] << 8) | p[2]) / 100.0;
          break;
        case 0x04:
          if (p.length >= 2) _engineLoadPercent = (p[1] * 100 / 255).round();
          break;
        case 0x61:
          if (p.length >= 2) _driverDemandTorquePercent = p[1] - 125;
          break;
        case 0x62:
          if (p.length >= 2) _actualTorquePercent = p[1] - 125;
          break;
        case 0x63:
          if (p.length >= 3) _referenceTorqueNm = (p[1] << 8) | p[2];
          break;
        case 0x1F:
          if (p.length >= 3) _runtimeSeconds = (p[1] << 8) | p[2];
          break;
        case 0x21:
          if (p.length >= 3) _distanceWithMilKm = (p[1] << 8) | p[2];
          break;
        case 0x3C:
          if (p.length >= 3) _catalystTempC = (((p[1] << 8) | p[2]) / 10.0) - 40.0;
          break;
      }
    } catch (_) {}
  }

  Future<void> refreshAdvancedDiagnostics() async {
    if (!canQueryDtc) return;
    if (_isDemoMode) {
      _throttlePositionPercent = 23;
      _egrCommandedPercent = 38;
      _egrErrorPercent = 2.4;
      _fuelRailPressureKpa = 52000;
      _fuelRateLph = 1.1;
      _ambientTempC = 24;
      _controlModuleVoltage = 13.9;
      _oilTempC = 92;
      _mafGps = 8.4;
      _engineLoadPercent = 28;
      _actualTorquePercent = 12;
      _driverDemandTorquePercent = 14;
      _referenceTorqueNm = 250;
      _runtimeSeconds = 840;
      _distanceWithMilKm = 0;
      _catalystTempC = 365.0;
      _barometricKpa = 101;
      _pid70CommandedSupported = true;
      _pid70ActualSupported = true;
      _commandedBoostAbsKpa = 235.0;
      _actualBoostAbsKpa = 231.0;
      _boostControlStatus = 2;
      _lastAdvancedRefresh = DateTime.now();
      notifyListeners();
      return;
    }

    // Manual/full refresh: probe every useful generic PID once. This deliberately
    // does not trust the support bitmap blindly; clone ELMs sometimes report it
    // incompletely even though the ECU answers the PID.
    for (final pid in _advancedPollPids) {
      if (_exclusiveDiagnosticOperation && !_isFullScanning) break;
      await _readAdvancedPidOnce(pid, forceProbe: true);
    }
    await _readBoostPressureControl(forceProbe: true);
    _lastAdvancedRefresh = DateTime.now();
    notifyListeners();
  }

  Future<void> _readBoostPressureControl({bool forceProbe = false}) async {
    _commandedBoostAbsKpa = null;
    _actualBoostAbsKpa = null;
    _boostControlStatus = null;
    _pid70CommandedSupported = false;
    _pid70ActualSupported = false;

    if (_isDemoMode) {
      // Clearly demo-only values; never used for a real ECU session.
      _pid70CommandedSupported = true;
      _pid70ActualSupported = true;
      _commandedBoostAbsKpa = 235.0;
      _actualBoostAbsKpa = 231.0;
      _boostControlStatus = 2;
      return;
    }
    final payload = await _queryPidPayload(0x70, forceProbe: forceProbe);
    if (payload == null) return;
    for (final p in [payload]) {
      // payload = [70, A, B, C, D, E, F, G, H, I, J]
      if (p.length < 11 || p[0] != 0x70) continue;
      final support = p[1];
      _pid70CommandedSupported = (support & 0x01) != 0;
      _pid70ActualSupported = (support & 0x02) != 0;
      if (_pid70CommandedSupported) {
        _commandedBoostAbsKpa = ((p[2] << 8) | p[3]) / 32.0;
      }
      if (_pid70ActualSupported) {
        _actualBoostAbsKpa = ((p[4] << 8) | p[5]) / 32.0;
      }
      _boostControlStatus = p[10] & 0x03;
      return;
    }
  }

  bool get supportsBoostPressureControl => _isDemoMode || _supportsPid(0x70);

  bool get supportsEgrData => _isDemoMode || _supportsPid(0x2C) || _supportsPid(0x2D);
  bool get supportsFuelRailPressure => _isDemoMode || _supportsPid(0x23);
  bool get supportsFuelRate => _isDemoMode || _supportsPid(0x5E);
  bool get supportsEcuVoltage => _isDemoMode || _supportsPid(0x42);
  bool get supportsGenericDpfData => _isDemoMode || _supportedMode01Pids.any((p) => p >= 0x7A && p <= 0x7F);
  bool get supportsOilTemperature => _isDemoMode || _supportsPid(0x5C);
  bool get supportsTorqueData => _isDemoMode || _supportsPid(0x61) || _supportsPid(0x62) || _supportsPid(0x63);
  bool get supportsMaf => _isDemoMode || _supportsPid(0x10);
  bool get supportsCatalystTemperature => _isDemoMode || _supportsPid(0x3C);
  int get supportedPidCount => supportedMode01Pids.where((pid) => pid % 0x20 != 0).length;

  List<DiscoveredSignal> _genericLiveSignals() {
    final now = DateTime.now();
    final pids = supportedMode01Pids;
    final out = <DiscoveredSignal>[];
    void add(int pid, String name, double? value, String? unit, {String? id}) {
      if (!pids.contains(pid) || value == null || !value.isFinite) return;
      out.add(DiscoveredSignal(id: id ?? '01${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}', name: name, source: 'SAE Mode 01 PID', unit: unit, numericValue: value, updatedAt: now));
    }
    add(0x0C, tx('Motor devri'), _data.rpm.toDouble(), 'rpm');
    add(0x0D, tx('Araç hızı'), _data.speed.toDouble(), 'km/h');
    add(0x05, tx('Soğutma suyu sıcaklığı'), _data.engineTemp.toDouble(), '°C');
    add(0x0B, tx('Manifold mutlak basıncı'), _data.boostKpa?.toDouble(), 'kPa');
    add(0x10, tx('MAF hava akışı'), _mafGps, 'g/s');
    add(0x23, tx('Yakıt rail basıncı'), _fuelRailPressureKpa?.toDouble(), 'kPa');
    add(0x42, tx('Kontrol modülü voltajı'), _controlModuleVoltage, 'V');
    add(0x5C, tx('Motor yağı sıcaklığı'), _oilTempC?.toDouble(), '°C');
    add(0x3C, tx('Katalizör / egzoz sıcaklığı'), _catalystTempC, '°C');
    add(0x2C, tx('EGR komutu'), _egrCommandedPercent, '%');
    add(0x2D, tx('EGR hata oranı'), _egrErrorPercent, '%');
    add(0x5E, tx('Yakıt tüketim debisi'), _fuelRateLph, 'L/h');
    if (pids.contains(0x70)) {
      add(0x70, tx('Turbo hedef mutlak basıncı'), _commandedBoostAbsKpa, 'kPa', id: '0170-CMD');
      add(0x70, tx('Turbo gerçek mutlak basıncı'), _actualBoostAbsKpa, 'kPa', id: '0170-ACT');
    }
    return out;
  }

  String _pidHex(int pid) =>
      pid.toRadixString(16).padLeft(2, '0').toUpperCase();

  String _bytesHex(Iterable<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  DiscoveredSignal? _decodeStandardPidSignal(int pid, List<int> payload) {
    if (payload.isEmpty || payload.first != pid) return null;
    final d = payload.skip(1).toList(growable: false);
    double? value;
    String? unit;
    String? name;
    String? text;

    int u16() => (d[0] << 8) | d[1];
    double percent(int a) => a * 100.0 / 255.0;

    try {
      switch (pid) {
        case 0x04: name = tx('Hesaplanan motor yükü'); value = percent(d[0]); unit = '%'; break;
        case 0x05: name = tx('Soğutma suyu sıcaklığı'); value = d[0] - 40.0; unit = '°C'; break;
        case 0x06: name = tx('Kısa yakıt düzeltmesi Bank 1'); value = (d[0] - 128) * 100.0 / 128.0; unit = '%'; break;
        case 0x07: name = tx('Uzun yakıt düzeltmesi Bank 1'); value = (d[0] - 128) * 100.0 / 128.0; unit = '%'; break;
        case 0x0A: name = tx('Yakıt basıncı'); value = d[0] * 3.0; unit = 'kPa'; break;
        case 0x0B: name = tx('Manifold mutlak basıncı'); value = d[0].toDouble(); unit = 'kPa'; break;
        case 0x0C: name = tx('Motor devri'); value = u16() / 4.0; unit = 'rpm'; break;
        case 0x0D: name = tx('Araç hızı'); value = d[0].toDouble(); unit = 'km/h'; break;
        case 0x0E: name = tx('Ateşleme avansı'); value = d[0] / 2.0 - 64.0; unit = '°'; break;
        case 0x0F: name = tx('Emme havası sıcaklığı'); value = d[0] - 40.0; unit = '°C'; break;
        case 0x10: name = tx('MAF hava akışı'); value = u16() / 100.0; unit = 'g/s'; break;
        case 0x11: name = tx('Gaz kelebeği konumu'); value = percent(d[0]); unit = '%'; break;
        case 0x1F: name = tx('Motor çalışma süresi'); value = u16().toDouble(); unit = tx('sn'); break;
        case 0x21: name = tx('MIL açıkken gidilen mesafe'); value = u16().toDouble(); unit = 'km'; break;
        case 0x23: name = tx('Yakıt rail basıncı'); value = u16() * 10.0; unit = 'kPa'; break;
        case 0x2C: name = tx('EGR komutu'); value = percent(d[0]); unit = '%'; break;
        case 0x2D: name = tx('EGR hata oranı'); value = (d[0] - 128) * 100.0 / 128.0; unit = '%'; break;
        case 0x2F: name = tx('Yakıt seviyesi'); value = percent(d[0]); unit = '%'; break;
        case 0x31: name = tx('DTC silmeden beri mesafe'); value = u16().toDouble(); unit = 'km'; break;
        case 0x33: name = tx('Barometrik basınç'); value = d[0].toDouble(); unit = 'kPa'; break;
        case 0x3C: name = tx('Katalizör sıcaklığı B1S1'); value = u16() / 10.0 - 40.0; unit = '°C'; break;
        case 0x3D: name = tx('Katalizör sıcaklığı B2S1'); value = u16() / 10.0 - 40.0; unit = '°C'; break;
        case 0x3E: name = tx('Katalizör sıcaklığı B1S2'); value = u16() / 10.0 - 40.0; unit = '°C'; break;
        case 0x3F: name = tx('Katalizör sıcaklığı B2S2'); value = u16() / 10.0 - 40.0; unit = '°C'; break;
        case 0x42: name = tx('Kontrol modülü voltajı'); value = u16() / 1000.0; unit = 'V'; break;
        case 0x45: name = tx('Göreli gaz kelebeği'); value = percent(d[0]); unit = '%'; break;
        case 0x46: name = tx('Ortam sıcaklığı'); value = d[0] - 40.0; unit = '°C'; break;
        case 0x49: name = tx('Gaz pedalı D'); value = percent(d[0]); unit = '%'; break;
        case 0x4A: name = tx('Gaz pedalı E'); value = percent(d[0]); unit = '%'; break;
        case 0x4B: name = tx('Gaz pedalı F'); value = percent(d[0]); unit = '%'; break;
        case 0x4C: name = tx('Komut edilen gaz kelebeği'); value = percent(d[0]); unit = '%'; break;
        case 0x51: name = tx('Yakıt tipi'); text = tx('Kod 0x{0}', [_pidHex(d[0])]); break;
        case 0x5C: name = tx('Motor yağı sıcaklığı'); value = d[0] - 40.0; unit = '°C'; break;
        case 0x5E: name = tx('Motor yakıt debisi'); value = u16() / 20.0; unit = 'L/h'; break;
        case 0x61: name = tx('Sürücü tork talebi'); value = d[0] - 125.0; unit = '%'; break;
        case 0x62: name = tx('Gerçek motor torku'); value = d[0] - 125.0; unit = '%'; break;
        case 0x63: name = tx('Motor referans torku'); value = u16().toDouble(); unit = 'Nm'; break;
      }
    } catch (_) {
      return null;
    }

    if (name == null) return null;
    return DiscoveredSignal(
      id: '01${_pidHex(pid)}',
      name: name,
      source: 'SAE Mode 01 PID',
      unit: unit,
      numericValue: value,
      textValue: text,
      updatedAt: DateTime.now(),
    );
  }

  Future<List<DiscoveredSignal>> _probeAllSupportedMode01Signals() async {
    final out = <DiscoveredSignal>[];
    final pids = supportedMode01Pids.toList()..sort();
    for (final pid in pids) {
      if (pid % 0x20 == 0) continue;
      List<int>? payload;
      try {
        payload = await _queryPidPayload(
          pid,
          timeout: const Duration(milliseconds: 1100),
          forceProbe: true,
        );
      } catch (_) {
        continue;
      }
      if (payload == null || payload.isEmpty) continue;
      final decoded = _decodeStandardPidSignal(pid, payload);
      if (decoded != null) {
        out.add(decoded);
      } else {
        out.add(DiscoveredSignal(
          id: '01${_pidHex(pid)}',
          name: 'PID 0x${_pidHex(pid)}',
          source: tx('SAE Mode 01 • Ham veri'),
          unit: null,
          numericValue: null,
          textValue: _bytesHex(payload.skip(1)),
          updatedAt: DateTime.now(),
        ));
      }
    }
    return out;
  }

  Future<void> discoverLiveSignals() async {
    if (!canQueryDtc || _liveSignalDiscoveryBusy) return;
    _liveSignalDiscoveryBusy = true;
    notifyListeners();
    try {
      if (_isDemoMode) {
        _supportedMode01Pids.addAll(<int>{0x0C,0x0D,0x05,0x0B,0x10,0x23,0x42,0x5C,0x3C,0x70});
        await refreshAdvancedDiagnostics();
        _supportedVagLiveDids
          ..clear()
          ..addEntries(VagLiveDidCatalog.candidates.take(10).map((e) => MapEntry(e.did, e)));
        _discoveredSignals
          ..clear()
          ..addAll(_genericLiveSignals());
        for (final d in _supportedVagLiveDids.values) {
          final demo = switch (d.did) {
            0x1050 => 235.0, 0x4E06 => 1310.0, 0x4E0D => 520.0, 0x1054 => 0.0,
            0x1055 => 420.0, 0x1056 => 360.0, 0x1057 => 1.8, 0x105D => 32.0,
            0x105E => 29.0, 0x4E16 => 8.6, _ => 0.0,
          };
          _discoveredSignals.add(DiscoveredSignal(id: '22${d.hex}', name: d.name, source: 'VAG UDS DID', unit: d.unit, numericValue: demo, textValue: d.unit == 'bool' ? (demo > 0 ? tx('Aktif') : tx('Pasif')) : null, updatedAt: DateTime.now()));
        }
        _lastLiveSignalDiscovery = DateTime.now();
        return;
      }

      await refreshAdvancedDiagnostics();

      // Kritik PID'leri bozuk clone bitmap'lerine karşı ayrıca doğrula.
      for (final pid in <int>[0x0C,0x0D,0x05,0x0B,0x10,0x23,0x42,0x5C,0x3C,0x2C,0x2D,0x5E,0x70]) {
        try {
          await _queryPidPayload(
            pid,
            timeout: const Duration(milliseconds: 1000),
            forceProbe: true,
          );
        } catch (_) {}
      }

      // Bitmap + runtime doğrulamasından geçen bütün Mode 01 PID'lerini tara.
      final genericSignals = await _probeAllSupportedMode01Signals();

      _supportedVagLiveDids.clear();
      final vagSignals = <DiscoveredSignal>[];
      if (isVagVehicle) {
        await _acquireExclusiveDiagnosticOperation();
        try {
          await _sendAndWait('ATH1', timeout: const Duration(seconds: 2));
          await _sendAndWait('ATCAF1', timeout: const Duration(seconds: 2));
          await _sendAndWait('ATSH7E0', timeout: const Duration(seconds: 2));
          try { await _sendAndWait('ATCRA7E8', timeout: const Duration(seconds: 2)); } catch (_) {}
          for (final d in VagLiveDidCatalog.candidates) {
            String raw;
            try {
              raw = await _sendAndWait('22${d.hex}', timeout: const Duration(milliseconds: 1350));
            } catch (_) { continue; }
            final payload = UdsDiagnostic.readDidPayload(raw, d.did);
            if (payload == null || payload.isEmpty) continue;
            final value = d.decodeNumber(payload);
            if (value == null || !value.isFinite) continue;
            _supportedVagLiveDids[d.did] = d;
            vagSignals.add(DiscoveredSignal(id: '22${d.hex}', name: d.name, source: 'VAG UDS DID', unit: d.unit, numericValue: value, textValue: d.unit == 'bool' ? (value > 0 ? tx('Aktif') : tx('Pasif')) : null, updatedAt: DateTime.now()));
          }
        } finally {
          try { await _sendAndWait('ATCRA', timeout: const Duration(seconds: 2)); } catch (_) {}
          try { await _sendAndWait('ATSH7DF', timeout: const Duration(seconds: 2)); } catch (_) {}
          try { await _sendAndWait('ATH0', timeout: const Duration(seconds: 2)); } catch (_) {}
          _releaseExclusiveDiagnosticOperation();
        }
      }
      _discoveredSignals
        ..clear()
        ..addAll(genericSignals)
        ..addAll(vagSignals);
      _lastLiveSignalDiscovery = DateTime.now();
    } finally {
      _liveSignalDiscoveryBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshDiscoveredSignals() async {
    if (!canQueryDtc || _liveSignalDiscoveryBusy) return;
    if (_supportedVagLiveDids.isEmpty) {
      await discoverLiveSignals();
      return;
    }
    _liveSignalDiscoveryBusy = true;
    notifyListeners();
    try {
      await refreshAdvancedDiagnostics();
      final vagSignals = <DiscoveredSignal>[];
      if (!_isDemoMode && isVagVehicle) {
        await _acquireExclusiveDiagnosticOperation();
        try {
          await _sendAndWait('ATH1', timeout: const Duration(seconds: 2));
          await _sendAndWait('ATCAF1', timeout: const Duration(seconds: 2));
          await _sendAndWait('ATSH7E0', timeout: const Duration(seconds: 2));
          try { await _sendAndWait('ATCRA7E8', timeout: const Duration(seconds: 2)); } catch (_) {}
          for (final d in _supportedVagLiveDids.values) {
            try {
              final raw = await _sendAndWait('22${d.hex}', timeout: const Duration(milliseconds: 1200));
              final payload = UdsDiagnostic.readDidPayload(raw, d.did);
              final value = payload == null ? null : d.decodeNumber(payload);
              if (value == null || !value.isFinite) continue;
              vagSignals.add(DiscoveredSignal(id: '22${d.hex}', name: d.name, source: 'VAG UDS DID', unit: d.unit, numericValue: value, textValue: d.unit == 'bool' ? (value > 0 ? tx('Aktif') : tx('Pasif')) : null, updatedAt: DateTime.now()));
            } catch (_) {}
          }
        } finally {
          try { await _sendAndWait('ATCRA', timeout: const Duration(seconds: 2)); } catch (_) {}
          try { await _sendAndWait('ATSH7DF', timeout: const Duration(seconds: 2)); } catch (_) {}
          try { await _sendAndWait('ATH0', timeout: const Duration(seconds: 2)); } catch (_) {}
          _releaseExclusiveDiagnosticOperation();
        }
      }
      _discoveredSignals
        ..clear()
        ..addAll(_genericLiveSignals())
        ..addAll(vagSignals);
      _lastLiveSignalDiscovery = DateTime.now();
    } finally {
      _liveSignalDiscoveryBusy = false;
      notifyListeners();
    }
  }

  Future<void> _readAdapterInfo() async {
    if (_isDemoMode) {
      _adapterInfo = ObdAdapterInfo(identity: 'ELM327 Demo', description: tx('OTOSİNYAL simülasyon adaptörü'), protocol: 'ISO 15765-4 CAN', voltage: 13.9);
      return;
    }
    String firstUseful(String raw, String cmd) {
      final n = _normalize(raw, echoCommand: cmd);
      if (n.isEmpty || _isNoData(n)) return '-';
      return n.split('\n').first.trim();
    }
    final ati = firstUseful(await _sendAndWait('ATI'), 'ATI');
    final at1 = firstUseful(await _sendAndWait('AT@1'), 'AT@1');
    final dp = firstUseful(await _sendAndWait('ATDP'), 'ATDP');
    final rv = firstUseful(await _sendAndWait('ATRV'), 'ATRV');
    final vm = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(rv);
    _adapterInfo = ObdAdapterInfo(identity: ati, description: at1, protocol: dp == '-' ? (_protocolName ?? '-') : dp, voltage: vm == null ? null : double.tryParse(vm.group(1)!));
    notifyListeners();
  }

  Future<void> testAdapterQuality() async {
    if (!canQueryDtc || _isAdapterTesting) return;
    _isAdapterTesting = true;
    notifyListeners();
    try {
      if (_isDemoMode) {
        _adapterQuality = AdapterQualityResult(successful: 8, total: 8, averageMs: 84, verdict: tx('Kodlamaya uygun'), capabilities: {tx('Kimlik'):true,'Header':true,'Flow control':true,'ISO-TP':true,tx('Uzun UDS'):true}, packetLossPercent:0);
        return;
      }
      final commands = <String>['ATI', 'ATDP', 'ATH1', 'ATAL', 'ATCAF1', 'ATCFC1', '0100', '0100'];
      var successful = 0;
      var totalMs = 0;
      final capabilities = <String,bool>{tx('Kimlik'):false,'Header':false,'Flow control':false,'ISO-TP':false,tx('Uzun UDS'):false};
      for (final command in commands) {
        final watch = Stopwatch()..start();
        try {
          final response = await _sendAndWait(command, timeout: const Duration(seconds: 5));
          watch.stop();
          totalMs += watch.elapsedMilliseconds;
          final normalized = _normalize(response, echoCommand: command);
          final ok = !_isNoData(normalized) && !normalized.contains('?') && !normalized.contains('ERROR');
          if (ok) successful++;
          if (command == 'ATI') capabilities[tx('Kimlik')] = ok;
          if (command == 'ATH1') capabilities['Header'] = ok;
          if (command == 'ATCFC1') capabilities['Flow control'] = ok;
          if (command == 'ATAL') capabilities['ISO-TP'] = ok;
        } catch (_) {
          watch.stop();
          totalMs += watch.elapsedMilliseconds;
        }
      }
      try {
        await _sendAndWait('ATSH710', timeout: const Duration(seconds: 3));
        await _sendAndWait('ATCRA77A', timeout: const Duration(seconds: 3));
        final longRaw = await _sendAndWait('22F190', timeout: const Duration(seconds: 8));
        final payload = UdsDiagnostic.readDidPayload(longRaw, 0xF190);
        capabilities[tx('Uzun UDS')] = payload != null && payload.length >= 17;
      } catch (_) {
        capabilities[tx('Uzun UDS')] = false;
      } finally {
        try { await _sendAndWait('ATCRA', timeout: const Duration(seconds: 2)); } catch (_) {}
        try { await _sendAndWait('ATSH7DF', timeout: const Duration(seconds: 2)); } catch (_) {}
        try { await _sendAndWait('ATH0', timeout: const Duration(seconds: 2)); } catch (_) {}
      }
      if (_transportId.isNotEmpty) {
        final profile = (_adapterProfile ?? ElmAdapterProfile(transportId: _transportId))
            .copyWith(longMessagesSupported: capabilities['ISO-TP'] == true);
        _adapterProfile = profile;
        unawaited(ElmAdapterProfileService.save(profile));
      }
      final average = totalMs ~/ commands.length;
      final loss = (((commands.length - successful) / commands.length) * 100).round();
      final suitable = capabilities.values.every((value)=>value) && loss == 0 && average < 1200;
      final verdict = suitable ? tx('Kodlamaya uygun') : successful >= 6 && average < 1800 ? tx('Teşhise uygun; kodlama doğrulanmadı') : tx('Adaptör veya bağlantı zayıf');
      _adapterQuality = AdapterQualityResult(successful: successful, total: commands.length, averageMs: average, verdict: verdict, capabilities: capabilities, packetLossPercent: loss);
    } finally {
      _isAdapterTesting = false;
      notifyListeners();
    }
  }

  /// Validates the real transport path required before any VAG coding recipe
  /// can be enabled. This deliberately performs no SecurityAccess or write.
  Future<CodingPreflightResult> runVagCodingPreflight() async {
    if (_isCodingPreflight) {
      return _codingPreflight ?? CodingPreflightResult(
        checks: const [],
        completedAt: DateTime.now(),
      );
    }

    _isCodingPreflight = true;
    _exclusiveDiagnosticOperation = true;
    _codingPreflight = null;
    notifyListeners();

    final checks = <CodingPreflightCheck>[];
    String? moduleName;
    String? requestId;
    String? responseId;

    void add(String label, String detail, bool passed, {bool required = true}) {
      checks.add(CodingPreflightCheck(
        label: label,
        detail: detail,
        passed: passed,
        required: required,
      ));
    }

    try {
      final connected = _isRealMode && _connection.isConnected && !_connection.isReconnecting;
      add(tx('ECU bağlantısı'), connected ? tx('Canlı teşhis oturumu açık') : tx('Önce adaptöre ve ECU’ya bağlan'), connected);

      final vag = isVagVehicle;
      add(tx('Araç ailesi'), vag ? tx('{0} VIN üzerinden tanındı', [_detectedBrand ?? 'VAG']) : tx('Bu doğrulama yalnızca VAG profilleri içindir'), vag);

      final voltage = _controlModuleVoltage ?? _adapterInfo.voltage ?? _data.voltage;
      final voltageOk = voltage >= 12.2 && voltage <= 15.0;
      add(tx('Besleme voltajı'), voltage > 0 ? '${voltage.toStringAsFixed(1)} V' : tx('Voltaj okunamadı'), voltageOk);

      final engineStopped = _data.rpm < 300;
      add(tx('Motor durumu'), engineStopped ? tx('Motor kapalı / devir yok') : tx('Kodlama için motoru kapat, kontağı açık bırak'), engineStopped);

      final vinOk = _detectedVin != null && _detectedVin!.length == 17;
      add(tx('VIN doğrulaması'), vinOk ? _detectedVin! : tx('17 karakterli VIN okunamadı'), vinOk);

      if (connected) {
        final atiRaw = await _sendAndWait('ATI', timeout: const Duration(seconds: 4));
        final identity = _normalize(atiRaw, echoCommand: 'ATI');
        final identityOk = identity.isNotEmpty && !_isNoData(identity) && !identity.contains('?');
        final cloneRisk = identity.toUpperCase().contains('ELM327 V2.1') &&
            !identity.toUpperCase().contains('VGATE');
        add(tx('Adaptör kimliği'), identityOk ? identity.split('\n').first : tx('ATI cevabı alınamadı'), identityOk);
        add(
          tx('Klon riski'),
          cloneRisk ? tx('Genel ELM327 v2.1 kimliği şüpheli; yazma kilitli kalır') : tx('Kimlik tek başına klon işareti vermedi'),
          !cloneRisk,
          required: false,
        );

        var elmCommandsOk = true;
        for (final command in const ['ATAL', 'ATCAF1', 'ATH1']) {
          final raw = await _sendAndWait(command, timeout: const Duration(seconds: 4));
          if (raw.toUpperCase().contains('?') || raw.toUpperCase().contains('ERROR')) {
            elmCommandsOk = false;
          }
        }
        add(tx('ELM uzun mesaj modu'), elmCommandsOk ? tx('ATAL / CAF / header komutları kabul edildi') : tx('Adaptör gerekli ELM komutlarından birini reddetti'), elmCommandsOk);

        final candidates = <({String name, String request, String response})>[
          (name: 'CAN Gateway', request: '710', response: '77A'),
          (name: tx('Merkezi Elektrik / BCM'), request: '70E', response: '778'),
          (name: tx('Gösterge Paneli'), request: '714', response: '77E'),
          (name: 'Motor ECU', request: '7E0', response: '7E8'),
        ];

        String moduleRaw = '';
        for (final candidate in candidates) {
          await _sendAndWait('ATSH${candidate.request}', timeout: const Duration(seconds: 3));
          await _sendAndWait('ATCRA${candidate.response}', timeout: const Duration(seconds: 3));
          moduleRaw = await _sendAndWait('22F190', timeout: const Duration(seconds: 7));
          if (_hasUdsPositive(moduleRaw, 0x62)) {
            moduleName = candidate.name;
            requestId = candidate.request;
            responseId = candidate.response;
            break;
          }
        }

        final moduleOk = moduleName != null;
        add(tx('VAG UDS modülü'), moduleOk ? '$moduleName • $requestId → $responseId' : tx('Gateway/BCM/Panel/Motor UDS cevabı vermedi'), moduleOk);

        final payload = UdsDiagnostic.readDidPayload(moduleRaw, 0xF190);
        final longFrameOk = payload != null && payload.length >= 17;
        add(tx('Çok kareli cevap'), longFrameOk ? tx('{0} bayt F190 verisi çözüldü', [payload.length]) : tx('Gateway F190 uzun cevabı çözülemedi; gerçek ECU işleminde yeniden doğrulanacak'), longFrameOk, required: false);

        var sessionOk = false;
        var testerPresentOk = false;
        if (moduleOk) {
          final sessionRaw = await _sendAndWait('1003', timeout: const Duration(seconds: 6));
          final sessionBytes = UdsDiagnostic.hexBytes(sessionRaw);
          sessionOk = _containsSequence(sessionBytes, const [0x50, 0x03]);
          final testerRaw = await _sendAndWait('3E00', timeout: const Duration(seconds: 4));
          final testerBytes = UdsDiagnostic.hexBytes(testerRaw);
          testerPresentOk = _containsSequence(testerBytes, const [0x7E, 0x00]);
        }
        add(tx('Genişletilmiş oturum'), sessionOk ? tx('UDS 10 03 kabul edildi') : tx('Gateway 10 03 açmadı; seçilen kodlamanın gerçek ECU adresinde yeniden denenecek'), sessionOk, required: false);
        add(tx('Oturum canlı tutma'), testerPresentOk ? tx('UDS 3E 00 doğrulandı') : tx('Tester Present cevabı alınamadı'), testerPresentOk);
      }
    } catch (error) {
      add(tx('Doğrulama akışı'), tx('İletişim hatası: {0}', [error]), false);
    } finally {
      try { await _sendAndWait('1001', timeout: const Duration(seconds: 3)); } catch (_) {}
      try { await _sendAndWait('ATCRA', timeout: const Duration(seconds: 2)); } catch (_) {}
      try { await _sendAndWait('ATSH7DF', timeout: const Duration(seconds: 2)); } catch (_) {}
      try { await _sendAndWait('ATH0', timeout: const Duration(seconds: 2)); } catch (_) {}
      _exclusiveDiagnosticOperation = false;
      _isCodingPreflight = false;
      _codingPreflight = CodingPreflightResult(
        checks: List.unmodifiable(checks),
        moduleName: moduleName,
        requestId: requestId,
        responseId: responseId,
        completedAt: DateTime.now(),
      );
      DiagnosticFlightRecorder.instance.event('CODING_PREFLIGHT', data: {
        'ready': _codingPreflight!.ready,
        'module': moduleName,
        'request_id': requestId,
        'response_id': responseId,
        'checks': checks.map((item) => {'label': item.label, 'passed': item.passed}).toList(),
      });
      notifyListeners();
    }
    return _codingPreflight!;
  }

  bool _containsSequence(List<int> bytes, List<int> sequence) {
    if (sequence.isEmpty || bytes.length < sequence.length) return false;
    for (var i = 0; i <= bytes.length - sequence.length; i++) {
      var matches = true;
      for (var j = 0; j < sequence.length; j++) {
        if (bytes[i + j] != sequence[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }

  /// Reads module identity and the current value of every safely-readable
  /// recipe. This method never sends SecurityAccess (27) or WriteData (2E).
  Future<void> scanCodingCompatibility({
    required List<VagCodingRecipe> recipes,
    required bool sfdPlatform,
  }) async {
    if (_isCodingCompatibilityScanning || !_isRealMode || !_connection.isConnected) return;
    _isCodingCompatibilityScanning = true;
    _exclusiveDiagnosticOperation = true;
    _codingModules.clear();
    _codingFeatureStates
      ..clear()
      ..addEntries(recipes.map((recipe)=>MapEntry(recipe.id,CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.reading,detail:tx('ECU değeri okunuyor')))));
    notifyListeners();
    try {
      final moduleRecipes = <String,VagCodingRecipe>{};
      for (final recipe in recipes) { moduleRecipes.putIfAbsent(recipe.moduleKey, ()=>recipe); }
      for (final entry in moduleRecipes.entries) {
        final recipe = entry.value;
        try {
          await _sendAndWait('ATH1', timeout: const Duration(seconds:3));
          await _sendAndWait('ATAL', timeout: const Duration(seconds:3));
          await _sendAndWait('ATCAF1', timeout: const Duration(seconds:3));
          await _sendAndWait('ATSH${recipe.requestId}', timeout: const Duration(seconds:3));
          await _sendAndWait('ATCRA${recipe.responseId}', timeout: const Duration(seconds:3));
          final vinRaw = await _sendAndWait('22F190', timeout: const Duration(seconds:8));
          final partRaw = await _sendAndWait('22F187', timeout: const Duration(seconds:7));
          final softwareRaw = await _sendAndWait('22F189', timeout: const Duration(seconds:7));
          final asamRaw = await _sendAndWait('22F1A0', timeout: const Duration(seconds:7));
          final asamVersionRaw = await _sendAndWait('22F1A2', timeout: const Duration(seconds:7));
          String? text(String raw,int did) { final p=UdsDiagnostic.readDidPayload(raw,did); if(p==null||p.isEmpty)return null; final t=UdsDiagnostic.ascii(p); return t.isEmpty?p.map((b)=>b.toRadixString(16).padLeft(2,'0').toUpperCase()).join():t; }
          final vin=text(vinRaw,0xF190);
          final part=text(partRaw,0xF187);
          final software=text(softwareRaw,0xF189);
          final asam=text(asamRaw,0xF1A0);
          final asamVersion=text(asamVersionRaw,0xF1A2);
          final responding=vin!=null||part!=null||software!=null||asam!=null;
          _codingModules[entry.key]=VagModuleIdentity(key:entry.key,name:recipe.moduleName,requestId:recipe.requestId,responseId:recipe.responseId,responding:responding,vin:vin,partNumber:part,softwareVersion:software,asamDataset:asam,asamVersion:asamVersion,sfdProtected:sfdPlatform,detail:responding?tx('ECU kimliği okundu'):tx('Modül UDS cevabı vermedi'));
        } catch(error) {
          _codingModules[entry.key]=VagModuleIdentity(key:entry.key,name:recipe.moduleName,requestId:recipe.requestId,responseId:recipe.responseId,responding:false,detail:tx('Okuma hatası: {0}', [error]));
        }
        notifyListeners();
      }

      for (final recipe in recipes) {
        final module=_codingModules[recipe.moduleKey];
        if(module==null||!module.responding) {
          _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.hardwareMissing,detail:tx('{0} araçta bulunamadı veya cevap vermedi', [recipe.moduleName]));
          continue;
        }
        if(recipe.kind==CodingRecipeKind.unsupportedSafety) {
          _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.unverified,detail:tx('Güvenlik kritik modüllerde yazma kalıcı olarak kapalı'));
          continue;
        }
        if(sfdPlatform) {
          _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.sfdProtected,detail:tx('Platform SFD korumalı; yetkili token olmadan yazma kapalı'));
          continue;
        }
        if(recipe.hasIdentityAllowlist && !recipe.matchesIdentity(module)) {
          _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.unverified,detail:tx('ECU kimliği bu tarifin parça/yazılım/ASAM allowlisti ile eşleşmedi'));
          continue;
        }
        if(recipe.readService!=0x22 || (recipe.writeService!=null && recipe.writeService!=0x2E)) {
          _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.unverified,detail:tx('Kurtarılan tarif farklı UDS servis akışı istiyor; bu motor sürümünde yazma kapalı'));
          continue;
        }
        if(recipe.kind!=CodingRecipeKind.longCodingBit||recipe.did==null||recipe.byteIndex==null||recipe.bitIndex==null) {
          _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.unverified,detail:tx('Kanal adı biliniyor; bu ECU/ASAM için sayısal adres doğrulanmadı'));
          continue;
        }
        try {
          await _sendAndWait('ATSH${recipe.requestId}', timeout: const Duration(seconds:3));
          await _sendAndWait('ATCRA${recipe.responseId}', timeout: const Duration(seconds:3));
          final did=int.parse(recipe.did!,radix:16);
          final raw=await _sendAndWait('22${recipe.did}', timeout: const Duration(seconds:8));
          final payload=UdsDiagnostic.readDidPayload(raw,did);
          if(payload==null||payload.length<=recipe.byteIndex!) {
            _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.unverified,detail:tx('Long coding değeri bu ECU’dan okunamadı'));
          } else {
            final enabled=(payload[recipe.byteIndex!]&(1<<recipe.bitIndex!))!=0;
            final hex=payload.map((b)=>b.toRadixString(16).padLeft(2,'0').toUpperCase()).join();
            _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.compatible,enabled:enabled,currentHex:hex,detail:recipe.writeEnabled?tx('Mevcut değer ECU’dan okundu'):tx('Mevcut değer okundu; tarif kimlik allowlist onayı bekliyor'));
          }
        } catch(error) {
          _codingFeatureStates[recipe.id]=CodingFeatureState(recipeId:recipe.id,compatibility:CodingCompatibility.error,detail:tx('Durum okuma hatası: {0}', [error]));
        }
        notifyListeners();
      }
    } finally {
      try { await _sendAndWait('1001', timeout: const Duration(seconds:3)); } catch (_) {}
      try { await _sendAndWait('ATCRA', timeout: const Duration(seconds:2)); } catch (_) {}
      try { await _sendAndWait('ATSH7DF', timeout: const Duration(seconds:2)); } catch (_) {}
      try { await _sendAndWait('ATH0', timeout: const Duration(seconds:2)); } catch (_) {}
      _exclusiveDiagnosticOperation=false;
      _isCodingCompatibilityScanning=false;
      notifyListeners();
    }
  }

  Future<CodingApplyResult> applyCodingRecipe({
    required VagCodingRecipe recipe,
    required bool enable,
    required CodingHistoryProvider history,
  }) async {
    if (_isVehicleMoving) return CodingApplyResult(false, tx('Araç hareket halindeyken ECU\'ya yazılmaz. Aracı durdurup park konumuna alın.'));
    final state=_codingFeatureStates[recipe.id];
    final module=_codingModules[recipe.moduleKey];
    if(recipe.kind!=CodingRecipeKind.longCodingBit||!recipe.writeEnabled) return CodingApplyResult(false,tx('Bu tarif için ECU/ASAM allowlist doğrulaması henüz yok; yazma güvenlik nedeniyle kapalı'));
    if(state?.compatibility!=CodingCompatibility.compatible||state?.currentHex==null||module==null) return CodingApplyResult(false,tx('Mevcut ECU değeri ve modül kimliği doğrulanmadı'));
    if(!recipe.hasIdentityAllowlist || !recipe.matchesIdentity(module)) return CodingApplyResult(false,tx('Bu ECU kimliği tarif allowlisti ile birebir doğrulanmadı; yazma reddedildi'));
    if(recipe.readService!=0x22 || recipe.writeService!=0x2E) return CodingApplyResult(false,tx('Bu tarif farklı UDS servis akışı istiyor; mevcut yazma motoru henüz desteklemiyor'));
    final vin=_detectedVin;
    if(vin==null||vin.length!=17||module.partNumber==null||module.softwareVersion==null) return CodingApplyResult(false,tx('VIN ve ECU parça/yazılım kimliği zorunlu'));
    final bytes=<int>[];
    for(var i=0;i<state!.currentHex!.length;i+=2){bytes.add(int.parse(state.currentHex!.substring(i,i+2),radix:16));}
    if(recipe.byteIndex!>=bytes.length) return CodingApplyResult(false,tx('Tarif byte konumu ECU verisinin dışında'));
    if(enable){bytes[recipe.byteIndex!]|=1<<recipe.bitIndex!;}else{bytes[recipe.byteIndex!]&=~(1<<recipe.bitIndex!);}
    final requested=bytes.map((b)=>(b&0xFF).toRadixString(16).padLeft(2,'0').toUpperCase()).join();
    _exclusiveDiagnosticOperation=true;
    notifyListeners();
    try {
      await _sendAndWait('ATH1'); await _sendAndWait('ATAL'); await _sendAndWait('ATCAF1');
      await _sendAndWait('ATSH${recipe.requestId}'); await _sendAndWait('ATCRA${recipe.responseId}');
      final sessionHex=recipe.diagnosticSession.toRadixString(16).padLeft(2,'0').toUpperCase();
      final session=await _sendAndWait('10$sessionHex',timeout:const Duration(seconds:6));
      if(!_containsSequence(UdsDiagnostic.hexBytes(session),[0x50,recipe.diagnosticSession&0xFF])) return CodingApplyResult(false,tx('İstenen UDS oturumu açılamadı'));
      final result=await CodingTransactionService.execute(
        requestedHex:requested,
        readCurrent:()async{final raw=await _sendAndWait('22${recipe.did}',timeout:const Duration(seconds:8));final p=UdsDiagnostic.readDidPayload(raw,int.parse(recipe.did!,radix:16));return p==null?'':p.map((b)=>b.toRadixString(16).padLeft(2,'0').toUpperCase()).join();},
        writeValue:(value)async{final raw=await _sendAndWait('2E${recipe.did}$value',timeout:const Duration(seconds:10));final n=UdsDiagnostic.parseNegative(raw);if(n!=null)throw StateError(n.description);if(!_containsSequence(UdsDiagnostic.hexBytes(raw),[0x6E,int.parse(recipe.did!.substring(0,2),radix:16),int.parse(recipe.did!.substring(2),radix:16)]))throw StateError(tx('Pozitif yazma cevabı yok'));},
        createBackup:(original)=>CodingBackupRecord(id:'${DateTime.now().microsecondsSinceEpoch}-${recipe.id}',vin:vin,brand:_detectedBrand??'VAG',moduleName:recipe.moduleName,requestId:recipe.requestId,responseId:recipe.responseId,did:recipe.did!,originalHex:original,status:CodingBackupStatus.captured,createdAt:DateTime.now().toUtc(),ecuPartNumber:module.partNumber,ecuSoftwareVersion:module.softwareVersion),
        saveBackup:history.capture,
        updateStatus:history.updateStatus,
      );
      return CodingApplyResult(result.success,result.message,rolledBack:result.rolledBack);
    } catch(error) {
      return CodingApplyResult(false,tx('Kodlama reddedildi: {0}', [error]));
    } finally {
      try{await _sendAndWait('1001');}catch(_){} try{await _sendAndWait('ATCRA');}catch(_){} try{await _sendAndWait('ATSH7DF');}catch(_){} try{await _sendAndWait('ATH0');}catch(_){}
      _exclusiveDiagnosticOperation=false; notifyListeners();
    }
  }

  int? _parseRecoveredAccessCode(String raw) {
    final match = RegExp(r'\d{4,6}').firstMatch(raw.trim());
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  /// Legacy VAG UDS Security Access used by the recovered engine.
  /// The old engine requests seed with 27 03, interprets the 4-byte seed
  /// big-endian, adds the decimal access code and returns the 32-bit result
  /// with 27 04. Overflow intentionally wraps at 32 bits.
  Future<void> _recoveredVagSecurityAccess(int accessCode) async {
    final seedRaw = await _sendAndWait('2703', timeout: const Duration(seconds: 7));
    final negative = UdsDiagnostic.parseNegative(seedRaw);
    if (negative != null) throw StateError(tx('Security seed reddedildi: {0}', [negative.description]));
    final bytes = UdsDiagnostic.hexBytes(seedRaw);
    var pos = -1;
    for (var i = 0; i + 5 < bytes.length; i++) {
      if (bytes[i] == 0x67 && bytes[i + 1] == 0x03) { pos = i; break; }
    }
    if (pos < 0 || pos + 5 >= bytes.length) throw StateError(tx('ECU 27 03 seed döndürmedi'));
    final seed = ((bytes[pos + 2] & 0xFF) << 24) |
        ((bytes[pos + 3] & 0xFF) << 16) |
        ((bytes[pos + 4] & 0xFF) << 8) |
        (bytes[pos + 5] & 0xFF);
    final key = (seed + accessCode) & 0xFFFFFFFF;
    final keyHex = key.toRadixString(16).padLeft(8, '0').toUpperCase();
    final keyRaw = await _sendAndWait('2704$keyHex', timeout: const Duration(seconds: 7));
    final keyNegative = UdsDiagnostic.parseNegative(keyRaw);
    if (keyNegative != null) throw StateError(tx('Security key reddedildi: {0}', [keyNegative.description]));
    if (!_containsSequence(UdsDiagnostic.hexBytes(keyRaw), const [0x67, 0x04])) {
      throw StateError(tx('Security Access pozitif onayı alınamadı'));
    }
  }

  Future<void> _runRecoveredProcedure(
    String procedure, {
    required int? accessCode,
    required Map<String, String> snapshots,
  }) async {
    if (procedure.trim().isEmpty) return;
    for (final tokenRaw in procedure.split(';')) {
      var token = tokenRaw.trim().toUpperCase();
      if (token.isEmpty) continue;
      // Old catalog can prefix a command with a temporary CAN header, e.g. 700:3E80.
      final headerMatch = RegExp(r'^([0-9A-F]{3}):(.+)$').firstMatch(token);
      String? restoreHeader;
      if (headerMatch != null) {
        restoreHeader = null;
        await _sendAndWait('ATSH${headerMatch.group(1)!}', timeout: const Duration(seconds: 3));
        token = headerMatch.group(2)!;
      }
      if (token == '2703' || token == '2704') {
        if (token == '2703') {
          // 2704 immediately following it is consumed by this complete handshake.
          if (accessCode == null) throw StateError(tx('Özel prosedür Security Access kodu istiyor'));
          await _recoveredVagSecurityAccess(accessCode);
        }
        continue;
      }
      final read = RegExp(r'^22([0-9A-F]{4})$').firstMatch(token);
      if (read != null) {
        final did = read.group(1)!;
        final raw = await _sendAndWait(token, timeout: const Duration(seconds: 8));
        final n = UdsDiagnostic.parseNegative(raw);
        if (n != null) throw StateError(tx('Prosedür {0} reddedildi: {1}', [token, n.description]));
        final payload = UdsDiagnostic.readDidPayload(raw, int.parse(did, radix: 16));
        if (payload == null) throw StateError(tx('Prosedür {0} veri döndürmedi', [token]));
        snapshots[did] = RecoveredVagAdaptationService.hex(payload);
        continue;
      }
      final replay = RegExp(r'^2E([0-9A-F]{4})$').firstMatch(token);
      if (replay != null) {
        final did = replay.group(1)!;
        final value = snapshots[did];
        if (value == null) throw StateError(tx('Prosedür {0} için önceki DID snapshotı yok', [token]));
        token = '2E$did$value';
      }
      final raw = await _sendAndWait(token, timeout: const Duration(seconds: 10));
      final n = UdsDiagnostic.parseNegative(raw);
      if (n != null) throw StateError(tx('Prosedür {0} reddedildi: {1}', [token, n.description]));
      if (restoreHeader != null) {
        await _sendAndWait('ATSH$restoreHeader', timeout: const Duration(seconds: 3));
      }
    }
  }


  Future<VagLightReadResult> readMqbLightConfiguration(VagLightChannel channel) async {
    if (_state != ObdConnectionState.ready) {
      return VagLightReadResult(false, tx('Önce araca bağlan.'));
    }
    _exclusiveDiagnosticOperation = true;
    notifyListeners();
    try {
      await _sendAndWait('ATH1');
      await _sendAndWait('ATAL');
      await _sendAndWait('ATCAF1');
      await _sendAndWait('ATSH${VagLightConfigurationService.requestId}');
      await _sendAndWait('ATCRA${VagLightConfigurationService.responseId}');
      final raw = await _sendAndWait('22${channel.did}', timeout: const Duration(seconds: 8));
      final negative = UdsDiagnostic.parseNegative(raw);
      if (negative != null) return VagLightReadResult(false, tx('ECU reddetti: {0}', [negative.description]));
      final payload = UdsDiagnostic.readDidPayload(raw, int.parse(channel.did, radix: 16));
      if (payload == null || payload.length < 17) {
        return VagLightReadResult(false, tx('Leuchte {0} verisi okunamadı veya payload kısa ({1} byte).', [channel.did, payload?.length ?? 0]));
      }
      final config = VagLightConfiguration.fromPayload(channel, payload);
      return VagLightReadResult(true, tx('ECU değeri okundu.'), configuration: config);
    } catch (e) {
      return VagLightReadResult(false, tx('Lamba kanalı okuma hatası: {0}', [e]));
    } finally {
      try { await _sendAndWait('ATCRA'); } catch (_) {}
      try { await _sendAndWait('ATSH7DF'); } catch (_) {}
      try { await _sendAndWait('ATH0'); } catch (_) {}
      _exclusiveDiagnosticOperation = false;
      notifyListeners();
    }
  }

  Future<CodingApplyResult> writeMqbLightConfiguration({
    required VagLightConfiguration configuration,
    required CodingHistoryProvider history,
  }) async {
    if (_isVehicleMoving) return CodingApplyResult(false, tx('Araç hareket halindeyken ECU\'ya yazılmaz. Aracı durdurup park konumuna alın.'));
    if (!_isRealMode || !_connection.isConnected || _connection.isReconnecting) {
      return CodingApplyResult(false, tx('Kodlama için canlı OBD bağlantısı gerekli.'));
    }
    final vin = _detectedVin;
    if (vin == null || vin.length != 17) {
      return CodingApplyResult(false, tx('Yazma için geçerli 17 karakter VIN zorunlu.'));
    }
    final channel = configuration.channel;
    final requested = VagLightConfigurationService.hex(configuration.toPayload());
    _exclusiveDiagnosticOperation = true;
    notifyListeners();
    try {
      await _sendAndWait('ATH1');
      await _sendAndWait('ATAL');
      await _sendAndWait('ATCAF1');
      await _sendAndWait('ATSH${VagLightConfigurationService.requestId}');
      await _sendAndWait('ATCRA${VagLightConfigurationService.responseId}');

      final partRaw = await _sendAndWait('22F187', timeout: const Duration(seconds: 7));
      final softwareRaw = await _sendAndWait('22F189', timeout: const Duration(seconds: 7));
      final partBytes = UdsDiagnostic.readDidPayload(partRaw, 0xF187);
      final softwareBytes = UdsDiagnostic.readDidPayload(softwareRaw, 0xF189);
      final partNumber = partBytes == null ? '' : UdsDiagnostic.ascii(partBytes).trim();
      final softwareVersion = softwareBytes == null ? '' : UdsDiagnostic.ascii(softwareBytes).trim();

      final beforeRaw = await _sendAndWait('22${channel.did}', timeout: const Duration(seconds: 8));
      final beforePayload = UdsDiagnostic.readDidPayload(beforeRaw, int.parse(channel.did, radix: 16));
      if (beforePayload == null || beforePayload.length < 17) {
        return CodingApplyResult(false, tx('Mevcut Leuchte değeri okunamadı; yazma iptal edildi.'));
      }
      final beforeHex = VagLightConfigurationService.hex(beforePayload);
      if (beforeHex == requested) {
        return CodingApplyResult(true, tx('Seçili değer zaten ECU üzerinde kayıtlı.'));
      }

      final session = await _sendAndWait('1003', timeout: const Duration(seconds: 6));
      final sessionNegative = UdsDiagnostic.parseNegative(session);
      if (sessionNegative != null) {
        return CodingApplyResult(false, tx('ECU genişletilmiş oturumu reddetti: {0}', [sessionNegative.description]));
      }

      await _recoveredVagSecurityAccess(VagLightConfigurationService.securityAccessCode);

      final result = await CodingTransactionService.execute(
        requestedHex: requested,
        readCurrent: () async {
          final raw = await _sendAndWait('22${channel.did}', timeout: const Duration(seconds: 8));
          final p = UdsDiagnostic.readDidPayload(raw, int.parse(channel.did, radix: 16));
          return p == null ? '' : VagLightConfigurationService.hex(p);
        },
        writeValue: (value) async {
          try { await _sendAndWait('3E00', timeout: const Duration(seconds: 3)); } catch (_) {}
          final raw = await _sendAndWait('2E${channel.did}$value', timeout: const Duration(seconds: 10));
          final negative = UdsDiagnostic.parseNegative(raw);
          if (negative != null) throw StateError(negative.description);
          final did = int.parse(channel.did, radix: 16);
          if (!_containsSequence(UdsDiagnostic.hexBytes(raw), [0x6E, (did >> 8) & 0xFF, did & 0xFF])) {
            throw StateError(tx('Pozitif 0x6E yazma cevabı yok'));
          }
        },
        createBackup: (original) => CodingBackupRecord(
          id: '${DateTime.now().microsecondsSinceEpoch}-leuchte-${channel.index}',
          vin: vin,
          brand: _detectedBrand ?? 'VAG',
          moduleName: '09 BCM • ${channel.name}',
          requestId: VagLightConfigurationService.requestId,
          responseId: VagLightConfigurationService.responseId,
          did: channel.did,
          originalHex: original,
          status: CodingBackupStatus.captured,
          createdAt: DateTime.now().toUtc(),
          ecuPartNumber: partNumber.isEmpty ? null : partNumber,
          ecuSoftwareVersion: softwareVersion.isEmpty ? null : softwareVersion,
        ),
        saveBackup: history.capture,
        updateStatus: history.updateStatus,
      );
      return CodingApplyResult(result.success, result.message, rolledBack: result.rolledBack);
    } catch (e) {
      return CodingApplyResult(false, tx('Lamba adaptasyonu yazma hatası: {0}', [e]));
    } finally {
      try { await _sendAndWait('1001'); } catch (_) {}
      try { await _sendAndWait('ATCRA'); } catch (_) {}
      try { await _sendAndWait('ATSH7DF'); } catch (_) {}
      try { await _sendAndWait('ATH0'); } catch (_) {}
      _exclusiveDiagnosticOperation = false;
      notifyListeners();
    }
  }

  Future<RecoveredVagAdaptationReadResult> readRecoveredVagAdaptation(
    RecoveredVagAdaptation item,
  ) async {
    if (item.did.length != 4) {
      return RecoveredVagAdaptationReadResult(success: false, message: tx('Bu kayıt standart 2-byte DID kullanmıyor.'));
    }
    if (_state != ObdConnectionState.ready) {
      return RecoveredVagAdaptationReadResult(success: false, message: tx('Önce araca bağlan.'));
    }
    _exclusiveDiagnosticOperation = true; notifyListeners();
    try {
      await _sendAndWait('ATH1'); await _sendAndWait('ATAL'); await _sendAndWait('ATCAF1');
      await _sendAndWait('ATSH${item.requestId}'); await _sendAndWait('ATCRA${item.responseId}');
      final raw = await _sendAndWait('22${item.did}', timeout: const Duration(seconds: 8));
      final negative = UdsDiagnostic.parseNegative(raw);
      if (negative != null) return RecoveredVagAdaptationReadResult(success:false,message:negative.description);
      final payload = UdsDiagnostic.readDidPayload(raw, int.parse(item.did, radix:16));
      if (payload == null || payload.isEmpty) return RecoveredVagAdaptationReadResult(success:false,message:tx('ECU pozitif DID verisi döndürmedi.'));
      String? selected;
      for (final option in item.options) { if (RecoveredVagAdaptationService.optionMatches(payload,item,option)) { selected=option.title; break; } }
      final human = RecoveredVagAdaptationService.humanReadableValue(payload, item);
      return RecoveredVagAdaptationReadResult(success:true,message:tx('Mevcut değer: {0}', [human]),currentHex:RecoveredVagAdaptationService.hex(payload),selectedOptionTitle:selected ?? human,payload:List<int>.unmodifiable(payload));
    } catch(e) { return RecoveredVagAdaptationReadResult(success:false,message:tx('Adaptasyon okuma hatası: {0}', [e])); }
    finally { try{await _sendAndWait('ATCRA');}catch(_){} try{await _sendAndWait('ATSH7DF');}catch(_){} try{await _sendAndWait('ATH0');}catch(_){} _exclusiveDiagnosticOperation=false; notifyListeners(); }
  }

  Future<CodingApplyResult> applyRecoveredVagAdaptation({
    required RecoveredVagAdaptation item,
    required RecoveredVagOption option,
    required CodingHistoryProvider history,
    String? manualAccessCode,
  }) async {
    if (_isVehicleMoving) return CodingApplyResult(false, tx('Araç hareket halindeyken ECU\'ya yazılmaz. Aracı durdurup park konumuna alın.'));
    if (!_isRealMode || !_connection.isConnected || _connection.isReconnecting) return CodingApplyResult(false,tx('Kodlama için canlı OBD bağlantısı gerekli.'));
    if (!item.hasSelectableOptions || item.did.length != 4) return CodingApplyResult(false,tx('Bu kayıt için güvenli seçilebilir değer tanımı yok.'));
    final vin=_detectedVin; if(vin==null||vin.length!=17) return CodingApplyResult(false,tx('Yazma için geçerli 17 karakter VIN zorunlu.'));
    final manualCode = manualAccessCode?.trim() ?? '';
    final accessSource = manualCode.isNotEmpty ? manualCode : item.password;
    final accessCode = accessSource.trim().isEmpty ? null : _parseRecoveredAccessCode(accessSource);
    if (item.hasPasswordRequirement && accessCode == null) {
      return CodingApplyResult(false,tx('Security Access gerekli. Kayıtta kesin anahtar yok; erişim anahtarını elle girebilirsin. İpucu: {0}', [item.passwordHints]));
    }
    _exclusiveDiagnosticOperation=true; notifyListeners();
    try {
      await _sendAndWait('ATH1'); await _sendAndWait('ATAL'); await _sendAndWait('ATCAF1');
      await _sendAndWait('ATSH${item.requestId}'); await _sendAndWait('ATCRA${item.responseId}');
      final partRaw=await _sendAndWait('22F187',timeout:const Duration(seconds:7));
      final softwareRaw=await _sendAndWait('22F189',timeout:const Duration(seconds:7));
      final partBytes=UdsDiagnostic.readDidPayload(partRaw,0xF187); final softwareBytes=UdsDiagnostic.readDidPayload(softwareRaw,0xF189);
      final partNumber=partBytes==null?'':UdsDiagnostic.ascii(partBytes).trim(); final softwareVersion=softwareBytes==null?'':UdsDiagnostic.ascii(softwareBytes).trim();
      // F187/F189 are useful identity evidence, but not every VAG ECU exposes both.
      // The authoritative safety anchor is the live target ECU + VIN + current DID value
      // captured before the write. Missing optional identity DIDs must not block a
      // reversible adaptation that we can read and verify on the selected ECU.
      final readRaw=await _sendAndWait('22${item.did}',timeout:const Duration(seconds:8));
      final before=UdsDiagnostic.readDidPayload(readRaw,int.parse(item.did,radix:16));
      if(before==null||before.isEmpty) return CodingApplyResult(false,tx('Mevcut adaptasyon değeri okunamadı; yazma iptal edildi.'));
      final requestedBytes=RecoveredVagAdaptationService.applyOptionToPayload(before,item,option);
      if(requestedBytes==null) return CodingApplyResult(false,tx('Kurtarılan değer tanımı mevcut ECU payloadına uygulanamadı.'));
      final requested=RecoveredVagAdaptationService.hex(requestedBytes);
      final session=await _sendAndWait('1003',timeout:const Duration(seconds:6));
      final sessionAccepted=_containsSequence(UdsDiagnostic.hexBytes(session),const [0x50,0x03]);
      if(!sessionAccepted && (accessCode!=null || item.preWrite.trim().isNotEmpty)) {
        // The recovered procedure/security path may carry the ECU-specific session command.
        // Do not fail globally on a Gateway-style 10 03 rejection; the target ECU's
        // actual procedure and final 0x2E/0x6E exchange are authoritative.
      }
      if(accessCode!=null && !item.preWrite.toUpperCase().contains('2703')) await _recoveredVagSecurityAccess(accessCode);
      final snapshots=<String,String>{};
      await _runRecoveredProcedure(item.preWrite,accessCode:accessCode,snapshots:snapshots);
      final result=await CodingTransactionService.execute(
        requestedHex:requested,
        readCurrent:()async{final raw=await _sendAndWait('22${item.did}',timeout:const Duration(seconds:8));final p=UdsDiagnostic.readDidPayload(raw,int.parse(item.did,radix:16));return p==null?'':RecoveredVagAdaptationService.hex(p);},
        writeValue:(value)async{final raw=await _sendAndWait('2E${item.did}$value',timeout:const Duration(seconds:10));final n=UdsDiagnostic.parseNegative(raw);if(n!=null)throw StateError(n.description);final did=int.parse(item.did,radix:16);if(!_containsSequence(UdsDiagnostic.hexBytes(raw),[0x6E,(did>>8)&0xFF,did&0xFF]))throw StateError(tx('Pozitif 0x6E yazma cevabı yok'));},
        createBackup:(original)=>CodingBackupRecord(id:'${DateTime.now().microsecondsSinceEpoch}-legacy-${item.platform}-${item.uid}',vin:vin,brand:_detectedBrand??'VAG',moduleName:'${item.platform} ${item.requestId}',requestId:item.requestId,responseId:item.responseId,did:item.did,originalHex:original,status:CodingBackupStatus.captured,createdAt:DateTime.now().toUtc(),ecuPartNumber:partNumber.isEmpty?null:partNumber,ecuSoftwareVersion:softwareVersion.isEmpty?null:softwareVersion),
        saveBackup:history.capture,updateStatus:history.updateStatus,
      );
      if(result.success) await _runRecoveredProcedure(item.postWrite,accessCode:accessCode,snapshots:snapshots);
      return CodingApplyResult(result.success,result.message,rolledBack:result.rolledBack);
    } catch(e) { return CodingApplyResult(false,tx('Kurtarılan adaptasyon yazma hatası: {0}', [e])); }
    finally { try{await _sendAndWait('1001');}catch(_){} try{await _sendAndWait('ATCRA');}catch(_){} try{await _sendAndWait('ATSH7DF');}catch(_){} try{await _sendAndWait('ATH0');}catch(_){} _exclusiveDiagnosticOperation=false; notifyListeners(); }
  }

  /// Restores only a value previously captured by OTOSINYAL. Raw/manual
  /// addresses are intentionally not accepted by this API.
  Future<CodingRollbackResult> rollbackCodingBackup(CodingBackupRecord record) async {
    if (_isVehicleMoving) return CodingRollbackResult(false, tx('Araç hareket halindeyken ECU\'ya yazılmaz. Aracı durdurup park konumuna alın.'));
    if (!record.canRollback) {
      return CodingRollbackResult(false, tx('Bu kayıt geri alınabilir durumda değil'));
    }
    if (_detectedVin != record.vin) {
      return CodingRollbackResult(false, tx('VIN uyuşmuyor; başka araca yedek yazılamaz'));
    }

    final did = record.did.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase().padLeft(4, '0');
    final original = record.originalHex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (did.length != 4 || original.isEmpty || original.length.isOdd) {
      return CodingRollbackResult(false, tx('Yedek kod verisi bozuk'));
    }

    _exclusiveDiagnosticOperation = true;
    notifyListeners();
    try {
      await _sendAndWait('ATH1', timeout: const Duration(seconds: 3));
      await _sendAndWait('ATAL', timeout: const Duration(seconds: 3));
      await _sendAndWait('ATCAF1', timeout: const Duration(seconds: 3));
      await _sendAndWait('ATSH${record.requestId}', timeout: const Duration(seconds: 3));
      await _sendAndWait('ATCRA${record.responseId}', timeout: const Duration(seconds: 3));

      final partRaw = await _sendAndWait('22F187', timeout: const Duration(seconds: 7));
      final softwareRaw = await _sendAndWait('22F189', timeout: const Duration(seconds: 7));
      final currentPartBytes = UdsDiagnostic.readDidPayload(partRaw, 0xF187);
      final currentSoftwareBytes = UdsDiagnostic.readDidPayload(softwareRaw, 0xF189);
      final currentPart = currentPartBytes == null ? '' : UdsDiagnostic.ascii(currentPartBytes);
      final currentSoftware = currentSoftwareBytes == null ? '' : UdsDiagnostic.ascii(currentSoftwareBytes);
      if (record.ecuPartNumber != null && record.ecuPartNumber!.isNotEmpty &&
          (currentPart.isEmpty || currentPart != record.ecuPartNumber)) {
        return CodingRollbackResult(false, tx('Hedef ECU parça numarası yedekle uyuşmuyor; geri dönüş reddedildi'));
      }
      if (record.ecuSoftwareVersion != null && record.ecuSoftwareVersion!.isNotEmpty &&
          (currentSoftware.isEmpty || currentSoftware != record.ecuSoftwareVersion)) {
        return CodingRollbackResult(false, tx('Hedef ECU yazılım sürümü yedekle uyuşmuyor; geri dönüş reddedildi'));
      }

      final session = await _sendAndWait('1003', timeout: const Duration(seconds: 6));
      if (!_containsSequence(UdsDiagnostic.hexBytes(session), const [0x50, 0x03])) {
        return CodingRollbackResult(false, tx('ECU genişletilmiş oturumu kabul etmedi'));
      }

      final beforeRaw = await _sendAndWait('22$did', timeout: const Duration(seconds: 8));
      final before = UdsDiagnostic.readDidPayload(beforeRaw, int.parse(did, radix: 16));
      if (before == null || before.isEmpty) {
        return CodingRollbackResult(false, tx('Mevcut kod okunamadı; geri dönüş iptal edildi'));
      }

      final writeRaw = await _sendAndWait('2E$did$original', timeout: const Duration(seconds: 10));
      final negative = UdsDiagnostic.parseNegative(writeRaw);
      if (negative != null) {
        return CodingRollbackResult(false, tx('ECU geri dönüşü reddetti: {0}', [negative.description]));
      }
      final positive = UdsDiagnostic.hexBytes(writeRaw);
      if (!_containsSequence(positive, [0x6E, int.parse(did.substring(0, 2), radix: 16), int.parse(did.substring(2), radix: 16)])) {
        return CodingRollbackResult(false, tx('Pozitif yazma onayı alınamadı'));
      }

      final verifyRaw = await _sendAndWait('22$did', timeout: const Duration(seconds: 8));
      final verified = UdsDiagnostic.readDidPayload(verifyRaw, int.parse(did, radix: 16));
      if (verified == null) return CodingRollbackResult(false, tx('Geri dönüş sonrası doğrulama okunamadı'));
      final verifiedHex = verified.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
      if (!verifiedHex.startsWith(original)) {
        return CodingRollbackResult(false, tx('ECU değeri yedekle eşleşmedi'), verifiedHex: verifiedHex);
      }
      DiagnosticFlightRecorder.instance.event('CODING_ROLLBACK_OK', data: {
        'vin': record.vin,
        'module': record.moduleName,
        'did': did,
        'backup_id': record.id,
      });
      return CodingRollbackResult(true, tx('Önceki kod geri yüklendi ve ECU’dan doğrulandı'), verifiedHex: verifiedHex);
    } catch (error) {
      return CodingRollbackResult(false, tx('Geri dönüş iletişim hatası: {0}', [error]));
    } finally {
      try { await _sendAndWait('1001', timeout: const Duration(seconds: 3)); } catch (_) {}
      try { await _sendAndWait('ATCRA', timeout: const Duration(seconds: 2)); } catch (_) {}
      try { await _sendAndWait('ATSH7DF', timeout: const Duration(seconds: 2)); } catch (_) {}
      try { await _sendAndWait('ATH0', timeout: const Duration(seconds: 2)); } catch (_) {}
      _exclusiveDiagnosticOperation = false;
      notifyListeners();
    }
  }

  Future<void> readReadiness() async {
    if (!canQueryDtc) return;
    if (_isDemoMode) {
      _readiness = ObdReadinessStatus(completed: 7, supported: 8, incomplete: [tx('EVAP sistemi')]);
      notifyListeners();
      return;
    }
    final response = await _sendDiagnosticWithRetry('0101');
    for (final p in _responsePayloads(response, 0x41)) {
      if (p.length < 5 || p[0] != 0x01) continue;
      final b = p[2], c = p[3], d = p[4];
      // SAE PID 01: B[0..2] sürekli monitor desteği, B[4..6] tamamlanmama;
      // C destek maskesi, D aynı monitorlerin tamamlanmama maskesidir.
      var supported = 0;
      var incomplete = 0;
      for (var bit = 0; bit < 3; bit++) {
        if ((b & (1 << bit)) != 0) {
          supported++;
          if ((b & (1 << (bit + 4))) != 0) incomplete++;
        }
      }
      for (var bit = 0; bit < 8; bit++) {
        if ((c & (1 << bit)) != 0) {
          supported++;
          if ((d & (1 << bit)) != 0) incomplete++;
        }
      }
      _readiness = ObdReadinessStatus(completed: supported - incomplete, supported: supported, incomplete: incomplete == 0 ? const [] : [tx('{0} monitör tamamlanmadı', [incomplete])]);
      notifyListeners();
      return;
    }
  }

  Future<void> readFreezeFrame() async {
    if (!canQueryDtc) return;
    if (_isDemoMode) {
      _freezeFrame = const FreezeFrameSnapshot(triggerDtc: 'P0301', rpm: 2460, speedKmh: 74, coolantC: 91, loadPercent: 68, mapKpa: 154);
      notifyListeners();
      return;
    }
    String? dtc;
    int? rpm, speed, coolant, load, map;
    Future<List<int>?> framePid(int pid) async {
      final cmd = '02${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}00';
      final r = await _sendDiagnosticWithRetry(cmd);
      for (final p in _responsePayloads(r, 0x42)) {
        if (p.length >= 2 && p[0] == pid) return p;
      }
      return null;
    }
    final cause = await framePid(0x02);
    if (cause != null && cause.length >= 4) dtc = _decodeDtcBytes(cause[2], cause[3]);
    final rp = await framePid(0x0C); if (rp != null && rp.length >= 4) rpm = ((rp[2] << 8) | rp[3]) ~/ 4;
    final sp = await framePid(0x0D); if (sp != null && sp.length >= 3) speed = sp[2];
    final ct = await framePid(0x05); if (ct != null && ct.length >= 3) coolant = ct[2] - 40;
    final ld = await framePid(0x04); if (ld != null && ld.length >= 3) load = (ld[2] * 100 / 255).round();
    final mp = await framePid(0x0B); if (mp != null && mp.length >= 3) map = mp[2];
    _freezeFrame = FreezeFrameSnapshot(triggerDtc: dtc, rpm: rpm, speedKmh: speed, coolantC: coolant, loadPercent: load, mapKpa: map);
    notifyListeners();
  }

  Future<void> readMode06Summary() async {
    if (!canQueryDtc) return;
    if (_isDemoMode) {
      _mode06Raw = [tx('Demo monitor sonucu mevcut')];
      notifyListeners();
      return;
    }
    final response = await _sendDiagnosticWithRetry('06', timeout: const Duration(seconds: 8));
    final n = _normalize(response, echoCommand: '06');
    _mode06Raw = _isNoData(n) ? const [] : n.split('\n').where((e) => e.trim().isNotEmpty).take(40).toList(growable: false);
    notifyListeners();
  }

  Future<void> discoverEcuModules() async {
    if (!canQueryDtc || _isDiscoveringEcuModules) return;
    _isDiscoveringEcuModules = true;
    _ecuDiscoveryError = null;
    notifyListeners();

    if (_isDemoMode) {
      _ecuModules
        ..clear()
        ..addAll([
          EcuModuleInfo(canId: '7E8', label: 'Motor ECU', ecuName: 'ECM-EngineControl', calibrationId: 'DEMO-ECM-001', cvn: '12AB34CD'),
          EcuModuleInfo(canId: '7E9', label: tx('Şanzıman ECU'), ecuName: 'TCM-Transmission', calibrationId: 'DEMO-TCM-001', cvn: '98FE76DC'),
        ]);
      _isDiscoveringEcuModules = false;
      notifyListeners();
      return;
    }

    await _acquireExclusiveDiagnosticOperation();
    try {
      // OBD-Droid'deki güvenli Mode 09 keşif yaklaşımı: yalnız okuma,
      // başlıkları geçici aç, ECU isim/kalibrasyon/CVN iste, her durumda ATH0'a dön.
      await _sendAndWait('ATH1');
      await _sendAndWait('ATCAF1');
      final calRaw = await _sendAndWait('0904', timeout: const Duration(seconds: 8));
      final cvnRaw = await _sendAndWait('0906', timeout: const Duration(seconds: 8));
      final nameRaw = await _sendAndWait('090A', timeout: const Duration(seconds: 8));

      final calById = _parseMode09ByCanId(calRaw, 0x04, ascii: true);
      final cvnById = _parseMode09ByCanId(cvnRaw, 0x06, ascii: false);
      final nameById = _parseMode09ByCanId(nameRaw, 0x0A, ascii: true);
      final ids = <String>{...calById.keys, ...cvnById.keys, ...nameById.keys}.toList()..sort();

      _ecuModules
        ..clear()
        ..addAll(ids.map((id) => EcuModuleInfo(
              canId: id,
              label: _guessEcuLabel(id),
              ecuName: nameById[id],
              calibrationId: calById[id],
              cvn: cvnById[id],
              rawResponses: const [],
            )));

      if (_ecuModules.isEmpty) {
        _ecuDiscoveryError = tx('Mode 09 başlıklı ECU cevabı alınamadı. Araç/adapter bu keşif yöntemini desteklemiyor olabilir.');
      }
    } catch (e) {
      developer.log('ECU modül keşfi hatası: $e', name: 'ObdLogic');
      _ecuDiscoveryError = tx('ECU modül keşfi sırasında iletişim hatası oluştu');
    } finally {
      try { await _sendAndWait('ATH0'); } catch (_) {}
      try { await _sendAndWait('ATCRA'); } catch (_) {}
      _releaseExclusiveDiagnosticOperation();
      _isDiscoveringEcuModules = false;
      notifyListeners();
    }
  }

  Map<String, String> _parseMode09ByCanId(String raw, int pid, {required bool ascii}) {
    final collected = <String, List<int>>{};
    for (final rawLine in raw.replaceAll('>', '\n').replaceAll('\r', '\n').split('\n')) {
      final line = rawLine.trim().toUpperCase();
      if (line.isEmpty) continue;

      String? id;
      String? body;
      final spaced = RegExp(r'^([0-9A-F]{3}|[0-9A-F]{8})\s+(.+)$').firstMatch(line);
      if (spaced != null) {
        id = spaced.group(1)!;
        body = spaced.group(2)!;
      } else {
        final compact = line.replaceAll(RegExp(r'[^0-9A-F]'), '');
        if (compact.length > 5 && compact.length.isOdd && compact.substring(3).length.isEven) {
          id = compact.substring(0, 3);
          body = compact.substring(3);
        } else if (compact.length >= 12 && compact.length.isEven && compact.startsWith('18DA')) {
          id = compact.substring(0, 8);
          body = compact.substring(8);
        }
      }
      if (id == null || body == null) continue;

      var bytes = _hexBytes(body);
      if (bytes.isEmpty) continue;

      // Strip ELM length byte or ISO-TP PCI byte(s).
      if (bytes[0] <= 0x08 && bytes.length > 1) {
        bytes = bytes.sublist(1);
      } else if ((bytes[0] & 0xF0) == 0x10 && bytes.length > 2) {
        bytes = bytes.sublist(2);
      } else if ((bytes[0] & 0xF0) == 0x20 && bytes.length > 1) {
        bytes = bytes.sublist(1);
      }
      collected.putIfAbsent(id, () => <int>[]).addAll(bytes);
    }

    final result = <String, String>{};
    for (final entry in collected.entries) {
      final bytes = entry.value;
      var marker = -1;
      for (var i = 0; i + 1 < bytes.length; i++) {
        if (bytes[i] == 0x49 && bytes[i + 1] == pid) {
          marker = i + 2;
          break;
        }
      }
      if (marker < 0 || marker >= bytes.length) continue;
      var payload = bytes.sublist(marker);
      // Mode 09 responses often include a message counter/sequence byte.
      if (payload.isNotEmpty && payload.first <= 0x20) payload = payload.sublist(1);
      if (payload.isEmpty) continue;

      if (ascii) {
        final text = String.fromCharCodes(payload.where((b) => b >= 0x20 && b <= 0x7E))
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (text.isNotEmpty) result[entry.key] = text;
      } else {
        final useful = payload.where((b) => b != 0x00).toList();
        if (useful.isNotEmpty) {
          result[entry.key] = useful.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
        }
      }
    }
    return result;
  }

  String _guessEcuLabel(String canId) {
    switch (canId.toUpperCase()) {
      case '7E8': return 'Motor / Powertrain ECU';
      case '7E9': return tx('Şanzıman / İkincil Powertrain ECU');
      case '7EA': return tx('İkincil ECU');
      case '7EB': return tx('İkincil ECU');
      default: return 'OBD-II ECU';
    }
  }

  Future<void> runFullVehicleScan() async {
    if (!canQueryDtc || _isFullScanning) return;
    final ownsExclusiveMode = !_exclusiveDiagnosticOperation;
    if (ownsExclusiveMode) _exclusiveDiagnosticOperation = true;
    DiagnosticFlightRecorder.instance.start(reason: 'full_vehicle_scan', context: {'mode': _isDemoMode ? 'demo' : 'real', 'brand': _detectedBrand, 'vin': _detectedVin});
    _isFullScanning = true;
    notifyListeners();
    Object? failure;
    try {
      await _readAdapterInfo();
      if (_detectedVin == null) await _detectVehicleBrand();
      await runOemDiscovery();
      await readMilStatus();
      await readTroubleCodes();
      await readReadiness();
      await readFreezeFrame();
      await readMode06Summary();
      await refreshAdvancedDiagnostics();
      _lastFullScan = DateTime.now();
      DiagnosticFlightRecorder.instance.finish(summary: {'brand': _detectedBrand, 'vin': _detectedVin, 'supported_pids': _supportedMode01Pids.length, 'dtc_count': _dtcEntries.length, 'oem_identities': _oemDiscovery.identities.where((e)=>e.supported).length});
    } catch (error) {
      failure = error;
      DiagnosticFlightRecorder.instance.finish(summary: {
        'failed': true,
        'error': error.toString(),
        'brand': _detectedBrand,
        'vin': _detectedVin,
      });
      _dtcError = tx('Tam tarama tamamlanamadı: {0}', [error]);
      _errorEventController.add(_dtcError!);
    } finally {
      _isFullScanning = false;
      if (ownsExclusiveMode) _exclusiveDiagnosticOperation = false;
      notifyListeners();
    }
    if (failure != null) return;
  }

  String? _requestIdForResponseId(String responseId) {
    final value = int.tryParse(responseId, radix: 16);
    if (value == null || value > 0x7FF || value < 0x08) return null;
    return (value - 8).toRadixString(16).padLeft(3, '0').toUpperCase();
  }

  Future<List<String>> _readModuleDtcCodes() async {
    final codes = <String>{};
    for (final item in const <(String, int)>[
      ('03', 0x43),
      ('07', 0x47),
      ('0A', 0x4A),
    ]) {
      final response = await _sendAndWait(item.$1, timeout: const Duration(seconds: 5));
      if (!_isNoData(response)) {
        codes.addAll(_parseTroubleCodes(response, item.$2));
      }
    }
    return codes.toList(growable: false)..sort();
  }

  List<String> _parseUdsDtcCodes(List<int> bytes) {
    final codes = <String>{};
    for (var i = 0; i + 2 < bytes.length; i++) {
      if (bytes[i] != 0x59) continue;
      final subFunction = bytes[i + 1];
      var start = i + 2;
      if (subFunction == 0x02 && start < bytes.length) start++;
      for (var cursor = start; cursor + 3 < bytes.length; cursor += 4) {
        final b0 = bytes[cursor];
        final b1 = bytes[cursor + 1];
        final b2 = bytes[cursor + 2];
        if (b0 == 0x00 && b1 == 0x00 && b2 == 0x00) continue;
        final letter = const <String>['P', 'C', 'B', 'U'][(b0 >> 6) & 0x03];
        final code = '$letter${(b0 >> 4) & 0x03}${(b0 & 0x0F).toRadixString(16).toUpperCase()}${(b1 >> 4).toRadixString(16).toUpperCase()}${(b1 & 0x0F).toRadixString(16).toUpperCase()}';
        if (code.length == 5) codes.add(code);
      }
    }
    return codes.toList(growable: false)..sort();
  }

  List<int> _udsBytes(String raw) => UdsDiagnostic.hexBytes(raw.toUpperCase());

  bool _hasUdsPositive(String raw, int service) =>
      _udsBytes(raw).contains(service);

  Future<DiagnosticUnitScanResult?> _scanCanUdsProfile(
    OemModuleProfile profile,
  ) async {
    final requestId = profile.requestId;
    final responseId = profile.responseId;
    if (requestId == null || responseId == null) return null;
    try {
      await _sendAndWait('ATSH$requestId');
      await _sendAndWait('ATCRA$responseId');
      await _sendAndWait('ATCAF1');

      // ReadDataByIdentifier F190 and ReadDTCInformation 1902FF are both
      // read-only UDS services; no session change or security access is sent.
      final identity = await _sendAndWait('22F190', timeout: const Duration(seconds: 5));
      final dtcRaw = await _sendAndWait('1902FF', timeout: const Duration(seconds: 6));
      final identityPositive = _hasUdsPositive(identity, 0x62);
      final dtcPositive = _hasUdsPositive(dtcRaw, 0x59);
      if (!identityPositive && !dtcPositive) return null;
      final codes = _parseUdsDtcCodes(_udsBytes(dtcRaw));
      return DiagnosticUnitScanResult(
        unit: profile.unit,
        discovered: true,
        demo: false,
        responseId: responseId,
        dtcs: codes,
        detail: codes.isEmpty ? tx('UDS cevabı alındı, DTC yok') : tx('{0} UDS DTC bulundu', [codes.length]),
        protocol: profile.protocolLabel,
        profile: '${profile.name} • ${profile.addressLabel}',
        scannedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<DiagnosticUnitScanResult?> _scanDoipProfile(
    OemModuleProfile profile,
    DoipDiagnosticClient client,
  ) async {
    final target = profile.doipLogicalAddress;
    if (target == null) return null;
    try {
      final identity = await client.requestUds(target, const [0x22, 0xF1, 0x90]);
      final dtc = await client.requestUds(target, const [0x19, 0x02, 0xFF]);
      final identityPositive = identity.contains(0x62);
      final dtcPositive = dtc.contains(0x59);
      if (!identityPositive && !dtcPositive) return null;
      final codes = _parseUdsDtcCodes(dtc);
      return DiagnosticUnitScanResult(
        unit: profile.unit,
        discovered: true,
        demo: false,
        responseId: '0x${target.toRadixString(16).padLeft(4, '0').toUpperCase()}',
        dtcs: codes,
        detail: codes.isEmpty ? tx('DoIP / UDS cevabı alındı, DTC yok') : tx('{0} DoIP UDS DTC bulundu', [codes.length]),
        protocol: profile.protocolLabel,
        profile: '${profile.name} • ${profile.addressLabel}',
        scannedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Runs only safe read probes against the selected modules.
  ///
  /// No coding, actuator test, security access or write service is sent here.
  /// A module is marked as found only after it returns a real Mode 01 response.
  Future<void> scanSelectedUnits(Set<DiagnosticUnit> selected) async {
    if (!canQueryDtc || _isModuleScanning || selected.isEmpty) return;
    _isModuleScanning = true;
    _exclusiveDiagnosticOperation = true;
    _moduleScanResults
      ..clear()
      ..addEntries(selected.map((unit) => MapEntry(
            unit,
            DiagnosticUnitScanResult(
              unit: unit,
              discovered: false,
              demo: false,
              responseId: null,
              dtcs: const [],
              detail: tx('Tarama bekleniyor'),
              scannedAt: DateTime.now(),
            ),
          )));
    notifyListeners();

    try {
      final engineSelected = selected.contains(DiagnosticUnit.engine);
      if (engineSelected) {
        await runFullVehicleScan();
        _moduleScanResults[DiagnosticUnit.engine] = DiagnosticUnitScanResult(
          unit: DiagnosticUnit.engine,
          discovered: _isDemoMode ||
              _oemDiscovery.respondingCanIds.isNotEmpty ||
              _dtcEntries.isNotEmpty ||
              _supportedMode01Pids.isNotEmpty,
          demo: _isDemoMode,
          responseId: _isDemoMode ? '7E8' : (_oemDiscovery.respondingCanIds.contains('7E8') ? '7E8' : null),
          dtcs: _dtcEntries.map((entry) => entry.code).toList(growable: false),
          detail: _isDemoMode ? tx('Demo ECU verisi') : tx('Motor ECU standart OBD taraması tamamlandı'),
          scannedAt: DateTime.now(),
        );
      }

      if (_isDemoMode) {
        for (final unit in selected.where((unit) => unit != DiagnosticUnit.engine)) {
          _moduleScanResults[unit] = DiagnosticUnitScanResult(
            unit: unit,
            discovered: false,
            demo: true,
            responseId: null,
            dtcs: const [],
            detail: tx('Demo modunda bu üniteye ait sahte cevap üretilmiyor'),
            scannedAt: DateTime.now(),
          );
        }
        return;
      }

      await _sendAndWait('ATH1');
      final functionalProbe = await _sendAndWait('0100', timeout: const Duration(seconds: 8));
      final functionalResponders = _extractCanResponseIds(functionalProbe);

      for (final unit in selected.where((unit) => unit != DiagnosticUnit.engine)) {
        final definition = diagnosticUnitDefinition(unit);
        final oemProfiles = await OemModuleProfileService.forBrand(_detectedBrand, unit);
        final candidates = <String>{
          ...definition.typicalResponseIds,
          ...functionalResponders.where((id) => id.length == 3),
        }.toList(growable: false);
        DiagnosticUnitScanResult? result;

        for (final profile in oemProfiles.where((item) => item.protocol == OemModuleProtocol.canUds)) {
          result = await _scanCanUdsProfile(profile);
          if (result != null) break;
        }

        final wifiHost = _connection is WifiObdConnection
            ? (_connection as WifiObdConnection).host
            : null;
        if (result == null &&
            wifiHost != null &&
            oemProfiles.any((item) => item.protocol == OemModuleProtocol.doip)) {
          final doip = DoipDiagnosticClient();
          try {
            await doip.connect(wifiHost);
            for (final profile in oemProfiles.where((item) => item.protocol == OemModuleProtocol.doip)) {
              result = await _scanDoipProfile(profile, doip);
              if (result != null) break;
            }
          } catch (_) {
            // A normal ELM Wi‑Fi adapter is not a DoIP gateway; continue with CAN/OBD.
          } finally {
            await doip.disconnect();
          }
        }

        if (result == null) {
          for (final responseId in candidates) {
          final requestId = _requestIdForResponseId(responseId);
          if (requestId == null) continue;
          try {
            await _sendAndWait('ATSH$requestId');
            await _sendAndWait('ATCRA$responseId');
            await _sendAndWait('ATCAF1');
            final probe = await _sendAndWait('0100', timeout: const Duration(seconds: 5));
            if (_responsePayloads(probe, 0x41).isEmpty) continue;
            final codes = await _readModuleDtcCodes();
            result = DiagnosticUnitScanResult(
              unit: unit,
              discovered: true,
              demo: false,
              responseId: responseId,
              dtcs: codes,
              detail: codes.isEmpty ? tx('Yanıt alındı, kayıtlı DTC yok') : tx('{0} DTC bulundu', [codes.length]),
              scannedAt: DateTime.now(),
            );
            break;
          } catch (error) {
            result = DiagnosticUnitScanResult(
              unit: unit,
              discovered: false,
              demo: false,
              responseId: responseId,
              dtcs: const [],
              detail: tx('Sorgu hatası: {0}', [error]),
              scannedAt: DateTime.now(),
            );
          }
        }
        }

        _moduleScanResults[unit] = result ?? DiagnosticUnitScanResult(
          unit: unit,
          discovered: false,
          demo: false,
          responseId: null,
          dtcs: const [],
          detail: tx('Bu ünite standart OBD sorgusuna cevap vermedi'),
          scannedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (error) {
      final message = tx('Ünite taraması tamamlanamadı: {0}', [error]);
      _errorEventController.add(message);
      for (final unit in selected) {
        final existing = _moduleScanResults[unit];
        if (existing == null || !existing.discovered) {
          _moduleScanResults[unit] = DiagnosticUnitScanResult(
            unit: unit,
            discovered: false,
            demo: _isDemoMode,
            responseId: existing?.responseId,
            dtcs: existing?.dtcs ?? const [],
            detail: message,
            scannedAt: DateTime.now(),
          );
        }
      }
    } finally {
      if (!_isDemoMode) {
        try { await _sendAndWait('ATCRA'); } catch (_) {}
        try { await _sendAndWait('ATSH7DF'); } catch (_) {}
        try { await _sendAndWait('ATH0'); } catch (_) {}
      }
      _isModuleScanning = false;
      _exclusiveDiagnosticOperation = false;
      notifyListeners();
    }
  }

  /// Standalone DoIP scan for a Wi‑Fi gateway. It does not require an ELM327
  /// session because DoIP is a separate TCP protocol on port 13400.
  Future<void> scanSelectedUnitsViaDoip(
    Set<DiagnosticUnit> selected, {
    required String host,
    int port = DoipDiagnosticClient.defaultPort,
  }) async {
    if (_isModuleScanning || selected.isEmpty || host.trim().isEmpty) return;
    _isModuleScanning = true;
    _moduleScanResults
      ..clear()
      ..addEntries(selected.map((unit) => MapEntry(
            unit,
            DiagnosticUnitScanResult(
              unit: unit,
              discovered: false,
              demo: false,
              responseId: null,
              dtcs: const [],
              detail: tx('DoIP taraması bekleniyor'),
              protocol: 'DoIP / UDS',
              scannedAt: DateTime.now(),
            ),
          )));
    notifyListeners();

    final client = DoipDiagnosticClient();
    try {
      await client.connect(host.trim(), port: port);
      for (final unit in selected) {
        final profiles = await OemModuleProfileService.forBrand(_detectedBrand, unit);
        DiagnosticUnitScanResult? result;
        for (final profile in profiles.where((item) => item.protocol == OemModuleProtocol.doip)) {
          result = await _scanDoipProfile(profile, client);
          if (result != null) break;
        }
        _moduleScanResults[unit] = result ?? DiagnosticUnitScanResult(
          unit: unit,
          discovered: false,
          demo: false,
          responseId: null,
          dtcs: const [],
          detail: tx('Bu marka kataloğunda bu ünite için DoIP logical address doğrulanamadı'),
          protocol: 'DoIP / UDS',
          scannedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (error) {
      final message = tx('DoIP taraması başarısız: {0}', [error]);
      _errorEventController.add(message);
      for (final unit in selected) {
        _moduleScanResults[unit] = DiagnosticUnitScanResult(
          unit: unit,
          discovered: false,
          demo: false,
          responseId: null,
          dtcs: const [],
          detail: message,
          protocol: 'DoIP / UDS',
          scannedAt: DateTime.now(),
        );
      }
    } finally {
      await client.disconnect();
      _isModuleScanning = false;
      notifyListeners();
    }
  }

  List<String> _extractCanResponseIds(String raw) {
    final ids = <String>{};
    for (final rawLine in raw.replaceAll('>', '\n').replaceAll('\r', '\n').split('\n')) {
      final line = rawLine.trim().toUpperCase();
      if (line.isEmpty) continue;
      final spaced = RegExp(r'^([0-9A-F]{3}|[0-9A-F]{8})\s+').firstMatch(line);
      if (spaced != null) {
        ids.add(spaced.group(1)!);
        continue;
      }
      final compact = line.replaceAll(RegExp(r'[^0-9A-F]'), '');
      // Compact header-on CAN form: 7E8 + PCI/length + payload.
      if (compact.length > 5 && compact.length.isOdd && compact.substring(3).length.isEven) {
        ids.add(compact.substring(0, 3));
        continue;
      }
      // Common 29-bit functional/physical ISO-TP IDs.
      if (compact.length >= 12 && compact.length.isEven && compact.startsWith('18DA')) {
        ids.add(compact.substring(0, 8));
      }
    }
    return ids.toList()..sort();
  }

  Future<UdsIdentityItem> _readStandardUdsDid(int did, String label) async {
    final hex = did.toRadixString(16).padLeft(4, '0').toUpperCase();
    try {
      final raw = await _sendAndWait('22$hex', timeout: const Duration(seconds: 7));
      final negative = UdsDiagnostic.parseNegative(raw);
      if (negative != null) {
        return UdsIdentityItem(label: label, did: '0x$hex', value: '-', supported: false, error: negative.description);
      }
      final payload = UdsDiagnostic.readDidPayload(raw, did);
      if (payload == null || payload.isEmpty) return UdsIdentityItem(label: label, did: '0x$hex', value: '-', supported: false, error: tx('ECU bu DID için veri döndürmedi'));
      final text = UdsDiagnostic.ascii(payload);
      final value = text.isNotEmpty ? text : payload.map((e)=>e.toRadixString(16).padLeft(2,'0').toUpperCase()).join(' ');
      return UdsIdentityItem(label: label, did: '0x$hex', value: value, supported: true);
    } catch (_) {
      return UdsIdentityItem(label: label, did: '0x$hex', value: '-', supported: false, error: tx('Okuma zaman aşımı'));
    }
  }

  Future<void> _loadCompleteDemoDiagnostics() async {
    // Demo modu gerçek ECU olmadan bütün yeni teşhis ekranlarını gezebilmek içindir.
    // Buradaki değerlerin tamamı DEMO'dur ve gerçek araç teşhisi olarak kullanılmaz.
    _protocolName = 'ISO 15765-4 CAN (11 bit ID, 500 kbit/s)';
    _detectedVin = 'WVWZZZAUZFW000001';
    _detectedBrand = 'Volkswagen';
    _adapterInfo = ObdAdapterInfo(
      identity: 'ELM327 v2.3 • DEMO',
      description: tx('OTOSİNYAL sanal OBD adaptörü'),
      protocol: 'ISO 15765-4 CAN',
      voltage: 13.9,
    );
    _barometricKpa = 101;
    _milOn = true;
    _milDtcCount = 1;

    _supportedMode01Pids
      ..clear()
      ..addAll(const <int>{
        0x01,0x04,0x05,0x0B,0x0C,0x0D,0x0F,0x10,0x11,0x1F,0x21,0x23,
        0x2C,0x2D,0x33,0x3C,0x42,0x46,0x5C,0x5E,0x61,0x62,0x63,0x70,0x7A,
      });

    _throttlePositionPercent = 37;
    _egrCommandedPercent = 34;
    _egrErrorPercent = 2.4;
    _fuelRailPressureKpa = 86500;
    _fuelRateLph = 5.8;
    _ambientTempC = 24;
    _controlModuleVoltage = 14.1;
    _oilTempC = 96;
    _mafGps = 42.8;
    _engineLoadPercent = 67;
    _actualTorquePercent = 58;
    _driverDemandTorquePercent = 61;
    _referenceTorqueNm = 250;
    _runtimeSeconds = 1840;
    _distanceWithMilKm = 0;
    _catalystTempC = 438.0;

    _pid70CommandedSupported = true;
    _pid70ActualSupported = true;
    _commandedBoostAbsKpa = 235.0;
    _actualBoostAbsKpa = 231.0;
    _boostControlStatus = 2;

    _readiness = ObdReadinessStatus(
      completed: 7,
      supported: 8,
      incomplete: [tx('EVAP sistemi')],
    );
    _freezeFrame = const FreezeFrameSnapshot(
      triggerDtc: 'P0301',
      rpm: 2460,
      speedKmh: 74,
      coolantC: 91,
      loadPercent: 68,
      mapKpa: 154,
    );
    _mode06Raw = [
      tx('DEMO • O2 sensör monitörü: PASS'),
      tx('DEMO • Katalizör monitörü: PASS'),
      tx('DEMO • Misfire monitörü: sınır içinde'),
    ];

    _dtcEntries
      ..clear()
      ..addAll(const [
        DtcEntry('P0301', DtcStatus.stored),
        DtcEntry('P0420', DtcStatus.pending),
        DtcEntry('P0101', DtcStatus.permanent),
      ]);

    final catalog = await OemDiagnosticCatalog.summaryForBrand(_detectedBrand);
    _oemDiscovery = OemDiscoveryState(
      respondingCanIds: const ['7E8', '7E9'],
      identities: [
        UdsIdentityItem(label:'VIN (UDS)', did:'0xF190', value:'WVWZZZAUZFW000001', supported:true),
        UdsIdentityItem(label:tx('Parça numarası'), did:'0xF187', value:'04L 906 021 DEMO', supported:true),
        UdsIdentityItem(label:tx('Yazılım sürümü'), did:'0xF189', value:'9978-DEMO', supported:true),
        UdsIdentityItem(label:tx('ECU seri numarası'), did:'0xF18C', value:'EDC17-DEMO-0001', supported:true),
        UdsIdentityItem(label:tx('Donanım numarası'), did:'0xF191', value:'04L907309-DEMO', supported:true),
      ],
      catalogName: catalog?.displayName ?? 'VOLKSWAGEN / AUDI GROUP • DEMO',
      catalogEcuCount: catalog?.ecuCount ?? 0,
      catalogDidCount: catalog?.didCount ?? 0,
      verifiedDidCount: catalog?.verifiedDidCount ?? 0,
      catalogRoutineCount: catalog?.routineCount ?? 0,
      catalogExperimental: catalog != null && catalog.verifiedDidCount == 0,
    );
    _lastAdvancedRefresh = DateTime.now();
    _lastDtcCheck = DateTime.now();
    _lastFullScan = DateTime.now();
    notifyListeners();
  }

  Future<void> runOemDiscovery() async {
    if (!canQueryDtc || _isOemScanning) return;
    _isOemScanning = true;
    notifyListeners();
    try {
      if (_isDemoMode) {
        await _loadCompleteDemoDiagnostics();
        return;
      }
      // Universal engine-ECU discovery. Most CAN OBD/UDS vehicles expose the
      // powertrain ECU at 7E0/7E8. We explicitly route the UDS identification
      // requests instead of relying on ELM's previous/default header.
      await _sendAndWait('ATH1');
      final probe = await _sendAndWait('0100', timeout: const Duration(seconds: 8));
      final responders = _extractCanResponseIds(probe);
      DiagnosticFlightRecorder.instance.event('ECU_RESPONDER_DISCOVERY', raw: probe, data: {'responders': responders});

      final catalog = await OemDiagnosticCatalog.summaryForBrand(_detectedBrand);
      final identities = <UdsIdentityItem>[];
      try {
        await _sendAndWait('ATSH7E0');
        await _sendAndWait('ATCRA7E8');
        await _sendAndWait('ATCAF1');
        for (final item in <(int,String)>[
          (0xF190,'VIN (UDS)'),
          (0xF187,tx('Parça numarası')),
          (0xF189,tx('Yazılım sürümü')),
          (0xF191,tx('Donanım numarası')),
          (0xF18C,tx('ECU seri numarası')),
          (0xF19E,tx('ASAM/ODX veri seti')),
          (0xF1A2,tx('ASAM/ODX sürümü')),
          (0xF197,tx('ECU sistem adı')),
        ]) {
          final result = await _readStandardUdsDid(item.$1, item.$2);
          identities.add(result);
          DiagnosticFlightRecorder.instance.event('UDS_IDENTITY', data: {'did': result.did, 'label': result.label, 'supported': result.supported, 'value': result.value, 'error': result.error});
        }
      } finally {
        try { await _sendAndWait('ATCRA'); } catch (_) {}
        try { await _sendAndWait('ATSH7DF'); } catch (_) {}
        try { await _sendAndWait('ATH0'); } catch (_) {}
      }
      _oemDiscovery = OemDiscoveryState(
        respondingCanIds: responders,
        identities: identities,
        catalogName: catalog?.displayName,
        catalogEcuCount: catalog?.ecuCount ?? 0,
        catalogDidCount: catalog?.didCount ?? 0,
        verifiedDidCount: catalog?.verifiedDidCount ?? 0,
        catalogRoutineCount: catalog?.routineCount ?? 0,
        catalogExperimental: catalog != null && catalog.verifiedDidCount == 0,
      );
    } finally {
      if (!_isDemoMode) {
        try { await _sendAndWait('ATH0'); } catch (_) {}
      }
      _isOemScanning = false;
      notifyListeners();
    }
  }


  int get diagnosticLogEventCount => DiagnosticFlightRecorder.instance.eventCount;
  String? get diagnosticLogSessionId => DiagnosticFlightRecorder.instance.sessionId;
  Future<void> shareDiagnosticLog() => DiagnosticFlightRecorder.instance.share();

  Future<void> toggleRealMode() async {
    if (!_connection.isConnected || (_connection.isReconnecting && !_isRealMode)) {
      return;
    }

    if (_isRealMode) {
      stopRealData();
      return;
    }

    if (_isDemoMode) {
      _isDemoMode = false;
      _demoGenerator.stop();
      _data = const ObdData();
    }

    _detectedVin = null;
    _detectedBrand = null;
    _codingPreflight = null;
    _supportedMode01Pids.clear();
    _runtimeConfirmedPids.clear();
    _runtimeRejectedPids.clear();
    _runtimePidMisses.clear();
    _hasReliableMode01Bitmap = false;
    _pidDiscoveryComplete = false;
    _activeProtocolSelector = '0';
    _protocolName = null;

    final ok = await runHandshake();
    if (!ok) {
      state = ObdConnectionState.error;
      return;
    }

    _isRealMode = true;
    state = ObdConnectionState.ready;
    _sessionStart = DateTime.now();
    _sessionMaxSpeed = 0;
    _sessionMaxRpm = 0;
    _sessionMaxBoost = 0;
    _barometricKpa = null;
    _commandCount = 0;
    _commandTimeoutCount = 0;
    _commandErrorCount = 0;
    _commandLatencyTotalMs = 0;

    // VIN ve uzun ISO-TP mesajları bağlantının ön koşulu değildir.
    // Ucuz ELM327 klonları temel Mode 01 PID'lerini okuyabilirken VIN
    // (Mode 09 PID 02) veya uzun yanıtları desteklemeyebilir.
    // Canlı akışı VIN beklemeden başlat; kullanıcı VIN'i daha sonra
    // araç bilgilerinden isteğe bağlı olarak sorgulayabilir.
    unawaited(_startPollingLoop());
    unawaited(readMilStatus());
    unawaited(_readBarometricPressure());

    // Build 13'te bu iki arka plan işi tanımlı olduğu halde çağrılmıyordu.
    // Sonuç: destek bitmap'i boş kalıyor, UI "0 kanal" yazıyor ve VIN sadece
    // kullanıcı tam tarama başlatırsa deneniyordu. Canlı akışı bekletmeden geri aç.
    unawaited(_discoverStartupVehicleDataInBackground());
    notifyListeners();
  }

  Future<void> _discoverStartupVehicleDataInBackground() async {
    // Canlı RPM/hız önce otursun. PID discovery ile VIN aynı anda ayrı task
    // olarak çalışmıyor; aksi halde VIN'in özel CAN header'ı ile 01xx PID sorgusu
    // birbirine karışabiliyordu. Tek akış, tek komut zinciri.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!_isRealMode || !_connection.isConnected || _connection.isReconnecting) return;

    for (var i = 0; i < 8 && _exclusiveDiagnosticOperation; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!_isRealMode || !_connection.isConnected || _connection.isReconnecting) return;
    }

    if (!_exclusiveDiagnosticOperation) {
      try {
        await _readSupportedPids();
      } catch (error) {
        _pidDiscoveryComplete = true;
        developer.log('Arka plan PID keşfi tamamlanamadı: $error', name: 'ObdLogic');
      }
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!_isRealMode || !_connection.isConnected || _connection.isReconnecting ||
        _detectedVin != null) return;

    for (var i = 0; i < 10 && _exclusiveDiagnosticOperation; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!_isRealMode || !_connection.isConnected || _connection.isReconnecting ||
          _detectedVin != null) return;
    }

    if (_exclusiveDiagnosticOperation) return;
    try {
      await _detectVehicleBrand();
    } catch (error) {
      developer.log('Arka plan VIN keşfi tamamlanamadı: $error', name: 'ObdLogic');
    }
  }

  Future<void> _restoreGenericObdSession() async {
    if (!_isRealMode || !_connection.isConnected) return;
    // Özel UDS/VIN taramasından önce hangi protokol seçildiyse aynısını geri yükle.
    // Build 14'te her seferinde ATSP0'a dönmek, sabit ATSP6 ile bağlanan araçlarda
    // yeniden SEARCHING başlatıp canlı PID akışını bozabiliyordu.
    try { await _sendAndWait('ATFCSM0', timeout: const Duration(seconds: 2)); } catch (_) {}
    try { await _sendAndWait('ATCRA', timeout: const Duration(seconds: 2)); } catch (_) {}
    try { await _sendAndWait('ATCAF1', timeout: const Duration(seconds: 2)); } catch (_) {}
    try { await _sendAndWait('ATCFC1', timeout: const Duration(seconds: 2)); } catch (_) {}
    try { await _sendAndWait('ATSP$_activeProtocolSelector', timeout: const Duration(seconds: 4)); } catch (_) {}
    // Modern CAN'da 7DF genel OBD isteğidir. ISO/KWP/J1850 oturumlarında
    // CAN header komutu göndermeyerek önceki protokolün kendi header davranışını koru.
    if (const <String>{'6','7','8','9'}.contains(_activeProtocolSelector)) {
      try { await _sendAndWait('ATSH7DF', timeout: const Duration(seconds: 2)); } catch (_) {}
    }
    try { await _sendAndWait('ATH1', timeout: const Duration(seconds: 2)); } catch (_) {}
  }

  Future<bool> runHandshake() async {
    try {
      state = ObdConnectionState.initializing;
      _initMessage = tx('ELM327 hazırlanıyor');
      notifyListeners();

      final atz = await _sendAndWait(
        'ATZ',
        timeout: const Duration(seconds: 7),
      );
      if (state == ObdConnectionState.disconnected) return false;
      if (_isNoData(atz) || atz.contains('?')) {
        _initMessage = tx('ELM327 yanıt vermiyor');
        notifyListeners();
        return false;
      }

      // ATZ ELM işlemcisini yeniden başlatır; özellikle BLE seri köprülerde hemen
      // arkasından komut gönderilirse ilk komut kaybolabiliyor.
      await Future<void>.delayed(const Duration(milliseconds: 900));

      // Adaptörü temiz, sessiz ve otomatik zamanlamalı moda al. Bazı ucuz
      // klonlar bütün AT komutlarını eksiksiz desteklemez; yalnız '?' dönen
      // kritik olmayan ayarlarda oturumu hemen öldürmeyiz.
      // Bağlantı başlangıcını olabildiğince küçük tut. Ucuz ELM327 klonları
      // ATAL/CAF/CFC gibi uzun mesaj ayarlarını desteklemese bile Mode 01
      // canlı verileri sorunsuz okuyabilir.
      // Header'ları açık tutuyoruz. OBDium da ECU kimliğini ve ISO-TP
      // frame sınırlarını korumak için ATH1 ile çalışıyor. Parser hem header'lı
      // hem headersız cevabı destekliyor.
      for (final command in ['ATE0', 'ATL0', 'ATS0', 'ATH1']) {
        final response = await _sendAndWait(command);
        if (state == ObdConnectionState.disconnected) return false;
        if (response.toUpperCase().contains('?')) {
          developer.log('$command adaptör tarafından desteklenmedi', name: 'ObdLogic');
        }
      }

      // Önce ELM'nin otomatik protokol aramasını kullan.
      await _sendAndWait('ATSP0');
      _activeProtocolSelector = '0';
      _initMessage = tx('Araç ECU\'su aranıyor • Otomatik protokol');
      notifyListeners();
      var probe = await _probeEcu(timeout: const Duration(seconds: 20));

      // Bazı ELM327 klonlarında ATSP0/SEARCHING bozuk çalışıyor. Bluetooth
      // bağlantısı ve ELM kanalı sağlam olduğu halde false-negative vermemek için
      // standart OBD-II protokollerini gerçek 41 00 cevabıyla tek tek doğrula.
      // Modern CAN araçlar için 6 ilk sırada; ardından diğer CAN ve eski ISO/KWP/J1850.
      if (!_hasAnyMode01Response(probe)) {
        const fallbacks = <({String code, String label})>[
          (code: '6', label: 'CAN 11/500'),
          (code: '7', label: 'CAN 29/500'),
          (code: '8', label: 'CAN 11/250'),
          (code: '9', label: 'CAN 29/250'),
          (code: '5', label: 'KWP Fast'),
          (code: '4', label: 'KWP 5 baud'),
          (code: '3', label: 'ISO 9141-2'),
          (code: '2', label: 'J1850 VPW'),
          (code: '1', label: 'J1850 PWM'),
        ];

        for (final candidate in fallbacks) {
          if (state == ObdConnectionState.disconnected) return false;
          _initMessage = tx('Araç ECU\'su aranıyor • {0}', [candidate.label]);
          notifyListeners();

          final sp = await _sendAndWait('ATSP${candidate.code}');
          if (sp.toUpperCase().contains('?')) continue;
          await Future<void>.delayed(const Duration(milliseconds: 350));
          final candidateProbe = await _probeEcu(timeout: const Duration(seconds: 10));
          if (_hasAnyMode01Response(candidateProbe)) {
            _activeProtocolSelector = candidate.code;
            probe = candidateProbe;
            break;
          }
          probe = candidateProbe;
        }
      }

      if (!_hasAnyMode01Response(probe)) {
        _initMessage = _humanConnectionFailure(probe);
        notifyListeners();
        return false;
      }

      if (_adapterProfile?.supportedMode01Pids.isNotEmpty == true) {
        _supportedMode01Pids
          ..clear()
          ..addAll(_adapterProfile!.supportedMode01Pids);
      }
      final protocolNumberRaw = await _sendAndWait('ATDPN', timeout: const Duration(seconds: 3));
      final protocolNumber = _normalize(protocolNumberRaw, echoCommand: 'ATDPN').split('\n').first.trim();
      // ATDPN otomatik seçimde `A6`, sabit seçimde `6` gibi döner. VIN/UDS
      // taramasından sonra ATSP0 ile yeniden SEARCHING başlatmak yerine seçilmiş
      // gerçek protokole geri dön.
      final protocolMatch = RegExp(r'([1-9])$').firstMatch(protocolNumber);
      if (protocolMatch != null) _activeProtocolSelector = protocolMatch.group(1)!;
      if (_transportId.isNotEmpty && protocolNumber.isNotEmpty && !protocolNumber.contains('?')) {
        final profile = (_adapterProfile ?? ElmAdapterProfile(transportId: _transportId))
            .copyWith(protocolNumber: protocolNumber);
        _adapterProfile = profile;
        unawaited(ElmAdapterProfileService.save(profile));
      }
      final protocol = await _sendAndWait('ATDP');
      final normalizedProtocol = _normalize(protocol, echoCommand: 'ATDP');
      if (normalizedProtocol.isNotEmpty && !_isNoData(normalizedProtocol)) {
        _protocolName = normalizedProtocol.split('\n').first;
      }

      await _readAdapterInfo();
      _initMessage = tx('ECU bağlantısı hazır');
      notifyListeners();
      return true;
    } catch (e) {
      developer.log('Handshake hatası: $e', name: 'ObdLogic');
      _initMessage = tx('ECU başlatılamadı');
      notifyListeners();
      return false;
    }
  }

  bool _containsMode01PidResponse(String raw, int pid) {
    for (final payload in _responsePayloads(raw, 0x41)) {
      if (payload.isNotEmpty && payload.first == pid) return true;
    }
    return false;
  }

  bool _hasAnyMode01Response(String raw) {
    return _responsePayloads(raw, 0x41).isNotEmpty;
  }

  Future<String> _probeEcu({Duration timeout = const Duration(seconds: 12)}) async {
    var response = await _sendDiagnosticWithRetry('0100', timeout: timeout);
    if (_containsMode01PidResponse(response, 0x00) || _hasAnyMode01Response(response)) {
      return response;
    }

    // Bazı klon ELM/ECU kombinasyonları 0100 cevabını parçalı ya da garip
    // biçimde geçirirken basit canlı PID'ye düzgün cevap verebiliyor.
    final rpmProbe = await _sendDiagnosticWithRetry('010C', timeout: timeout);
    if (_containsMode01PidResponse(rpmProbe, 0x0C) || _hasAnyMode01Response(rpmProbe)) {
      return rpmProbe;
    }
    return response.isNotEmpty ? response : rpmProbe;
  }

  String _humanConnectionFailure(String raw) {
    final upper = raw.toUpperCase();
    final normalized = _normalize(raw).replaceAll('\n', ' | ').trim();
    final detail = normalized.length > 70 ? '${normalized.substring(0, 70)}…' : normalized;
    if (upper.contains('UNABLE TO CONNECT')) return tx('Araç ECU’suna bağlanılamadı');
    if (upper.contains('BUS INIT')) return tx('Araç haberleşmesi başlatılamadı');
    if (upper.contains('CAN ERROR') || upper.contains('BUS ERROR')) return tx('Araç veri hattından yanıt alınamadı');
    if (upper.contains('NO DATA')) return tx('Araç ECU’sundan veri alınamadı');
    if (detail.isNotEmpty) developer.log('Tanınmayan ECU cevabı: $detail', name: 'ObdLogic');
    return tx('Araç ECU’suyla iletişim kurulamadı');
  }

  Future<void> _readSupportedPids() async {
    // Birden fazla ECU aynı bitmap sorgusuna cevap verebilir. Bütün cevapları
    // OR'layarak gerçek destek kümesini çıkar. Önceki adaptör profili yalnızca
    // fallback olarak tutulur; canlı sorgu başarılıysa güncel sonuç esas alınır.
    final cached = Set<int>.from(_supportedMode01Pids);
    final discovered = <int>{};
    _runtimeRejectedPids.clear();
    _runtimePidMisses.clear();
    var basePid = 0x00;
    var gotBitmap = false;
    _hasReliableMode01Bitmap = false;

    for (var block = 0; block < 8; block++) {
      final cmd = '01${basePid.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      final response = await _sendDiagnosticWithRetry(
        cmd,
        timeout: const Duration(seconds: 5),
        retries: 2,
      );
      final payloads = _responsePayloads(response, 0x41)
          .where((p) => p.length >= 5 && p[0] == basePid)
          .toList(growable: false);
      if (payloads.isEmpty) break;

      gotBitmap = true;
      var mergedBitmap = 0;
      for (final payload in payloads) {
        var bitmap = 0;
        for (final b in payload.sublist(1, 5)) {
          bitmap = (bitmap << 8) | b;
        }
        mergedBitmap |= bitmap;
      }

      for (var bit = 0; bit < 32; bit++) {
        if ((mergedBitmap & (1 << (31 - bit))) != 0) {
          final pid = basePid + bit + 1;
          // 20/40/60/... yalnız sonraki destek-bitmap bloğunun varlığını söyler;
          // gerçek canlı sensör değildir ve UI sensör sayısına girmemelidir.
          if (pid % 0x20 != 0) discovered.add(pid);
        }
      }

      if ((mergedBitmap & 0x00000001) == 0) break;
      basePid += 0x20;
      if (basePid > 0xE0) break;
    }

    _hasReliableMode01Bitmap = gotBitmap;
    _supportedMode01Pids
      ..clear()
      ..addAll(gotBitmap ? discovered : cached.where((pid) => pid % 0x20 != 0));

    // Bazı ELM klonları 0100 bitmap cevabını bozarken tekil PID'leri düzgün
    // döndürür. Yalnız bitmap hiç alınamadıysa temel canlı PID'leri doğrula;
    // bitmap sağlamsa ECU'nun "unsupported" bitlerine saygı duyup kuyruğu şişirme.
    if (!gotBitmap) {
      const corePids = <int>[0x0C, 0x0D, 0x05, 0x0B, 0x10, 0x23, 0x42, 0x5C];
      for (final pid in corePids) {
        try {
          await _queryPidPayload(
            pid,
            timeout: const Duration(milliseconds: 1100),
            forceProbe: true,
          );
        } catch (_) {}
      }
    }

    // Runtime doğrulaması bitmap'ten daha güvenilir kanıttır.
    _supportedMode01Pids.addAll(_runtimeConfirmedPids);

    if (_transportId.isNotEmpty && _supportedMode01Pids.isNotEmpty) {
      final profile = (_adapterProfile ?? ElmAdapterProfile(transportId: _transportId))
          .copyWith(supportedMode01Pids: _supportedMode01Pids.toList()..sort());
      _adapterProfile = profile;
      unawaited(ElmAdapterProfileService.save(profile));
    }
    _pidDiscoveryComplete = true;
    notifyListeners();
  }

  bool _ecuRecoveryInProgress = false;

  Future<void> _recoverEcuConnection() async {
    // Aynı bağlantı olayı birkaç kez gelirse paralel AT komutları üretme.
    // Yazma, kodlama, adaptasyon ve DTC silme sırasında otomatik
    // handshake başlatma; işlem kullanıcı tarafından yeniden başlatılmalı.
    if (_ecuRecoveryInProgress || !_isRealMode ||
        _exclusiveDiagnosticOperation || _isClearingCodes) return;
    _ecuRecoveryInProgress = true;
    try {
      state = ObdConnectionState.initializing;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!_isRealMode || !_connection.isConnected ||
          _exclusiveDiagnosticOperation || _isClearingCodes) return;
      final ok = await runHandshake();
      if (!_isRealMode) return;
      if (ok) {
        state = ObdConnectionState.ready;
      } else {
        stopWithError(tx('Araç bağlantısı yeniden kurulamadı. Tekrar bağlanın.'));
      }
    } finally {
      _ecuRecoveryInProgress = false;
    }
  }

  Future<void> _startPollingLoop() async {
    while (_isRealMode) {
      if (_exclusiveDiagnosticOperation) {
        await Future<void>.delayed(const Duration(milliseconds: 45));
        continue;
      }
      if (_connection.isReconnecting || state == ObdConnectionState.initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        continue;
      }
      if (!_connection.isConnected) break;

      var batch = _data;

      // Fast lane: RPM + speed are requested every cycle. Do not gate these on
      // the ECU support bitmap; some clone adapters expose a broken 0100 bitmap.
      batch = _parsePidResponse(await _sendAndWait('010C', timeout: const Duration(milliseconds: 1200)), batch);
      if (!_isRealMode || !_connection.isConnected) return;
      if (_exclusiveDiagnosticOperation) continue;
      batch = _parsePidResponse(await _sendAndWait('010D', timeout: const Duration(milliseconds: 1200)), batch);
      if (!_isRealMode || !_connection.isConnected) return;
      if (_exclusiveDiagnosticOperation) continue;

      // Publish RPM/speed now; slow sensors must never make the needles feel late.
      _data = batch;
      notifyListeners();

      _slowPollTick++;
      // Medium lane: temperature + MAP every fourth fast cycle.
      if (_slowPollTick % 4 == 0) {
        batch = _parsePidResponse(await _sendAndWait('0105', timeout: const Duration(milliseconds: 1200)), batch);
        if (_exclusiveDiagnosticOperation) continue;
        batch = _parsePidResponse(await _sendAndWait('010B', timeout: const Duration(milliseconds: 1200)), batch);
      }

      // Adapter voltage changes slowly; don't waste one ELM round-trip per frame.
      if (_slowPollTick % 18 == 0) {
        batch = _parsePidResponse(await _sendAndWait('ATRV', timeout: const Duration(milliseconds: 1000)), batch);
      }

      // Slow lane: one optional PID per loop. Güvenilir destek bitmap'i varken
      // unsupported PID hiç kuyruğa girmez; bu yüzden ek canlı sensörleri 5 kat daha
      // hızlı dolaştırabiliriz. RPM/hız yine her döngünün başında önceliklidir.
      if (_pidDiscoveryComplete && _advancedPollPids.isNotEmpty) {
        final pid = _advancedPollPids[_advancedPollIndex % _advancedPollPids.length];
        _advancedPollIndex = (_advancedPollIndex + 1) % _advancedPollPids.length;
        await _readAdvancedPidOnce(pid);
        if (pid == 0x42 && _controlModuleVoltage != null) {
          batch = batch.copyWith(voltage: _controlModuleVoltage);
        }
      }

      if (_slowPollTick % 24 == 0) {
        await _readBoostPressureControl();
      }

      if (batch.speed > _sessionMaxSpeed) _sessionMaxSpeed = batch.speed;
      if (batch.rpm > _sessionMaxRpm) _sessionMaxRpm = batch.rpm;
      if ((batch.boostKpa ?? 0) > _sessionMaxBoost) _sessionMaxBoost = batch.boostKpa ?? 0;
      _data = batch;
      _lastAdvancedRefresh = DateTime.now();
      notifyListeners();

      // Small yield only; real cadence is governed by ELM round-trip latency.
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }
    if (_isRealMode) stopRealData();
  }

  Future<void> _readBarometricPressure() async {
    if (_isDemoMode) {
      _barometricKpa = 101;
      notifyListeners();
      return;
    }
    final p = await _queryPidPayload(0x33, forceProbe: true);
    if (p != null && p.length >= 2) {
      _barometricKpa = p[1];
      notifyListeners();
    }
  }

  Future<void> readMilStatus() async {
    if (!canQueryDtc) return;
    if (_isDemoMode) {
      _milOn = true;
      _milDtcCount = 1;
      notifyListeners();
      return;
    }
    final response = await _sendDiagnosticWithRetry('0101');
    for (final p in _responsePayloads(response, 0x41)) {
      if (p.length >= 2 && p[0] == 0x01) {
        _milOn = (p[1] & 0x80) != 0;
        _milDtcCount = p[1] & 0x7F;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> _detectVehicleBrand() async {
    if (_isDemoMode) {
      _detectedVin = 'WVWZZZAUZFW000001';
      _detectedBrand = 'Volkswagen';
      final handler = onVehicleDetected;
      if (handler != null) await handler(_detectedVin!, _detectedBrand);
      notifyListeners();
      return;
    }

    final ownsExclusiveMode = !_exclusiveDiagnosticOperation;
    if (ownsExclusiveMode) await _acquireExclusiveDiagnosticOperation();
    try {
      _initMessage = tx('VIN aranıyor • Mode 09 araç kimliği okunuyor');
      notifyListeners();

      var vin = await _readVinViaMode09();
      if (vin.length != 17) {
        _initMessage = tx('VIN aranıyor • UDS F190 kontrol üniteleri taranıyor');
        notifyListeners();
        vin = await _readVinViaGenericUds();
      }

      if (VinDecoder.isValidVin(vin)) {
        _detectedVin = vin;
        _detectedBrand = VinDecoder.guessBrand(vin);
        _initMessage = tx('VIN bulundu • Araç profili hazırlanıyor');
        final handler = onVehicleDetected;
        if (handler != null) await handler(vin, _detectedBrand);
        notifyListeners();
      } else {
        _initMessage = tx('VIN okunamadı • Genel ECU verileri kullanılabilir');
        notifyListeners();
      }
    } catch (error) {
      developer.log('VIN keşfi başarısız: $error', name: 'ObdLogic');
      _initMessage = tx('VIN okunamadı • Genel ECU verileri kullanılabilir');
      notifyListeners();
    } finally {
      // VIN taraması header/CAF/filter ayarlarını değiştirir. Aynı canlı veri
      // oturumunun devam edebilmesi için önceki protokolü eksiksiz geri yükle.
      await _restoreGenericObdSession();
      if (ownsExclusiveMode) _releaseExclusiveDiagnosticOperation();
    }
  }

  Future<String> _readVinViaMode09() async {
    // Daha önce transient NO DATA yüzünden profile `false` yazılmış olsa bile
    // yeni araç oturumunda 0902'yi tekrar dene. Negatif cache VIN'i kalıcı
    // olarak kapatmamalı.
    const strategies = <List<String>>[
      <String>['ATH1', 'ATCAF1', 'ATCFC1'],
      <String>['ATH0', 'ATCAF1', 'ATCFC1'],
      // OBDium'un raw ISO-TP okuma mantığına denk fallback: frame sınırlarını
      // header ile koru, CAN auto-formatting'i kapat, flow-control açık kalsın.
      <String>['ATH1', 'ATCAF0', 'ATCFC1'],
    ];

    String lastRaw = '';
    for (var attempt = 0; attempt < strategies.length; attempt++) {
      if (!_connection.isConnected || _connection.isReconnecting) return '';
      for (final cmd in strategies[attempt]) {
        try { await _sendAndWait(cmd, timeout: const Duration(seconds: 2)); } catch (_) {}
      }
      try { await _sendAndWait('ATAL', timeout: const Duration(seconds: 2)); } catch (_) {}

      lastRaw = await _sendDiagnosticWithRetry(
        '0902',
        timeout: const Duration(seconds: 7),
        retries: 1,
      );
      DiagnosticFlightRecorder.instance.event(
        'VIN_MODE09',
        command: '0902',
        raw: lastRaw,
        data: <String, Object?>{'strategy': attempt + 1},
      );
      final vin = VinDecoder.extractVin(lastRaw);
      if (VinDecoder.isValidVin(vin)) {
        if (_transportId.isNotEmpty) {
          final profile = (_adapterProfile ?? ElmAdapterProfile(transportId: _transportId))
              .copyWith(vinMode09Supported: true, longMessagesSupported: true);
          _adapterProfile = profile;
          unawaited(ElmAdapterProfileService.save(profile));
        }
        return vin;
      }
    }

    // Sadece başarısızlığı logla; profile false kaydetme. NO DATA bazen araç
    // kontağı, ECU uykusu veya eksik BLE parçası gibi geçici bir durumdur.
    developer.log(
      'Mode 09 VIN alınamadı: ${_normalize(lastRaw, echoCommand: '0902').replaceAll('\n', ' | ')}',
      name: 'ObdLogic',
    );
    return '';
  }

  /// Marka/model sabitlemeden yaygın ISO-15765 CAN adres çiftlerini yoklar.
  /// VAG MQB gateway (710/77A) ve motor ECU (7E0/7E8) ilk sıradadır.
  Future<String> _readVinViaGenericUds() async {
    const pairs = <({String request, String response})>[
      (request: '710', response: '77A'), // VAG CAN Gateway
      (request: '7E0', response: '7E8'), // Engine ECU
      (request: '714', response: '77E'), // VAG instrument cluster (fallback)
      (request: '7E1', response: '7E9'),
      (request: '7E2', response: '7EA'),
      (request: '7E3', response: '7EB'),
      (request: '7E4', response: '7EC'),
      (request: '7E5', response: '7ED'),
      (request: '7E6', response: '7EE'),
      (request: '7E7', response: '7EF'),
    ];

    var longMessageWorked = false;
    try {
      for (final cmd in const ['ATH1', 'ATAL', 'ATCAF1', 'ATCFC1']) {
        try { await _sendAndWait(cmd, timeout: const Duration(seconds: 2)); } catch (_) {}
      }

      for (final pair in pairs) {
        if (!_connection.isConnected || _connection.isReconnecting) break;
        try {
          await _sendAndWait('ATSH${pair.request}', timeout: const Duration(seconds: 2));
          await _sendAndWait('ATCRA${pair.response}', timeout: const Duration(seconds: 2));
        } catch (_) {
          continue;
        }

        Future<String> readF190({int retries = 1}) => _sendDiagnosticWithRetry(
              '22F190',
              timeout: const Duration(seconds: 8),
              retries: retries,
            );

        // 1) CAF1 + automatic flow control.
        var raw = await readF190();
        var candidate = VinDecoder.extractVinFromUds(raw);
        DiagnosticFlightRecorder.instance.event('VIN_UDS_F190', command: '22F190', raw: raw,
            data: <String, Object?>{'request': pair.request, 'response': pair.response, 'mode': 'CAF1'});

        // 2) Raw ISO-TP frame fallback. Parser sequence numaralarını doğrular.
        if (!VinDecoder.isValidVin(candidate)) {
          try {
            await _sendAndWait('ATH1', timeout: const Duration(seconds: 2));
            await _sendAndWait('ATCAF0', timeout: const Duration(seconds: 2));
            await _sendAndWait('ATCFC1', timeout: const Duration(seconds: 2));
            raw = await readF190();
            candidate = VinDecoder.extractVinFromUds(raw);
            DiagnosticFlightRecorder.instance.event('VIN_UDS_F190', command: '22F190', raw: raw,
                data: <String, Object?>{'request': pair.request, 'response': pair.response, 'mode': 'CAF0'});
          } catch (_) {}
          try { await _sendAndWait('ATCAF1', timeout: const Duration(seconds: 2)); } catch (_) {}
        }

        // 3) ELM clone otomatik FC yapamıyorsa explicit flow-control.
        if (!VinDecoder.isValidVin(candidate)) {
          try {
            await _sendAndWait('ATH1', timeout: const Duration(seconds: 2));
            await _sendAndWait('ATCAF0', timeout: const Duration(seconds: 2));
            await _sendAndWait('ATFCSH${pair.request}', timeout: const Duration(seconds: 2));
            await _sendAndWait('ATFCSD300000', timeout: const Duration(seconds: 2));
            await _sendAndWait('ATFCSM1', timeout: const Duration(seconds: 2));
            raw = await readF190();
            candidate = VinDecoder.extractVinFromUds(raw);
          } catch (_) {} finally {
            try { await _sendAndWait('ATFCSM0', timeout: const Duration(seconds: 2)); } catch (_) {}
            try { await _sendAndWait('ATCAF1', timeout: const Duration(seconds: 2)); } catch (_) {}
          }
        }

        // 4) ECU F190'ı yalnız extended diagnostic session'da açıyorsa.
        if (!VinDecoder.isValidVin(candidate)) {
          try {
            await _sendAndWait('1003', timeout: const Duration(seconds: 4));
            raw = await readF190();
            candidate = VinDecoder.extractVinFromUds(raw);
          } catch (_) {
          } finally {
            try { await _sendAndWait('1001', timeout: const Duration(seconds: 3)); } catch (_) {}
          }
        }

        if (VinDecoder.isValidVin(candidate)) {
          longMessageWorked = true;
          if (_transportId.isNotEmpty) {
            final profile = (_adapterProfile ?? ElmAdapterProfile(transportId: _transportId))
                .copyWith(longMessagesSupported: true);
            _adapterProfile = profile;
            unawaited(ElmAdapterProfileService.save(profile));
          }
          return candidate;
        }
      }
    } catch (error) {
      developer.log('Genel UDS VIN taraması başarısız: $error', name: 'ObdLogic');
    } finally {
      try { await _sendAndWait('ATFCSM0', timeout: const Duration(seconds: 2)); } catch (_) {}
      try { await _sendAndWait('ATCAF1', timeout: const Duration(seconds: 2)); } catch (_) {}
      if (_transportId.isNotEmpty && !longMessageWorked && _adapterProfile?.longMessagesSupported == null) {
        // Sadece bilgi amaçlı; bu değer VIN taramasını sonraki oturumda engellemez.
        final profile = (_adapterProfile ?? ElmAdapterProfile(transportId: _transportId))
            .copyWith(longMessagesSupported: false);
        _adapterProfile = profile;
        unawaited(ElmAdapterProfileService.save(profile));
      }
    }
    return '';
  }

  Future<void> readTroubleCodes() async {
    if (!canQueryDtc) {
      _dtcError = tx('Önce OBD adaptörüne bağlanıp ECU oturumunu başlatın');
      notifyListeners();
      return;
    }

    _isReadingCodes = true;
    _dtcError = null;
    notifyListeners();

    try {
      _dtcEntries.clear();
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        _dtcEntries.addAll(const [
          DtcEntry('P0301', DtcStatus.stored),
          DtcEntry('P0420', DtcStatus.pending),
          DtcEntry('P0101', DtcStatus.permanent),
        ]);
      } else {
        await _appendDtcMode('03', 0x43, DtcStatus.stored);
        await _appendDtcMode('07', 0x47, DtcStatus.pending);
        await _appendDtcMode('0A', 0x4A, DtcStatus.permanent);
        await readMilStatus();
      }
      if (_dtcEntries.isNotEmpty) {
        try { await readFreezeFrame(); } catch (_) {}
      } else {
        _freezeFrame = const FreezeFrameSnapshot();
      }
      _lastDtcCheck = DateTime.now();
      if (onDtcScan != null) {
        onDtcScan!(DtcScanRecord(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          vehicleId: getActiveVehicleId?.call(),
          scannedAt: _lastDtcCheck!,
          stored: _dtcEntries.where((e) => e.status == DtcStatus.stored).map((e) => e.code).toList(),
          pending: _dtcEntries.where((e) => e.status == DtcStatus.pending).map((e) => e.code).toList(),
          permanent: _dtcEntries.where((e) => e.status == DtcStatus.permanent).map((e) => e.code).toList(),
          milOn: _milOn,
        ));
      }
    } catch (e) {
      developer.log('DTC okuma hatası: $e', name: 'ObdLogic');
      _dtcError = tx('Arıza kodları okunamadı');
    } finally {
      _isReadingCodes = false;
      notifyListeners();
    }
  }

  Future<void> _appendDtcMode(
    String command,
    int responseService,
    DtcStatus status,
  ) async {
    final response = await _sendDiagnosticWithRetry(command, timeout: const Duration(seconds: 6));
    if (_isNoData(response)) return;
    final codes = _parseTroubleCodes(response, responseService);
    for (final code in codes) {
      if (!_dtcEntries.any((e) => e.code == code && e.status == status)) {
        _dtcEntries.add(DtcEntry(code, status));
      }
    }
  }

  Future<bool> clearTroubleCodes() async {
    if (!canQueryDtc) {
      _dtcError = tx('Önce araç seçip ECU bağlantısını başlatın');
      notifyListeners();
      return false;
    }

    _isClearingCodes = true;
    _dtcError = null;
    notifyListeners();

    if (!_isDemoMode) await _acquireExclusiveDiagnosticOperation();
    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        _dtcEntries.removeWhere((e) => e.status != DtcStatus.permanent);
        _lastDtcCheck = DateTime.now();
        return true;
      }

      final response = await _sendAndWait('04');
      final normalized = _normalize(response, echoCommand: '04');
      // Bazı ELM/ECU kombinasyonları Mode 04 sonrası 44/OK yerine STOPPED,
      // NO DATA ya da boş prompt döndürebilir. ACK tek başına başarı sayılmaz;
      // aşağıda ECU tekrar taranarak gerçek sonuç doğrulanır.
      final upper = normalized.toUpperCase();
      final plausibleAck = upper.contains('44') ||
          upper.contains('OK') ||
          upper.contains('STOPPED') ||
          upper.contains('NO DATA') ||
          normalized.trim().isEmpty;
      if (!plausibleAck && upper.contains('ERROR')) {
        _dtcError = tx('ELM/ECU Mode 04 komutunu reddetti');
        return false;
      }

      // ECU'nun monitörleri sıfırlaması için kısa süre verip GERÇEKTEN tekrar tara.
      await Future.delayed(const Duration(seconds: 2));
      _dtcEntries.clear();
      await _appendDtcMode('03', 0x43, DtcStatus.stored);
      await _appendDtcMode('07', 0x47, DtcStatus.pending);
      await _appendDtcMode('0A', 0x4A, DtcStatus.permanent);
      await readMilStatus();
      _lastDtcCheck = DateTime.now();

      final stillStored = _dtcEntries.any((e) => e.status == DtcStatus.stored);
      if (stillStored) {
        _dtcError = tx('Bazı kayıtlı arızalar ECU tarafından silinmedi veya hemen geri döndü');
        return false;
      }
      return true;
    } catch (e) {
      developer.log('DTC temizleme hatası: $e', name: 'ObdLogic');
      _dtcError = tx('Temizleme sırasında iletişim hatası oluştu');
      return false;
    } finally {
      if (!_isDemoMode) _releaseExclusiveDiagnosticOperation();
      _isClearingCodes = false;
      notifyListeners();
    }
  }

  List<String> _parseTroubleCodes(String raw, int responseService) {
    final result = <String>{};
    for (final payload in _responsePayloads(raw, responseService)) {
      // DTC cevabında service byte'tan sonraki baytlar ikişerli kodlardır.
      for (var i = 0; i + 1 < payload.length; i += 2) {
        final code = _decodeDtcBytes(payload[i], payload[i + 1]);
        if (code != null) result.add(code);
      }
    }
    return result.toList(growable: false);
  }

  String? _decodeDtcBytes(int byte1, int byte2) {
    if (byte1 == 0 && byte2 == 0) return null;
    const letters = ['P', 'C', 'B', 'U'];
    final letter = letters[(byte1 >> 6) & 0x03];
    final digit1 = (byte1 >> 4) & 0x03;
    final digit2 = (byte1 & 0x0F).toRadixString(16).toUpperCase();
    final digit3 = ((byte2 >> 4) & 0x0F).toRadixString(16).toUpperCase();
    final digit4 = (byte2 & 0x0F).toRadixString(16).toUpperCase();
    return '$letter$digit1$digit2$digit3$digit4';
  }

  Future<void> toggleDemoMode() async {
    if (_isRealMode) return;
    if (_isDemoMode) {
      _isDemoMode = false;
      _demoGenerator.stop();
      _data = const ObdData();
      _dtcEntries.clear();
      _supportedMode01Pids.clear();
      _runtimeConfirmedPids.clear();
      _runtimeRejectedPids.clear();
      _discoveredSignals.clear();
      _supportedVagLiveDids.clear();
      _lastLiveSignalDiscovery = null;
      _detectedVin = null;
      _detectedBrand = null;
      _protocolName = null;
      _adapterInfo = const ObdAdapterInfo();
      _readiness = const ObdReadinessStatus();
      _freezeFrame = const FreezeFrameSnapshot();
      _mode06Raw = const [];
      _oemDiscovery = const OemDiscoveryState();
      _moduleScanResults.clear();
      _commandedBoostAbsKpa = null;
      _actualBoostAbsKpa = null;
      _pid70CommandedSupported = false;
      _pid70ActualSupported = false;
      _boostControlStatus = null;
      _lastFullScan = null;
      notifyListeners();
      return;
    }

    _isDemoMode = true;
    await _loadCompleteDemoDiagnostics();
    _demoGenerator.start((newData) {
      _data = newData;
      // Demo canlı verisi akarken ECU hedef/gerçek, OEM, DTC ve tarama verileri korunur.
      notifyListeners();
    });
    notifyListeners();
  }

  void stopRealData() {
    if (!_isRealMode && state == ObdConnectionState.disconnected) return;
    _isRealMode = false;
    if (_commandCompleter?.isCompleted == false) {
      _commandCompleter?.complete('');
    }
    _saveSessionAsTrip();
    _data = const ObdData();
    _discoveredSignals.clear();
    _supportedVagLiveDids.clear();
    _lastLiveSignalDiscovery = null;
    _milOn = null;
    _milDtcCount = null;
    _barometricKpa = null;
    _throttlePositionPercent = null;
    _egrCommandedPercent = null;
    _egrErrorPercent = null;
    _fuelRailPressureKpa = null;
    _fuelRateLph = null;
    _ambientTempC = null;
    _controlModuleVoltage = null;
    _oilTempC = null;
    _mafGps = null;
    _engineLoadPercent = null;
    _actualTorquePercent = null;
    _driverDemandTorquePercent = null;
    _referenceTorqueNm = null;
    _runtimeSeconds = null;
    _distanceWithMilKm = null;
    _catalystTempC = null;
    _lastAdvancedRefresh = null;
    _readiness = const ObdReadinessStatus();
    _freezeFrame = const FreezeFrameSnapshot();
    _oemDiscovery = const OemDiscoveryState();
    _mode06Raw = const [];
    _moduleScanResults.clear();
    _codingPreflight = null;
    _exclusiveDiagnosticOperation = false;
    state = ObdConnectionState.disconnected;
    notifyListeners();
  }

  void _saveSessionAsTrip() {
    final start = _sessionStart;
    if (start == null) return;
    final duration = DateTime.now().difference(start).inSeconds;
    _sessionStart = null;
    if (duration < 10 || onTripEnd == null) return;

    onTripEnd!(
      TripLog(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        vehicleId: getActiveVehicleId?.call(),
        startTime: start,
        durationSeconds: duration,
        maxSpeed: _sessionMaxSpeed,
        maxRpm: _sessionMaxRpm,
        maxBoostKpa: _sessionMaxBoost > 0 ? _sessionMaxBoost : null,
      ),
    );
  }


  Future<VagLongCodingReadResult> readVagLongCoding(VagLongCodingModule module) async {
    if (!_isRealMode || !_connection.isConnected || _connection.isReconnecting) {
      return VagLongCodingReadResult(success:false,message:tx('Önce canlı OBD bağlantısı kur.'));
    }
    _exclusiveDiagnosticOperation=true; notifyListeners();
    try {
      await _sendAndWait('ATH1',timeout:const Duration(seconds:3));
      await _sendAndWait('ATAL',timeout:const Duration(seconds:3));
      await _sendAndWait('ATCAF1',timeout:const Duration(seconds:3));
      await _sendAndWait('ATSH${module.requestId}',timeout:const Duration(seconds:3));
      await _sendAndWait('ATCRA${module.responseId}',timeout:const Duration(seconds:3));
      final partRaw=await _sendAndWait('22F187',timeout:const Duration(seconds:7));
      final swRaw=await _sendAndWait('22F189',timeout:const Duration(seconds:7));
      final raw=await _sendAndWait('220600',timeout:const Duration(seconds:10));
      final neg=UdsDiagnostic.parseNegative(raw);
      if(neg!=null) return VagLongCodingReadResult(success:false,message:tx('Long Coding okunamadı: {0}', [neg.description]));
      final payload=UdsDiagnostic.readDidPayload(raw,0x0600);
      if(payload==null||payload.isEmpty) return VagLongCodingReadResult(success:false,message:tx('ECU 0x0600 Long Coding verisi döndürmedi.'));
      String? text(String r,int did){final p=UdsDiagnostic.readDidPayload(r,did);if(p==null||p.isEmpty)return null;final t=UdsDiagnostic.ascii(p).trim();return t.isEmpty?null:t;}
      return VagLongCodingReadResult(success:true,message:tx('{0} byte Long Coding okundu', [payload.length]),valueHex:VagLongCodingService.hex(payload),partNumber:text(partRaw,0xF187),softwareVersion:text(swRaw,0xF189));
    } catch(e) {
      return VagLongCodingReadResult(success:false,message:tx('Long Coding okuma hatası: {0}', [e]));
    } finally {
      try{await _sendAndWait('ATCRA',timeout:const Duration(seconds:2));}catch(_){}
      try{await _sendAndWait('ATSH7DF',timeout:const Duration(seconds:2));}catch(_){}
      try{await _sendAndWait('ATH0',timeout:const Duration(seconds:2));}catch(_){}
      _exclusiveDiagnosticOperation=false; notifyListeners();
    }
  }

  Future<CodingApplyResult> writeVagLongCoding({
    required VagLongCodingModule module,
    required String requestedHex,
    required CodingHistoryProvider history,
  }) async {
    if (_isVehicleMoving) return CodingApplyResult(false, tx('Araç hareket halindeyken ECU\'ya yazılmaz. Aracı durdurup park konumuna alın.'));
    if (!module.writeAllowed || module.safetyCritical) return CodingApplyResult(false,tx('Bu modülde ham Long Coding yazma güvenlik nedeniyle kapalı.'));
    final vin=_detectedVin;
    if(vin==null||vin.length!=17) return CodingApplyResult(false,tx('Geçerli VIN olmadan kodlama yazılmaz.'));
    final requested=requestedHex.replaceAll(RegExp(r'[^0-9A-Fa-f]'),'').toUpperCase();
    if(requested.isEmpty||requested.length.isOdd) return CodingApplyResult(false,tx('Long Coding HEX değeri geçersiz.'));
    _exclusiveDiagnosticOperation=true; notifyListeners();
    try {
      await _sendAndWait('ATH1'); await _sendAndWait('ATAL'); await _sendAndWait('ATCAF1');
      await _sendAndWait('ATSH${module.requestId}'); await _sendAndWait('ATCRA${module.responseId}');
      final partRaw=await _sendAndWait('22F187',timeout:const Duration(seconds:7));
      final swRaw=await _sendAndWait('22F189',timeout:const Duration(seconds:7));
      String? text(String r,int did){final p=UdsDiagnostic.readDidPayload(r,did);if(p==null||p.isEmpty)return null;final t=UdsDiagnostic.ascii(p).trim();return t.isEmpty?null:t;}
      final part=text(partRaw,0xF187), sw=text(swRaw,0xF189);
      final beforeRaw=await _sendAndWait('220600',timeout:const Duration(seconds:10));
      final before=UdsDiagnostic.readDidPayload(beforeRaw,0x0600);
      if(before==null||before.isEmpty) return CodingApplyResult(false,tx('Mevcut Long Coding okunamadı; yazma iptal edildi.'));
      final beforeHex=VagLongCodingService.hex(before);
      if(beforeHex.length!=requested.length) return CodingApplyResult(false,tx('Yeni Long Coding uzunluğu ECU ile aynı değil ({0} byte bekleniyor).', [beforeHex.length~/2]));
      final session=await _sendAndWait('1003',timeout:const Duration(seconds:6));
      final sessionNeg=UdsDiagnostic.parseNegative(session);
      if(sessionNeg!=null || !_containsSequence(UdsDiagnostic.hexBytes(session),const [0x50,0x03])) {
        return CodingApplyResult(false,tx('ECU genişletilmiş oturumu açmadı{0}.', [sessionNeg==null?'':': ${sessionNeg.description}']));
      }
      try{await _sendAndWait('3E00',timeout:const Duration(seconds:4));}catch(_){}
      final result=await CodingTransactionService.execute(
        requestedHex:requested,
        readCurrent:()async{final r=await _sendAndWait('220600',timeout:const Duration(seconds:10));final p=UdsDiagnostic.readDidPayload(r,0x0600);return p==null?'':VagLongCodingService.hex(p);},
        writeValue:(value)async{try{await _sendAndWait('3E00',timeout:const Duration(seconds:4));}catch(_){} final r=await _sendAndWait('2E0600$value',timeout:const Duration(seconds:12));final n=UdsDiagnostic.parseNegative(r);if(n!=null)throw StateError(n.description);if(!_containsSequence(UdsDiagnostic.hexBytes(r),const [0x6E,0x06,0x00]))throw StateError(tx('ECU pozitif 0x6E0600 cevabı vermedi'));},
        createBackup:(original)=>CodingBackupRecord(id:'${DateTime.now().microsecondsSinceEpoch}-long-${module.module}',vin:vin,brand:_detectedBrand??'VAG',moduleName:module.name,requestId:module.requestId,responseId:module.responseId,did:'0600',originalHex:original,status:CodingBackupStatus.captured,createdAt:DateTime.now().toUtc(),ecuPartNumber:part,ecuSoftwareVersion:sw),
        saveBackup:history.capture,
        updateStatus:history.updateStatus,
      );
      return CodingApplyResult(result.success,result.message,rolledBack:result.rolledBack);
    } catch(e) {
      return CodingApplyResult(false,tx('Long Coding yazma hatası: {0}', [e]));
    } finally {
      try{await _sendAndWait('1001',timeout:const Duration(seconds:3));}catch(_){}
      try{await _sendAndWait('ATCRA',timeout:const Duration(seconds:2));}catch(_){}
      try{await _sendAndWait('ATSH7DF',timeout:const Duration(seconds:2));}catch(_){}
      try{await _sendAndWait('ATH0',timeout:const Duration(seconds:2));}catch(_){}
      _exclusiveDiagnosticOperation=false; notifyListeners();
    }
  }

  Future<VagModuleBackupSnapshot> captureVagModuleBackup({
    required VagLongCodingModule module,
    required List<String> commands,
  }) async {
    if(!_isRealMode||!_connection.isConnected) throw StateError(tx('Önce canlı OBD bağlantısı kur.'));
    _exclusiveDiagnosticOperation=true; notifyListeners();
    final values=<String,String>{};
    try {
      await _sendAndWait('ATH1'); await _sendAndWait('ATAL'); await _sendAndWait('ATCAF1');
      await _sendAndWait('ATSH${module.requestId}'); await _sendAndWait('ATCRA${module.responseId}');
      for(final command in commands) {
        if(!RegExp(r'^22[0-9A-Fa-f]{4}$').hasMatch(command)) continue;
        final did=command.substring(2).toUpperCase();
        try {
          final raw=await _sendAndWait(command,timeout:const Duration(seconds:5));
          final p=UdsDiagnostic.readDidPayload(raw,int.parse(did,radix:16));
          if(p!=null) values[did]=VagLongCodingService.hex(p);
        } catch(_) {}
      }
      return VagModuleBackupSnapshot(module:module.module,moduleName:module.name,requestId:module.requestId,responseId:module.responseId,createdAt:DateTime.now().toUtc(),values:Map.unmodifiable(values),attempted:commands.length,succeeded:values.length);
    } finally {
      try{await _sendAndWait('ATCRA');}catch(_){} try{await _sendAndWait('ATSH7DF');}catch(_){} try{await _sendAndWait('ATH0');}catch(_){}
      _exclusiveDiagnosticOperation=false; notifyListeners();
    }
  }

  void stopWithError(String errorMessage) {
    stopRealData();
    _errorEventController.add(errorMessage);
  }

  @override
  void dispose() {
    _isRealMode = false;
    _demoGenerator.stop();
    _rxSubscription?.cancel();
    _errorEventController.close();
    super.dispose();
  }
}
