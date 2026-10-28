import 'package:flutter/widgets.dart';

/// Küçük yazıları okunur boyuta yaklaştıran metin ölçekleyici.
///
/// Uygulamadaki bazı etiketler 7–10 pt'ye kadar iniyor ve uzun kullanımda göz
/// yoruyordu. Bu ölçekleyici [minComfortSize] altındaki yazıları aradaki farkın
/// yarısı kadar büyütür (ör. 9 → 11, 10 → 11.5); daha büyük yazılara dokunmaz.
/// Kullanıcının iOS'ta seçtiği yazı boyutu ([base]) üzerine uygulanır.
@immutable
class ComfortTextScaler extends TextScaler {
  const ComfortTextScaler(this.base);

  final TextScaler base;

  static const double minComfortSize = 13;
  static const double _boost = 0.5;

  @override
  double scale(double fontSize) {
    final adjusted = fontSize < minComfortSize ? fontSize + (minComfortSize - fontSize) * _boost : fontSize;
    return base.scale(adjusted);
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor;

  @override
  bool operator ==(Object other) => other is ComfortTextScaler && other.base == base;

  @override
  int get hashCode => Object.hash(ComfortTextScaler, base);
}
