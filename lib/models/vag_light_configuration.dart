import 'package:otosinyal_obd2/l10n/tx.dart';
class VagLightChannel {
  final int index;
  final String did;
  final String name;
  final String hint;

  const VagLightChannel({
    required this.index,
    required this.did,
    required this.name,
    this.hint = '',
  });
}

class VagLightConfiguration {
  final VagLightChannel channel;
  final List<int> rawPayload;
  final int lampType;
  final int functionA;
  final int functionB;
  final int dimmwertAB;
  final int lightControlAB;
  final int functionC;
  final int functionD;
  final int dimmwertCD;
  final int dimmingDirectionCD;
  final int functionE;
  final int functionF;
  final int dimmwertEF;
  final int functionG;
  final int functionH;
  final int dimmwertGH;
  final int dimmingDirectionGH;
  final int dimmingDirectionEF;

  const VagLightConfiguration({
    required this.channel,
    required this.rawPayload,
    required this.lampType,
    required this.functionA,
    required this.functionB,
    required this.dimmwertAB,
    required this.lightControlAB,
    required this.functionC,
    required this.functionD,
    required this.dimmwertCD,
    required this.dimmingDirectionCD,
    required this.functionE,
    required this.functionF,
    required this.dimmwertEF,
    required this.functionG,
    required this.functionH,
    required this.dimmwertGH,
    required this.dimmingDirectionGH,
    required this.dimmingDirectionEF,
  });

  factory VagLightConfiguration.fromPayload(VagLightChannel channel, List<int> payload) {
    if (payload.length < 17) {
      throw StateError(tx('Leuchte payload en az 17 byte olmalı; {0} byte geldi.', [payload.length]));
    }
    return VagLightConfiguration(
      channel: channel,
      rawPayload: List<int>.unmodifiable(payload),
      lampType: payload[0],
      functionA: payload[1],
      functionB: payload[2],
      dimmwertAB: payload[3],
      lightControlAB: payload[4],
      functionC: payload[5],
      functionD: payload[6],
      dimmwertCD: payload[7],
      dimmingDirectionCD: payload[8],
      functionE: payload[9],
      functionF: payload[10],
      dimmwertEF: payload[11],
      functionG: payload[12],
      functionH: payload[13],
      dimmwertGH: payload[14],
      dimmingDirectionGH: payload[15],
      dimmingDirectionEF: payload[16],
    );
  }

  List<int> toPayload() {
    final out = List<int>.from(rawPayload);
    final values = <int>[
      lampType,
      functionA,
      functionB,
      dimmwertAB,
      lightControlAB,
      functionC,
      functionD,
      dimmwertCD,
      dimmingDirectionCD,
      functionE,
      functionF,
      dimmwertEF,
      functionG,
      functionH,
      dimmwertGH,
      dimmingDirectionGH,
      dimmingDirectionEF,
    ];
    for (var i = 0; i < values.length; i++) {
      out[i] = values[i] & 0xFF;
    }
    return out;
  }

  VagLightConfiguration copyWith({
    int? lampType,
    int? functionA,
    int? functionB,
    int? dimmwertAB,
    int? lightControlAB,
    int? functionC,
    int? functionD,
    int? dimmwertCD,
    int? dimmingDirectionCD,
    int? functionE,
    int? functionF,
    int? dimmwertEF,
    int? functionG,
    int? functionH,
    int? dimmwertGH,
    int? dimmingDirectionGH,
    int? dimmingDirectionEF,
  }) {
    return VagLightConfiguration(
      channel: channel,
      rawPayload: rawPayload,
      lampType: lampType ?? this.lampType,
      functionA: functionA ?? this.functionA,
      functionB: functionB ?? this.functionB,
      dimmwertAB: dimmwertAB ?? this.dimmwertAB,
      lightControlAB: lightControlAB ?? this.lightControlAB,
      functionC: functionC ?? this.functionC,
      functionD: functionD ?? this.functionD,
      dimmwertCD: dimmwertCD ?? this.dimmwertCD,
      dimmingDirectionCD: dimmingDirectionCD ?? this.dimmingDirectionCD,
      functionE: functionE ?? this.functionE,
      functionF: functionF ?? this.functionF,
      dimmwertEF: dimmwertEF ?? this.dimmwertEF,
      functionG: functionG ?? this.functionG,
      functionH: functionH ?? this.functionH,
      dimmwertGH: dimmwertGH ?? this.dimmwertGH,
      dimmingDirectionGH: dimmingDirectionGH ?? this.dimmingDirectionGH,
      dimmingDirectionEF: dimmingDirectionEF ?? this.dimmingDirectionEF,
    );
  }
}

class VagLightReadResult {
  final bool success;
  final String message;
  final VagLightConfiguration? configuration;

  const VagLightReadResult(this.success, this.message, {this.configuration});
}
