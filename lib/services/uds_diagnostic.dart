import 'package:otosinyal_obd2/l10n/tx.dart';
class UdsNegativeResponse {
  final int requestService;
  final int code;
  final String description;
  const UdsNegativeResponse(this.requestService,this.code,this.description);
}

class UdsDiagnostic {
  static final Map<int,String> negativeResponseDescriptions = {
    0x10:tx('Genel ret'),0x11:tx('Servis desteklenmiyor'),0x12:tx('Alt fonksiyon desteklenmiyor'),0x13:tx('Mesaj uzunluğu/format hatası'),
    0x21:tx('ECU meşgul, tekrar deneyin'),0x22:tx('Koşullar uygun değil'),0x24:tx('İstek sırası hatalı'),0x31:tx('İstek aralık dışında'),
    0x33:tx('Güvenlik erişimi reddedildi'),0x35:tx('Geçersiz anahtar'),0x36:tx('Deneme sayısı aşıldı'),0x37:tx('Gerekli bekleme süresi dolmadı'),
    0x70:tx('Yükleme/indirme kabul edilmedi'),0x71:tx('Aktarım askıya alındı'),0x72:tx('Programlama hatası'),0x73:tx('Yanlış blok sıra sayacı'),
    0x78:tx('Yanıt beklemede'),0x7E:tx('Alt fonksiyon mevcut oturumda desteklenmiyor'),0x7F:tx('Servis mevcut oturumda desteklenmiyor'),
  };

  static List<int> _lineBytes(String source) {
    var line = source.trim().toUpperCase();
    if (line.isEmpty ||
        line.contains('NO DATA') ||
        line.contains('SEARCHING') ||
        line.contains('STOPPED') ||
        line.contains('ERROR') ||
        line == 'OK' ||
        line == '?') {
      return const [];
    }

    // ELM multiline responses may be prefixed with "0:", "1:" etc.
    line = line.replaceFirst(RegExp(r'^\s*[0-9A-F]+\s*:\s*'), '');

    var tokens = line.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];

    // Header-on mode with spaces: "7E8 06 41 00 ..." or 29-bit CAN ID.
    if (tokens.length > 1) {
      final first = tokens.first;
      final is11BitHeader = RegExp(r'^[0-9A-F]{3}$').hasMatch(first);
      final is29BitHeader = RegExp(r'^[0-9A-F]{8}$').hasMatch(first) &&
          (first.startsWith('18DA') || first.startsWith('18DB'));
      if (is11BitHeader || is29BitHeader) tokens = tokens.sublist(1);
    }

    var compact = tokens.join().replaceAll(RegExp(r'[^0-9A-F]'), '');

    // Several ELM327 firmwares omit spaces while headers are enabled, e.g.
    // "7E8064100000000". AndrOBD handles this form; OtoSinyal must too.
    if (compact.length > 5 && compact.length.isOdd) {
      final tail = compact.substring(3);
      if (RegExp(r'^[0-9A-F]{3}$').hasMatch(compact.substring(0, 3)) &&
          tail.length.isEven) {
        compact = tail;
      }
    }

    // Compact 29-bit CAN response, commonly 18DAxxxx + PCI/length + payload.
    if (compact.length > 10 && compact.length.isEven) {
      final header = compact.substring(0, 8);
      final tail = compact.substring(8);
      if (tail.length >= 2 && tail.length.isEven &&
          (header.startsWith('18DA') || header.startsWith('18DB'))) {
        final first = int.tryParse(tail.substring(0, 2), radix: 16);
        final looksLikeCanPayload = first != null &&
            (first <= 0x3F ||
                first == 0x41 || first == 0x42 || first == 0x43 ||
                first == 0x47 || first == 0x49 || first == 0x4A ||
                first == 0x59 || first == 0x62 || first == 0x7F);
        if (looksLikeCanPayload) compact = tail;
      }
    }

    if (compact.length < 2 || compact.length.isOdd) return const [];
    final out = <int>[];
    for (var i = 0; i < compact.length; i += 2) {
      out.add(int.parse(compact.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  /// Raw byte view kept for positive-response marker checks.
  static List<int> hexBytes(String raw) {
    final out=<int>[];
    for(final line in raw.replaceAll('>','\n').replaceAll('\r','\n').split('\n')) { out.addAll(_lineBytes(line)); }
    return out;
  }

  /// Reassembles ISO-TP before UDS parsing. This matters for long-coding DID
  /// 0600: byte/bit definitions can point well past the first CAN frame.
  static List<List<int>> udsMessages(String raw) {
    final frames=<List<int>>[];
    for(final line in raw.replaceAll('>','\n').replaceAll('\r','\n').split('\n')) {
      final b=_lineBytes(line); if(b.isNotEmpty)frames.add(b);
    }
    final messages=<List<int>>[];
    List<int>? active; int expected=0; int nextSeq=1;
    void finish(){ if(active!=null){ final n=expected>0&&active!.length>expected?expected:active!.length; messages.add(List<int>.from(active!.sublist(0,n))); } active=null; expected=0; nextSeq=1; }
    for(var frame in frames){
      if(frame.isEmpty)continue;
      // Some ELM firmwares with CAF1 return a one-byte payload length before UDS.
      if(frame.length>1 && frame[0] <= 0x3F && (frame[1]==0x62||frame[1]==0x6E||frame[1]==0x67||frame[1]==0x50||frame[1]==0x7F)) {
        finish(); final len=frame[0]; messages.add(List<int>.from(frame.sublist(1, (1+len).clamp(1,frame.length)))); continue;
      }
      final pci=frame[0]; final type=pci&0xF0;
      if(type==0x00 && frame.length>1){ finish(); final len=pci&0x0F; messages.add(List<int>.from(frame.sublist(1,(1+len).clamp(1,frame.length)))); continue; }
      if(type==0x10 && frame.length>2){ finish(); expected=((pci&0x0F)<<8)|frame[1]; active=List<int>.from(frame.sublist(2)); if(active!.length>=expected)finish(); continue; }
      if(type==0x20 && active!=null){ final seq=pci&0x0F; if(seq!=(nextSeq&0x0F)){ active=null; expected=0; nextSeq=1; continue; } active!.addAll(frame.sublist(1)); nextSeq++; if(active!.length>=expected)finish(); continue; }
      // Already de-framed diagnostic/OBD data (common with CAF1). 0x49 is
      // Mode 09 positive response (VIN); the Mode 01/03/07/0A positives are
      // included so the same frame assembler can be reused safely by decoders.
      if(frame.contains(0x41)||frame.contains(0x43)||frame.contains(0x47)||frame.contains(0x49)||frame.contains(0x4A)||frame.contains(0x59)||frame.contains(0x62)||frame.contains(0x6E)||frame.contains(0x67)||frame.contains(0x50)||frame.contains(0x7F)){ finish(); messages.add(List<int>.from(frame)); }
    }
    finish();
    if(messages.isEmpty){ final flat=hexBytes(raw); if(flat.isNotEmpty)messages.add(flat); }
    return messages;
  }

  static UdsNegativeResponse? parseNegative(String raw) {
    for(final b in udsMessages(raw)) for(var i=0;i+2<b.length;i++) if(b[i]==0x7F) return UdsNegativeResponse(b[i+1],b[i+2],negativeResponseDescriptions[b[i+2]] ?? tx('Bilinmeyen UDS negatif yanıtı'));
    return null;
  }

  static List<int>? readDidPayload(String raw, int did) {
    final hi=(did>>8)&0xFF, lo=did&0xFF;
    for(final b in udsMessages(raw)) for(var i=0;i+2<b.length;i++) if(b[i]==0x62&&b[i+1]==hi&&b[i+2]==lo) return List<int>.from(b.sublist(i+3));
    return null;
  }

  static String ascii(List<int> bytes) => String.fromCharCodes(bytes.where((b)=>b>=0x20&&b<=0x7E)).trim();
}
