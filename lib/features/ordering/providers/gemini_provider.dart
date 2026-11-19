import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/core/security/api_key_security.dart';

// Quản lý trợ lý AI Gemini
class GeminiAssistantNotifier extends StateNotifier<String> {
  GeminiAssistantNotifier() : super('');

  static const List<String> _candidateModels = [
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
  ];

  // Gọi API Gemini
  Future<String?> _generateWithFallback(String prompt) async {
    final apiKey = await ApiKeySecurity.getGeminiApiKey();

    for (final modelName in _candidateModels) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.trim().isNotEmpty) {
          return response.text!.trim();
        }
      } catch (e) {
        debugPrint('Lỗi gọi model $modelName: $e');
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('api_key_invalid') ||
            errStr.contains('leaked') ||
            errStr.contains('permission_denied')) {
          rethrow;
        }
      }
    }
    return null;
  }

  // Tư vấn chọn món trong thực đơn của một nhà hàng
  Future<void> askForRecommendation(
    String userQuery,
    List<MenuItemModel> currentMenu,
    String restaurantName,
  ) async {
    if (currentMenu.isEmpty) {
      state = 'Hiện tại nhà hàng chưa có thực đơn để gợi ý!';
      return;
    }
    state = 'Đang suy nghĩ...';
    try {
      String menuContext = currentMenu
          .map((m) => '- ${m.name} (${m.price}đ): ${m.description}')
          .join('\n');
      final prompt = '''
Bạn là nhân viên tư vấn món ăn của nhà hàng "$restaurantName". 
Dưới đây là thực đơn:
$menuContext
Khách hàng yêu cầu: "$userQuery"
Nhiệm vụ: Dựa vào đúng thực đơn trên, chọn ra 1-2 món phù hợp nhất để giới thiệu. Trả lời dưới 100 chữ.
''';
      final result = await _generateWithFallback(prompt);
      state =
          result ?? _localMenuFallback(userQuery, currentMenu, restaurantName);
    } catch (e) {
      debugPrint('Lỗi Gemini askForRecommendation: $e');
      state = _localMenuFallback(userQuery, currentMenu, restaurantName);
    }
  }

  // Tư vấn tìm kiếm nhà hàng và món ăn trên hệ thống
  Future<void> suggestRestaurantAndDish(
    String userQuery,
    String systemContext,
  ) async {
    state = 'AI đang lướt tìm nhà hàng ngon cho bạn...';
    try {
      final prompt = '''
Bạn là trợ lý ẩm thực thông minh của ứng dụng.
Dưới đây là các nhà hàng và thực đơn trên hệ thống:
$systemContext

Khách hàng yêu cầu: "$userQuery"

Nhiệm vụ: Dựa đúng vào dữ liệu trên, hãy gợi ý 1 nhà hàng phù hợp nhất và 1-2 món ăn tiêu biểu của quán đó. Trả lời thân thiện, súc tích dưới 100 chữ.
''';
      final result = await _generateWithFallback(prompt);
      state = result ?? _localSystemFallback(userQuery, systemContext);
    } catch (e) {
      debugPrint('Lỗi Gemini suggestRestaurantAndDish: $e');
      state = _localSystemFallback(userQuery, systemContext);
    }
  }

  // Gợi ý dự phòng theo thực đơn nhà hàng
  String _localMenuFallback(
    String query,
    List<MenuItemModel> menu,
    String restaurantName,
  ) {
    final q = query.toLowerCase();
    final matched = menu.where((m) {
      return m.name.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q) ||
          m.category.toLowerCase().contains(q);
    }).toList();

    final picks = (matched.isNotEmpty ? matched : menu).take(2).toList();
    final dishList = picks.map((m) => '${m.name} (${m.price}đ)').join(' và ');
    return 'Gợi ý tại $restaurantName: Bạn nên thử món $dishList. Đây là những món nổi bật trong thực đơn của quán.';
  }

  // Gợi ý dự phòng theo danh sách nhà hàng
  String _localSystemFallback(String query, String systemContext) {
    if (systemContext.trim().isEmpty) {
      return 'Hiện hệ thống chưa có nhà hàng nào được phê duyệt.';
    }

    final blocks = systemContext
        .split('-------------------')
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    if (blocks.isEmpty) {
      return 'Chưa tìm thấy nhà hàng nào phù hợp lúc này.';
    }

    final q = query.toLowerCase();
    String bestBlock = blocks.first;
    int bestScore = -1;

    final keywords = q
        .replaceAll(
            RegExp(
                r'[^\w\sàáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]'),
            ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();

    for (final block in blocks) {
      final lowerBlock = block.toLowerCase();
      int score = 0;
      for (final kw in keywords) {
        if (lowerBlock.contains(kw)) score += 2;
      }
      if (q.contains('rẻ') || q.contains('100k')) {
        if (lowerBlock.contains('50000') ||
            lowerBlock.contains('60000') ||
            lowerBlock.contains('70000') ||
            lowerBlock.contains('80000') ||
            lowerBlock.contains('90000')) {
          score += 3;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestBlock = block;
      }
    }

    final lines = bestBlock.split('\n');
    final resLine = lines.firstWhere(
      (l) => l.startsWith('Nhà hàng:'),
      orElse: () => lines.first,
    );
    final menuLine = lines.firstWhere(
      (l) => l.startsWith('Thực đơn:'),
      orElse: () => 'Thực đơn: Đang cập nhật',
    );

    final resName = resLine.replaceFirst('Nhà hàng:', '').trim();
    final menuInfo = menuLine.replaceFirst('Thực đơn:', '').trim();

    return 'Với yêu cầu "$query", gợi ý bạn ghé $resName:\n\n'
        '• Thực đơn: $menuInfo.\n'
        '• Bạn có thể chuyển sang tab Khám phá để xem bản đồ hoặc Đặt bàn ngay.';
  }
}

final geminiAssistantProvider =
    StateNotifierProvider<GeminiAssistantNotifier, String>((ref) {
  return GeminiAssistantNotifier();
});
