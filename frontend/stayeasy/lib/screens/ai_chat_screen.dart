import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _ai = AiService();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;
  bool _started = false; // bắt đầu hội thoại sau lần gửi đầu tiên

  @override
  void initState() {
    super.initState();
    // Không thêm tin nhắn mặc định để hiển thị màn hình chào
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    // Ẩn bàn phím để tránh nhảy layout gây trắng màn hình
    FocusScope.of(context).unfocus();
    setState(() {
      // Chuyển sang màn hình chat ngay để tránh màn hình trắng
      _sending = true;
      _started = true;
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
    });
    try {
      final reply = await _ai.chat(message: text, history: _messages);
      if (!mounted) return; // tránh setState sau khi rời màn hình
      setState(() {
        _messages.add({'role': 'assistant', 'content': reply});
      });
    } catch (e) {
      if (!mounted) return; // tránh setState sau khi rời màn hình
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Xin lỗi, đã có lỗi khi trả lời. Vui lòng thử lại. ($e)',
        });
      });
    } finally {
      if (!mounted) return; // tránh setState sau khi rời màn hình
      setState(() => _sending = false);
    }
  }

  // Hiển thị danh sách tin nhắn dạng bong bóng
  Widget _buildMessages() {
    return ListView.builder(
      key: const PageStorageKey('aiChatList'),
      padding: const EdgeInsets.all(12),
      primary: true,
      shrinkWrap: false,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _messages.length,
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

  // Màn hình chào: đơn giản và an toàn về layout
  Widget _buildWelcome() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Xin chào! Mình là StayEasy Assistant. Hãy nhập câu hỏi để bắt đầu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ví dụ: "Tìm khách sạn ở Đà Nẵng tuần sau" hoặc "Gợi ý phòng phù hợp cho gia đình 4 người".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Nhập câu hỏi của bạn...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.play_arrow),
                        label: _sending
                            ? const Text('Đang xử lý...')
                            : const Text('Bắt đầu'),
                      ),
                    ),
                  ),
                ),
                if (_sending) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showWelcome = !_started; // chỉ hiển thị chào trước khi gửi lần đầu
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('StayEasy Assistant')),
      body: showWelcome
          ? _buildWelcome()
          : Column(
              children: [
                Expanded(child: _buildMessages()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                        Flexible(
                          fit: FlexFit.loose,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints.tightFor(
                              height: 48,
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _sending
                                  ? null
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      _send();
                                    },
                              icon: const Icon(Icons.send),
                              label: _sending
                                  ? const Text('Đang gửi...')
                                  : const Text('Gửi'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
