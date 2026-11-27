import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'booking_pages.dart';
import 'catalog_gateway.dart';
import 'chat_center.dart';
import 'main.dart';
import 'models.dart';
import 'store.dart';
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
    this.store,
  });

  final AuthRepository auth;
  final String itemId;
  final String itemName;
  final String ownerName;
  final String senderName;
  final ChatCenter? center;
  final ShareStore? store;

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
                '關於「${widget.itemName}」。可以約好當面交接。',
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
                              isOwner: widget.senderName == widget.ownerName,
                              store: widget.store,
                              auth: widget.auth,
                              onChanged: _load,
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

ButtonStyle _chatButton({required bool filled}) {
  const size = Size(156, 52);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  final text = const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  if (filled) {
    return FilledButton.styleFrom(
      minimumSize: size,
      maximumSize: size,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: text,
      shape: shape,
    );
  }
  return OutlinedButton.styleFrom(
    minimumSize: size,
    maximumSize: size,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    textStyle: text,
    shape: shape,
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.isOwner,
    required this.auth,
    required this.onChanged,
    this.store,
  });

  final ChatMessage message;
  final bool mine;
  final bool isOwner;
  final ShareStore? store;
  final AuthRepository auth;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final actions = _actions(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: mine ? const Color(0xFF003070) : Colors.white,
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
                          child: Image.memory(message.photo!, width: 220, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  if (message.body.isNotEmpty)
                    Text(
                      message.body,
                      style: TextStyle(color: mine ? Colors.white : const Color(0xFF1B2A24)),
                    ),
                ],
              ),
            ),
          ),
          if (actions != null) ...[
            const SizedBox(height: 6),
            actions,
          ],
        ],
      ),
    );
  }

  Widget? _actions(BuildContext context) {
    final catalog = store;
    if (catalog == null || message.bookingId.isEmpty) return null;
    Booking? booking;
    for (final item in catalog.bookings) {
      if (item.id == message.bookingId) booking = item;
    }
    if (booking == null) return null;
    if (message.kind == 'request' && isOwner && booking.stage == BookingStage.requested) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            style: _chatButton(filled: true),
            onPressed: () => _accept(context, catalog, booking!),
            child: Text(tr(context, '同意', 'Accept')),
          ),
          OutlinedButton(
            style: _chatButton(filled: false),
            onPressed: () => _reject(context, catalog, booking!),
            child: Text(tr(context, '拒絕', 'Reject')),
          ),
        ],
      );
    }
    if (message.kind == 'pay' && !isOwner && catalog.needsOnlinePayment(booking)) {
      return FilledButton(
        style: _chatButton(filled: true),
        onPressed: () => _openBooking(context, booking!.id),
        child: Text(tr(context, '前往付款', 'Open payment')),
      );
    }
    if (message.kind == 'code' &&
        isOwner &&
        booking.stage == BookingStage.reserved &&
        catalog.codeReady(booking)) {
      return FilledButton(
        style: _chatButton(filled: true),
        onPressed: () => _openBooking(context, booking!.id),
        child: Text(tr(context, '前往確認借出', 'Open handover')),
      );
    }
    if (message.kind == 'rented' && isOwner && booking.stage == BookingStage.pickedUp) {
      return FilledButton(
        style: _chatButton(filled: true),
        onPressed: () => _openBooking(context, booking!.id),
        child: Text(tr(context, '前往確認歸還', 'Open return')),
      );
    }
    final user = AccountScope.of(context).user;
    if (message.kind == 'returned' &&
        (booking.stage == BookingStage.returned || booking.stage == BookingStage.reviewed) &&
        (isOwner
            ? booking.borrower.isNotEmpty && (booking.ownerReviewComment ?? '').trim().isEmpty
            : catalog.isBorrower(booking, user.label, user.name) &&
                (booking.comment ?? '').trim().isEmpty)) {
      return FilledButton(
        style: _chatButton(filled: true),
        onPressed: () => _openBooking(context, booking!.id),
        child: Text(tr(context, '前往評價', 'Open review')),
      );
    }
    return null;
  }

  void _openBooking(BuildContext context, String bookingId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingDetailPage(bookingId: bookingId)),
    );
  }

  String _owner(ShareStore catalog, Booking booking) {
    return catalog.findItem(booking.itemId)?.owner ?? '';
  }

  Future<void> _accept(BuildContext context, ShareStore catalog, Booking booking) async {
    catalog.acceptBooking(booking.id);
    final latest = catalog.bookingById(booking.id);
    final needsPay = catalog.needsOnlinePayment(latest);
    await auth.sendMessage(
      itemId: booking.itemId,
      sender: _owner(catalog, booking),
      body: [
        both('物主已同意這次租借。', 'The owner accepted this rental.'),
        if (needsPay)
          both('請到預約頁完成付款。', 'Open the booking page to pay.')
        else
          '交接碼 / Exchange code：${latest.pickupCode}',
      ].join('\n'),
      kind: needsPay ? 'pay' : 'code',
      bookingId: booking.id,
    );
    await onChanged();
  }

  Future<void> _reject(BuildContext context, ShareStore catalog, Booking booking) async {
    final reason = TextEditingController();
    final why = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, '為什麼拒絕？', 'Why reject?')),
        content: TextField(
          controller: reason,
          decoration: InputDecoration(hintText: tr(context, '可以留空', 'You can leave this blank')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, '取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reason.text.trim()),
            child: Text(tr(context, '拒絕', 'Reject')),
          ),
        ],
      ),
    );
    reason.dispose();
    if (why == null) return;
    catalog.rejectBooking(booking.id, why);
    await auth.sendMessage(
      itemId: booking.itemId,
      sender: _owner(catalog, booking),
      body: [
        both('你的租借已被拒絕。', 'Your rental was rejected.'),
        if (why.isNotEmpty) '原因 / Reason：$why',
      ].join('\n'),
      kind: 'rejected',
      bookingId: booking.id,
    );
    await onChanged();
  }
}
