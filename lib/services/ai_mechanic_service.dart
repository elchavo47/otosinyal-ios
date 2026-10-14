import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class AiMechanicService {
  static const _prefsKey = 'otosinyal_ai_backend_endpoint';
  static const _buildEndpoint = String.fromEnvironment('OTOSINYAL_AI_ENDPOINT');

  /// Mağaza build'inde AI sunucusu tanımlı değilse özellik gösterilmez
  /// (kullanıcıdan sunucu adresi istemek App Review 2.1 açısından eksik özellik sayılır).
  static bool get isAvailable => _buildEndpoint.trim().isNotEmpty;

  static Future<String> getEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_prefsKey) ?? _buildEndpoint).trim();
  }

  static Future<void> setEndpoint(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = value.trim();
    if (clean.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, clean);
    }
  }

  static Future<String> ask({
    required String prompt,
    required String question,
  }) async {
    final endpoint = await getEndpoint();
    if (endpoint.isEmpty) {
      throw StateError('AI sunucu adresi tanımlı değil');
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https') {
      throw StateError('AI sunucusu geçerli bir HTTPS adresi olmalı');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.headers.set('accept', 'application/json');
      request.write(jsonEncode({
        'source': 'otosinyal_mobile',
        'question': question,
        'prompt': prompt,
      }));
      final response = await request.close().timeout(const Duration(seconds: 45));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('AI sunucusu HTTP ${response.statusCode}: ${body.length > 180 ? body.substring(0, 180) : body}');
      }
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['answer', 'message', 'response', 'text']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
      }
      if (body.trim().isNotEmpty) return body.trim();
      throw const FormatException('AI sunucusu boş yanıt döndürdü');
    } finally {
      client.close(force: true);
    }
  }
}
