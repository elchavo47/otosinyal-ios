import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:otosinyal_obd2/l10n/app_language.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// OBD2 arıza kodları (DTC) için açıklamalar (Türkçe / İngilizce).
///
/// Veri kaynağı: assets/data/dtc_generic_tr.json ve dtc_generic_en.json —
/// 4.193 P/B/C/U kodu. Etkin uygulama diline göre ilgili dosya yüklenir.
/// ~1.500'ü kullanıcının sağladığı elle çevrilmiş Türkçe metinden,
/// ~2.700'ü ise İngilizce bir DTC veritabanından kalıp/terim tabanlı bir
/// çeviri motoruyla otomatik çevrildi. Otomatik çevrilen kısımda bazı
/// nadir/özel terimler tam doğal Türkçe olmayabilir ama teknik anlam
/// korunmuştur. Bu kodların büyük çoğunluğu SAE tarafından tanımlanan
/// "jenerik" kodlardır ve HER MARKADA aynı anlama gelir.
///
/// Sözlükte bulunmayan kodlar için: harften sonraki ilk rakam '0' ise
/// yine jenerik kabul edilip kategori bazlı bir açıklama verilir; değilse
/// (P1xxx, P3xxx gibi) bu muhtemelen üretici-özel bir koddur ve elimizde
/// veri yoksa uydurma açıklama YAPILMAZ, dürüstçe belirtilir.
class DtcDictionary {
  static Map<String, String> _codes = {};
  static bool _isLoaded = false;
  static final Map<String, Map<String, String>> _oemCodes = {};
  static const Map<String,String> _brandFile = {'volkswagen':'vw','audi':'vw','skoda':'vw','seat':'vw','cupra':'vw','bmw':'bmw','mini':'bmw','mercedes':'mercedes','ford':'ford','toyota':'toyota','lexus':'toyota','hyundai':'hmg','kia':'hmg','genesis':'hmg'};
  static Future<void>? _loadingFuture;

  /// Uygulama açılışında bir kere çağrılmalı (main.dart).
  /// JSON'u assets'ten okuyup belleğe alır.
  static Future<void> initialize() {
    final lang = AppLanguage.isEnglish ? 'en' : 'tr';
    if (_loadingFuture == null || _loadedLanguage != lang) {
      _loadedLanguage = lang;
      _loadingFuture = _load(lang);
    }
    return _loadingFuture!;
  }

  static String? _loadedLanguage;

  static Future<void> _load(String lang) async {
    try {
      final raw = await rootBundle.loadString('assets/data/dtc_generic_$lang.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _codes = decoded.map((k, v) => MapEntry(k, v.toString()));
      // Delphi-OBD OEM katalogları ek açıklama katmanı olarak yüklenir.
      // Bu katalog girdilerinin çoğu upstream'de verified=false olduğundan UI
      // bunları kesin teşhis değil, üretici kataloğu açıklaması olarak kullanır.
      for (final key in {'vw','bmw','mercedes','ford','toyota','hmg'}) {
        try {
          final oemRaw = await rootBundle.loadString('assets/data/delphi/dtc-$key.json');
          final root = jsonDecode(oemRaw) as Map<String,dynamic>;
          final map = <String,String>{};
          for (final item in ((root['dtcs'] as List?) ?? const []).whereType<Map>()) {
            final c='${item['code'] ?? ''}'.toUpperCase();
            final d='${item['description'] ?? ''}'.trim();
            if(c.isNotEmpty && d.isNotEmpty) map[c]=d;
          }
          _oemCodes[key]=map;
        } catch (_) {}
      }
    } catch (_) {
      _codes = {};
    } finally {
      _isLoaded = true;
    }
  }

  static bool get isLoaded => _isLoaded;

  /// [code] için açıklama döner. [brand] verilirse, üretici-özel bir kod
  /// tespit edilirse mesajda marka adı da geçer.
  static String getDescription(String code, {String? brand}) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return tx('Bilinmeyen arıza kodu');

    final known = _codes[normalized];
    if (known != null) return known;

    final b=(brand ?? '').trim().toLowerCase();
    String? oemKey;
    for(final e in _brandFile.entries){ if(b.contains(e.key)){ oemKey=e.value; break; } }
    final oem = oemKey == null ? null : _oemCodes[oemKey]?[normalized];
    if(oem != null) return tx('{0} • Üretici kataloğu (doğrulama önerilir)', [oem]);

    final isGeneric = normalized.length >= 2 && normalized[1] == '0';
    if (isGeneric) {
      return _genericCategoryHint(normalized);
    }

    final brandLabel = (brand != null && brand.trim().isNotEmpty)
        ? brand.trim()
        : tx('aracın üreticisine');
    return tx('{0} özel bir kod — veritabanımızda yok, yetkili servis/bayi ile kontrol edin', [brandLabel]);
  }

  static String _genericCategoryHint(String code) {
    switch (code[0]) {
      case 'P':
        return tx('Motor / şanzıman ile ilgili jenerik arıza kodu');
      case 'B':
        return tx('Kasa (hava yastığı, klima, aydınlatma vb.) jenerik arıza kodu');
      case 'C':
        return tx('Şasi (ABS, süspansiyon, direksiyon vb.) jenerik arıza kodu');
      case 'U':
        return tx('Ağ / modüller arası iletişim jenerik arıza kodu');
      default:
        return tx('Bilinmeyen arıza kodu');
    }
  }

  /// Bir kodun sözlükte bulunup bulunmadığını (dolayısıyla üretici-özel
  /// olup olmadığını) UI'da rozet göstermek için kullanılır.
  static bool isManufacturerSpecific(String code) {
    final normalized = code.trim().toUpperCase();
    if (_codes.containsKey(normalized)) return false;
    return normalized.length >= 2 && normalized[1] != '0';
  }
}
