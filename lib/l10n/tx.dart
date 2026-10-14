import 'app_language.dart';
import 'en_strings.dart';

final RegExp _placeholder = RegExp(r'\{(\d+)\}');

/// Türkçe kaynak metni etkin dile çevirir.
///
/// Kaynak metin anahtar olarak kullanılır; İngilizce modda [enStrings]
/// içindeki karşılığı döner. `{0}`, `{1}` yer tutucuları [args] ile doldurulur.
String tx(String turkish, [List<Object?> args = const []]) {
  final template = AppLanguage.isEnglish ? (enStrings[turkish] ?? turkish) : turkish;
  if (args.isEmpty) return template;
  return template.replaceAllMapped(_placeholder, (m) {
    final index = int.parse(m.group(1)!);
    return index < args.length ? '${args[index]}' : m.group(0)!;
  });
}
