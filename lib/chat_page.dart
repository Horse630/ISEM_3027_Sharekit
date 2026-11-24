import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'catalog_gateway.dart';
import 'chat_center.dart';
import 'text.dart';
import 'widgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.auth,
    required this.itemId,
    required this.itemName,
    required this.ownerName,
    required this.senderName,
    this.center,
  });

  final AuthRepository auth;
  final String itemId;
  final String itemName;
  final String ownerName;
  final String senderName;
  final ChatCenter? center;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  List<ChatMessage> _messages = [];
  Uint8List? _photo;
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
    await widget.center?.markItem(widget.itemId);
  }

  Future<void> _pickPhoto() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (!mounted || bytes == null) return;
    setState(() => _photo = shrinkPhotoBytes(bytes) ?? bytes);
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    final photo = _photo;
    if (body.isEmpty && photo == null) return;
    _text.clear();
    setState(() => _photo = null);
    await widget.auth.sendMessage(
      itemId: widget.itemId,
      sender: widget.senderName,
      body: body,
      photo: photo,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, '聯絡${widget.ownerName}', 'Message ${widget.ownerName}')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              tr(
                context,
                '關於「${widget.itemName}」。可以約好當面交接或郵寄。',
                'About “${widget.itemName}”. Agree a handover here.',
              ),
              style: const TextStyle(color: Color(0xFF5E6A64)),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: Text(tr(context, '正在打開對話…', 'Opening chat…')))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          tr(context, '還沒有訊息。寫一句給物主吧。', 'No messages yet.'),
                        ),
                      )
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
          if (_photo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => showFullPhoto(context, _photo!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_photo!, width: 64, height: 64, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(tr(context, '已附加相片', 'Photo attached')),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.attach_file),
                    tooltip: tr(context, '傳送相片', 'Send a photo'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: InputDecoration(
                        hintText: tr(context, '輸入訊息', 'Message'),
                      ),
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
                    child: Text(tr(context, '送出', 'Send')),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.photo != null)
              GestureDetector(
                onTap: () => showFullPhoto(context, message.photo!),
                child: Padding(
                  padding: EdgeInsets.only(bottom: message.body.isEmpty ? 0 : 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      message.photo!,
                      width: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: TextStyle(
                  color: mine ? Colors.white : const Color(0xFF1B2A24),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
