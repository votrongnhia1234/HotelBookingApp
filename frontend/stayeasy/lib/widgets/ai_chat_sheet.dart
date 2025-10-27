import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/ai_service.dart';

class AiChatSheet extends StatefulWidget {
  const AiChatSheet({super.key});

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  final _controller = TextEditingController();
  final _ai = AiService();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Chào mặc định để tránh màn hình trắng
    _messages.add({
      'role': 'assistant',
      'content':
          'Xin chào! Mình là StayEasy Assistant. Bạn có thể hỏi về phòng, giá, hoặc gợi ý điểm đến. Ví dụ: "Tìm khách sạn ở Đà Nẵng tuần sau".',
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
    });
    try {
      final reply = await _ai.chat(message: text, history: _messages);
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'content': reply});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content':
              'Xin lỗi, đã có lỗi khi trả lời (có thể do quota API). Bạn vui lòng thử lại sau.',
        });
      });
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  Widget _buildMessages(ScrollController? controller) {
    return ListView.separated(
      key: const PageStorageKey('aiChatSheetList'),
      controller: controller,
      padding: const EdgeInsets.all(12),
      reverse: false,
      primary: false,
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = _messages[index];
        final isUser = m['role'] == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF1E88E5) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              m['content'] ?? '',
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetBody(ScrollController? scrollController) {
    final colorScheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Material(
        color: colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'StayEasy Assistant',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildMessages(scrollController)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Nhập tin nhắn... (ví dụ: Tìm khách sạn ở Đà Nẵng tuần sau)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // constrain send button height to avoid layout issues
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send),
                          label: _sending
                              ? const Text('Đang gửi...')
                              : const Text('Gửi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _sheetBody(null);
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (context, scrollController) => _sheetBody(scrollController),
    );
  }
}
