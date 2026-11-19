import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:str/core/config/api_keys.dart';

// Bảo mật và mã hóa API Key
class ApiKeySecurity {
  static const String _secretSalt = 'SmartOrder2026';
  static const String _prefsKey = 'encrypted_gemini_api_key_b64';
  static String? _runtimeApiKey;

  // Lấy API Key đã giải mã
  static Future<String> getGeminiApiKey() async {
    if (_runtimeApiKey != null && _runtimeApiKey!.isNotEmpty) {
      return _runtimeApiKey!;
    }
    final codeKey = ApiKeys.geminiApiKey.trim();
    if (codeKey.isNotEmpty) {
      return codeKey;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedB64 = prefs.getString(_prefsKey);
      if (savedB64 != null && savedB64.isNotEmpty) {
        _runtimeApiKey = decryptFromBase64(savedB64);
        return _runtimeApiKey!;
      }
    } catch (_) {}

    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    return envKey;
  }

  // Lưu và mã hóa API Key mới
  static Future<List<int>> saveAndEncryptNewKey(String plainApiKey) async {
    final cleanKey = plainApiKey.trim();
    _runtimeApiKey = cleanKey;

    final encryptedBytes = encryptToBytes(cleanKey);
    final b64 = base64Encode(encryptedBytes);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, b64);
    } catch (_) {}

    return encryptedBytes;
  }

  // Mã hóa chuỗi sang mảng byte XOR
  static List<int> encryptToBytes(String plainApiKey) {
    final rawBytes = utf8.encode(plainApiKey.trim());
    final saltBytes = utf8.encode(_secretSalt);
    return List<int>.generate(
      rawBytes.length,
      (i) => rawBytes[i] ^ saltBytes[i % saltBytes.length],
    );
  }

  // Giải mã mảng byte XOR
  static String decryptBytes(List<int> encryptedBytes) {
    final saltBytes = utf8.encode(_secretSalt);
    final decrypted = List<int>.generate(
      encryptedBytes.length,
      (i) => encryptedBytes[i] ^ saltBytes[i % saltBytes.length],
    );
    return utf8.decode(decrypted);
  }

  // Giải mã chuỗi Base64
  static String decryptFromBase64(String encryptedBase64) {
    final bytes = base64Decode(encryptedBase64);
    return decryptBytes(bytes);
  }
}
