import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_repository.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.auth,
    required this.itemId,
    required this.itemName,
    required this.ownerName,
    required this.senderName,
  });

  final AuthRepository auth;
  final String itemId;
  final String itemName;
  final String ownerName;
  final String senderName;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  List<ChatMessage> _messages = [];
  var _loading = true;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final messages = await widget.auth.messagesFor(widget.itemId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    _text.clear();
    await widget.auth.sendMessage(
      itemId: widget.itemId,
      sender: widget.senderName,
      body: body,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('聯絡${widget.ownerName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              '關於「${widget.itemName}」。可以約好當面交接或郵寄。',
              style: const TextStyle(color: Color(0xFF5E6A64)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: Text('正在打開對話…'))
                : _messages.isEmpty
                    ? const Center(child: Text('還沒有訊息。寫一句給物主吧。'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                          for (final message in _messages)
                            _Bubble(
                              message: message,
                              mine: message.sender == widget.senderName,
                            ),
                        ],
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(hintText: '輸入訊息'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 52),
                      maximumSize: const Size(96, 52),
                    ),
                    onPressed: _send,
                    child: const Text('送出'),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF0E6B52) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.body,
          style: TextStyle(color: mine ? Colors.white : const Color(0xFF1B2A24)),
        ),
      ),
    );
  }
}
