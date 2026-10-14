import 'ios_share_origin.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

class DiagnosticFlightRecorder {
  DiagnosticFlightRecorder._();
  static final DiagnosticFlightRecorder instance = DiagnosticFlightRecorder._();

  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  String? _sessionId;
  DateTime? _startedAt;
  int _seq = 0;
  bool _closed = false;

  bool get active => _sessionId != null && !_closed;
  String? get sessionId => _sessionId;
  int get eventCount => _events.length;

  void start({String reason = 'diagnostic', Map<String, dynamic>? context}) {
    _startedAt = DateTime.now();
    _sessionId = _startedAt!.toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    _events.clear();
    _seq = 0;
    _closed = false;
    event('SESSION_START', data: <String, dynamic>{'reason': reason, ...?context});
  }

  void ensureStarted({String reason = 'automatic'}) {
    if (!active) start(reason: reason);
  }

  void event(String type, {String? command, String? raw, int? elapsedMs, Map<String, dynamic>? data}) {
    ensureStarted();
    _events.add(<String, dynamic>{
      'seq': ++_seq,
      'time': DateTime.now().toIso8601String(),
      'type': type,
      if (command != null) 'command': command,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (raw != null) 'raw': raw.replaceAll('\r', '<CR>').replaceAll('\n', '<LF>'),
      if (data != null) 'data': data,
    });
    if (_events.length > 12000) _events.removeRange(0, 1000);
  }

  void finish({Map<String, dynamic>? summary}) {
    if (!active) return;
    event('SESSION_END', data: summary);
    _closed = true;
  }

  Map<String, dynamic> snapshot() => <String, dynamic>{
    'format': 'OTOSINYAL Diagnostic Flight Recorder v1',
    'session_id': _sessionId,
    'started_at': _startedAt?.toIso8601String(),
    'generated_at': DateTime.now().toIso8601String(),
    'event_count': _events.length,
    'events': List<Map<String, dynamic>>.from(_events),
  };

  String asText() {
    final b = StringBuffer()
      ..writeln('OTOSINYAL DIAGNOSTIC FLIGHT RECORDER')
      ..writeln('Session: ${_sessionId ?? '-'}')
      ..writeln('Started: ${_startedAt?.toIso8601String() ?? '-'}')
      ..writeln('Events: ${_events.length}')
      ..writeln('=' * 72);
    for (final e in _events) {
      b.write('[${e['seq']}] ${e['time']} ${e['type']}');
      if (e['elapsed_ms'] != null) b.write(' ${e['elapsed_ms']}ms');
      if (e['command'] != null) b.write(' TX=${e['command']}');
      b.writeln();
      if (e['raw'] != null) b.writeln('  RX=${e['raw']}');
      if (e['data'] != null) b.writeln('  DATA=${jsonEncode(e['data'])}');
    }
    return b.toString();
  }

  Future<List<File>> export() async {
    ensureStarted();
    final dir = await getTemporaryDirectory();
    final base = 'OTOSINYAL_DIAG_${_sessionId ?? DateTime.now().millisecondsSinceEpoch}';
    final jsonFile = File('${dir.path}/$base.json');
    final txtFile = File('${dir.path}/$base.txt');
    await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot()), flush: true);
    await txtFile.writeAsString(asText(), flush: true);
    return <File>[jsonFile, txtFile];
  }

  Future<void> share() async {
    final files = await export();
    await Share.shareXFiles(files.map((f) => XFile(f.path)).toList(), subject: tx('OTOSİNYAL Ayrıntılı Teşhis Logu'), sharePositionOrigin: otoShareOrigin());
  }
}
