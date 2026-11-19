import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/core/security/api_key_security.dart';
import 'package:str/features/ordering/providers/gemini_provider.dart';

// Tab trợ lý ẩm thực AI
class AiAssistantTab extends ConsumerStatefulWidget {
  const AiAssistantTab({super.key});

  @override
  ConsumerState<AiAssistantTab> createState() => _AiAssistantTabState();
}

class _AiAssistantTabState extends ConsumerState<AiAssistantTab> {
  final TextEditingController _aiTextCtrl = TextEditingController();
  String _lastAiQuestion = '';

  final List<Map<String, dynamic>> _aiSuggestions = const [
    {
      'label': 'Gợi ý quán lẩu thái ngon',
      'icon': Icons.soup_kitchen_rounded,
    },
    {
      'label': 'Quán món Âu hẹn hò lãng mạn',
      'icon': Icons.favorite_rounded,
    },
    {
      'label': 'Món ngon giá dưới 100k',
      'icon': Icons.savings_rounded,
    },
    {
      'label': 'Quán rộng rãi cho gia đình',
      'icon': Icons.groups_rounded,
    },
  ];

  @override
  void dispose() {
    _aiTextCtrl.dispose();
    super.dispose();
  }

  // Gửi câu hỏi tư vấn tới AI
  void _sendAIQuery([String? presetQuery]) {
    final query = (presetQuery ?? _aiTextCtrl.text).trim();
    if (query.isNotEmpty) {
      setState(() => _lastAiQuestion = query);
      final restaurants = ref.read(realRestaurantListProvider);
      final allMenus = ref.read(menuDbProvider);
      String systemContext = '';

      for (var res in restaurants.where((r) => r.status == 'APPROVED')) {
        systemContext += 'Nhà hàng: ${res.name} (Chuyên: ${res.category})\n';
        final resMenu =
            allMenus.where((m) => m.restaurantName == res.name).toList();
        if (resMenu.isNotEmpty) {
          systemContext += 'Thực đơn: ' +
              resMenu.map((m) => '${m.name} (${m.price}đ)').join(', ') +
              '\n';
        } else {
          systemContext += 'Thực đơn: Đang cập nhật\n';
        }
        systemContext += '-------------------\n';
      }

      ref
          .read(geminiAssistantProvider.notifier)
          .suggestRestaurantAndDish(query, systemContext);
      _aiTextCtrl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  // Hộp thoại cấu hình và mã hóa API Key
  void _showApiKeyDialog() {
    final keyCtrl = TextEditingController();
    List<int>? encryptedResult;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.vpn_key_rounded, color: Colors.purple),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mã hóa Gemini API Key',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập Gemini API Key mới từ Google AI Studio để mã hóa và sử dụng:',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF6C7278), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: keyCtrl,
                    decoration: InputDecoration(
                      hintText: 'Dán API Key (AIzaSy...)',
                      filled: true,
                      fillColor: const Color(0xFFF4F6FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (encryptedResult != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Đã kích hoạt và mã hóa Key thành mảng byte:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            encryptedResult.toString(),
                            style: const TextStyle(
                                fontSize: 11, fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                    text: encryptedResult.toString()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Đã sao chép mảng byte mã hóa!'),
                                    backgroundColor: Color(0xFF00C853),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Sao chép mảng byte'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (keyCtrl.text.trim().isEmpty) return;
                  final bytes = await ApiKeySecurity.saveAndEncryptNewKey(
                      keyCtrl.text.trim());
                  setDialogState(() => encryptedResult = bytes);
                },
                child: const Text('Mã hóa & Lưu',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answer = ref.watch(geminiAssistantProvider);
    final isLoading =
        answer.contains('Đang lướt tìm') || answer.contains('Đang suy nghĩ');
    Color textColor = const Color(0xFF1A1D26);
    if (answer.contains('❌ LỖI') || answer.contains('Có lỗi')) {
      textColor = Colors.red;
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trợ lý Ẩm thực AI',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1D26),
                        ),
                      ),
                      Text(
                        'Tư vấn quán ngon & thực đơn theo sở thích',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF6C7278)),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Cấu hình API Key',
                  child: IconButton(
                    onPressed: _showApiKeyDialog,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                    ),
                    icon: const Icon(Icons.vpn_key_rounded,
                        color: Colors.purple, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Gợi ý câu hỏi nhanh:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C7278),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _aiSuggestions.map((item) {
                    final label = item['label'] as String;
                    final iconData = item['icon'] as IconData;
                    return ActionChip(
                      avatar: Icon(
                        iconData,
                        size: 16,
                        color: const Color(0xFF6A1B9A),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.purple.shade100),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                      onPressed: () => _sendAIQuery(label),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                if (_lastAiQuestion.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16, left: 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        _lastAiQuestion,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.08),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  color: Colors.purple,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(Icons.auto_awesome,
                                color: Colors.purple, size: 34),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        answer.isEmpty
                            ? 'Xin chào! Bạn đang tìm món ăn hay không gian quán như thế nào? Hãy chọn gợi ý phía trên hoặc nhập yêu cầu bên dưới.'
                            : answer,
                        textAlign:
                            answer.isEmpty ? TextAlign.center : TextAlign.left,
                        style: TextStyle(
                          fontSize: 15,
                          color: isLoading ? Colors.purple : textColor,
                          fontStyle: answer.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontWeight:
                              isLoading ? FontWeight.w600 : FontWeight.normal,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiTextCtrl,
                      onSubmitted: (_) => _sendAIQuery(),
                      decoration: InputDecoration(
                        hintText: 'Nhập yêu cầu tìm quán hoặc món ăn...',
                        filled: true,
                        fillColor: const Color(0xFFF4F6FA),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendAIQuery(),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
