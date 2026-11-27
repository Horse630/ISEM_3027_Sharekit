import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'booking_pages.dart';
import 'item_pages.dart';
import 'catalog_gateway.dart';
import 'chat_center.dart';
import 'main.dart';
import 'models.dart';
import 'store.dart';
import 'text.dart';
import 'widgets.dart';

const supportServiceName = 'Customer service';
const legacySupportServiceName = 'Customary service';

bool isSupportStaff(String sender) =>
    sender == supportServiceName || sender == legacySupportServiceName;

String supportSenderLabel(String sender) =>
    isSupportStaff(sender) ? supportServiceName : sender;

String supportItemId(String login) => 'support-$login';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.auth,
    required this.itemId,
    required this.itemName,
    required this.ownerName,
    required this.senderName,
    this.clientName,
    this.center,
    this.store,
  });

  final AuthRepository auth;
  final String itemId;
  final String itemName;
  final String ownerName;
  final String senderName;
  final String? clientName;
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

  bool get _support => widget.ownerName == supportServiceName;

  Future<void> _load() async {
    final messages = await widget.auth.messagesFor(widget.itemId);
    if (!mounted) return;
    if (_support && !messages.any((message) => isSupportStaff(message.sender))) {
      await widget.auth.sendMessage(
        itemId: widget.itemId,
        sender: supportServiceName,
        body: tr(
          context,
          '你好，這裡是 Customer service。請告訴我們你的問題：你當時想做什麼，以及發生了什麼。我們會看你的訊息並協助。',
          'Hello, this is Customer service. Please tell us your problem: what you were trying to do, and what went wrong. We will read your message and help.',
        ),
      );
      return _load();
    }
    final mine = _support
        ? messages
        : conversationOf(
            messages: messages,
            owner: widget.ownerName,
            client: widget.clientName ?? widget.senderName,
          );
    if (!mounted) return;
    setState(() {
      _messages = mine;
      _loading = false;
    });
    await widget.center?.markThread(
      widget.itemId,
      widget.clientName ?? widget.senderName,
      ids: mine.map((message) => message.id),
    );
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
    if (!mounted) return;
    if (_support && widget.senderName != supportServiceName) {
      await widget.auth.sendMessage(
        itemId: widget.itemId,
        sender: supportServiceName,
        body: tr(
          context,
          '我們已收到你的訊息。Customer service 會盡快有人聯絡你。',
          'We have received your message. Someone from Customer service will contact you soon.',
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            PersonAvatar(
              auth: widget.auth,
              name: _support
                  ? supportServiceName
                  : (widget.senderName == widget.ownerName
                      ? (widget.clientName ?? '')
                      : widget.ownerName),
              appIcon: _support,
              onTap: _support
                  ? null
                  : () {
                      final catalog = widget.store;
                      if (catalog == null) return;
                      final person = widget.senderName == widget.ownerName
                          ? (widget.clientName ?? '')
                          : widget.ownerName;
                      showPersonReviews(context, catalog, person);
                    },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _support
                    ? supportServiceName
                    : tr(context, '聯絡${widget.ownerName}', 'Message ${widget.ownerName}'),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              _support
                  ? tr(
                      context,
                      '請在下面說明你的問題。',
                      'Describe your problem below.',
                    )
                  : tr(
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
                              thread: _messages,
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
                  if (!_support && widget.store != null)
                    IconButton(
                      onPressed: () {
                        final catalog = widget.store!;
                        final choices = catalog.items
                            .where((item) => item.owner == widget.ownerName)
                            .toList();
                        final current = catalog.findItem(widget.itemId);
                        if (current != null && choices.every((item) => item.id != current.id)) {
                          choices.insert(0, current);
                        }
                        if (choices.isEmpty) return;
                        showPriceOfferDialog(
                          context,
                          store: catalog,
                          auth: widget.auth,
                          sender: widget.senderName,
                          choices: choices,
                          initialId: widget.itemId,
                        ).then((_) => _load());
                      },
                      icon: const Icon(Icons.sell_outlined),
                      tooltip: tr(context, '提議租金和按金', 'Propose rent and deposit'),
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
    required this.thread,
    required this.mine,
    required this.isOwner,
    required this.auth,
    required this.onChanged,
    this.store,
  });

  final ChatMessage message;
  final List<ChatMessage> thread;
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
                      message.body
                          .split('\n')
                          .where((line) => !line.startsWith('#offer '))
                          .join('\n')
                          .replaceAll(legacySupportServiceName, supportServiceName)
                          .replaceAll('列表上的原價不會改變。', '')
                          .replaceAll(' The listed price stays the same.', ''),
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
    if (catalog != null && message.kind == 'offer-book' && !isOwner) {
      final offer = _readOffer(message.body);
      return FilledButton(
        style: _chatButton(filled: true),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookPage(
                itemId: message.itemId,
                useAgreed: true,
                agreedDaily: offer?.$1,
                agreedDeposit: offer?.$2 ?? 0,
              ),
            ),
          );
        },
        child: Text(tr(context, '前往確認預約', 'Confirm booking')),
      );
    }
    if (catalog != null && message.kind == 'offer' && !mine && _offerOpen()) {
      final offer = _readOffer(message.body);
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            style: _chatButton(filled: true),
            onPressed: offer == null ? null : () => _decideOffer(context, catalog, accept: true, offer: offer),
            child: Text(tr(context, '同意', 'Accept')),
          ),
          OutlinedButton(
            style: _chatButton(filled: false),
            onPressed: () => _decideOffer(context, catalog, accept: false, offer: (0, 0)),
            child: Text(tr(context, '拒絕', 'Decline')),
          ),
        ],
      );
    }
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

  bool _offerOpen() {
    final key = message.id.toString();
    return !thread.any(
      (item) =>
          (item.kind == 'offer-yes' || item.kind == 'offer-no' || item.kind == 'offer-book') &&
          item.bookingId == key,
    );
  }

  Future<void> _decideOffer(
    BuildContext context,
    ShareStore catalog, {
    required bool accept,
    required (double?, double) offer,
  }) async {
    final user = AccountScope.of(context).user;
    final owner = catalog.findItem(message.itemId)?.owner ?? '';
    final fromOwner = user.label == owner || user.name == owner;
    final rentText = offer.$1 == null ? '' : offer.$1.toString();
    await auth.sendMessage(
      itemId: message.itemId,
      sender: user.label,
      body: accept
          ? [
              both(
                '已同意新的租金和按金。請借用者到預約頁確認預約，物主仍須同意這次租借。',
                'The new rent and deposit are agreed. The borrower should open the booking page to confirm. The owner still needs to accept it.',
              ),
              '#offer rent=$rentText deposit=${offer.$2}',
            ].join('\n')
          : (fromOwner
              ? both('物主已拒絕這次提議。', 'The owner declined this offer.')
              : both('借用者已拒絕這次提議。', 'The borrower declined this offer.')),
      kind: accept ? 'offer-book' : 'offer-no',
      bookingId: message.id.toString(),
    );
    await onChanged();
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
          both('請到預約頁向物主出示取件碼。', 'Open the booking page and show the pickup code to the owner.'),
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

List<ChatMessage> conversationOf({
  required List<ChatMessage> messages,
  required String owner,
  required String client,
}) {
  final sorted = [...messages]..sort((a, b) => a.id.compareTo(b.id));
  String? current;
  final kept = <ChatMessage>[];
  for (final message in sorted) {
    if (message.sender != owner) current = message.sender;
    if (current == client) kept.add(message);
  }
  return kept;
}

(double?, double)? _readOffer(String body) {
  for (final line in body.split('\n')) {
    if (!line.startsWith('#offer ')) continue;
    double? rent;
    var deposit = 0.0;
    for (final part in line.substring(7).split(' ')) {
      final bits = part.split('=');
      if (bits.length != 2) continue;
      if (bits[0] == 'rent') {
        rent = bits[1].isEmpty ? null : double.tryParse(bits[1]);
      } else if (bits[0] == 'deposit') {
        deposit = double.tryParse(bits[1]) ?? 0;
      }
    }
    return (rent, deposit);
  }
  return null;
}

Future<void> showPriceOfferDialog(
  BuildContext context, {
  required ShareStore store,
  required AuthRepository auth,
  required String sender,
  required List<ShareItem> choices,
  String? initialId,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _PriceOfferDialog(
      store: store,
      auth: auth,
      sender: sender,
      choices: choices,
      initialId: initialId ?? choices.first.id,
    ),
  );
}

class _PriceOfferDialog extends StatefulWidget {
  const _PriceOfferDialog({
    required this.store,
    required this.auth,
    required this.sender,
    required this.choices,
    required this.initialId,
  });

  final ShareStore store;
  final AuthRepository auth;
  final String sender;
  final List<ShareItem> choices;
  final String initialId;

  @override
  State<_PriceOfferDialog> createState() => _PriceOfferDialogState();
}

class _PriceOfferDialogState extends State<_PriceOfferDialog> {
  late String _itemId = widget.choices.any((item) => item.id == widget.initialId)
      ? widget.initialId
      : widget.choices.first.id;
  final _price = TextEditingController();
  final _deposit = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _price.dispose();
    _deposit.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    double? rent;
    if (_price.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_price.text.trim());
      if (parsed == null || parsed < 0) {
        setState(() => _error = tr(context, '租金請填數字，或留空代表免費。', 'Enter a number for the rent, or leave it blank for free.'));
        return;
      }
      rent = parsed == 0 ? null : parsed;
    }
    var deposit = 0.0;
    if (_deposit.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_deposit.text.trim());
      if (parsed == null || parsed < 0) {
        setState(() => _error = tr(context, '按金請填數字，或留空代表不用按金。', 'Enter a number for the deposit, or leave it blank.'));
        return;
      }
      deposit = parsed;
    }
    final item = widget.choices.firstWhere((entry) => entry.id == _itemId);
    final rentText = rent == null ? '免費 / Free' : money(rent);
    setState(() => _busy = true);
    await widget.auth.sendMessage(
      itemId: item.id,
      sender: widget.sender,
      body: [
        both('提議新租金與按金', 'Proposed rent and deposit'),
        '物品 / Item：${item.name}',
        '租金 / Rent：$rentText',
        '按金 / Deposit：${money(deposit)}',
        '#offer rent=${rent ?? ''} deposit=$deposit',
      ].join('\n'),
      kind: 'offer',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, '提議新租金和按金', 'Propose rent and deposit')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _itemId,
              decoration: InputDecoration(labelText: tr(context, '借用物品', 'Item to borrow')),
              items: [
                for (final item in widget.choices)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: _busy ? null : (value) {
                if (value == null) return;
                setState(() => _itemId = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr(context, '提議每日租金（可留空）', 'Proposed daily rent, optional')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deposit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr(context, '提議按金（可留空）', 'Proposed deposit, optional')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFF9A4632))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(tr(context, '取消', 'Cancel')),
        ),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: Text(tr(context, '送出', 'Send')),
        ),
      ],
    );
  }
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.auth,
    required this.name,
    this.onTap,
    this.appIcon = false,
  });

  final AuthRepository auth;
  final String name;
  final VoidCallback? onTap;
  final bool appIcon;

  @override
  Widget build(BuildContext context) {
    final image = appIcon
        ? const AssetImage('assets/app_icon.png')
        : null;
    return GestureDetector(
      onTap: appIcon || name.trim().isEmpty ? null : onTap,
      child: FutureBuilder<Uint8List?>(
        future: appIcon ? Future<Uint8List?>.value() : auth.photoForName(name),
        builder: (context, snapshot) {
          final photo = snapshot.data;
          return CircleAvatar(
            backgroundColor: const Color(0xFF003070).withValues(alpha: 0.12),
            backgroundImage: image ?? (photo == null ? null : MemoryImage(photo)),
            child: image == null && photo == null
                ? const Icon(Icons.person_outline, color: Color(0xFF003070))
                : null,
          );
        },
      ),
    );
  }
}

void showPersonReviews(BuildContext context, ShareStore store, String name) {
  final person = name.trim();
  if (person.isEmpty) return;
  final reviews = store.reviewsAbout(person);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr(dialogContext, '$person 的評價', 'Reviews of $person')),
      content: SizedBox(
        width: 360,
        child: reviews.isEmpty
            ? Text(tr(dialogContext, '暫時沒有其他人給的評價。', 'No reviews from other people yet.'))
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final review in reviews)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_reviewTitle(dialogContext, store, review, person)),
                      subtitle: Text(_reviewBody(store, review, person)),
                      isThreeLine: true,
                    ),
                ],
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(tr(dialogContext, '關閉', 'Close')),
        ),
      ],
    ),
  );
}

String _reviewTitle(BuildContext context, ShareStore store, Booking review, String person) {
  final item = store.findItem(review.itemId);
  final aboutOwner = item != null && item.owner == person;
  final author = aboutOwner
      ? (review.borrower.isEmpty ? tr(context, '借用者', 'Borrower') : review.borrower)
      : (review.ownerReviewAuthor ?? item?.owner ?? tr(context, '物主', 'Owner'));
  final stars = aboutOwner ? (review.stars ?? 0) : (review.ownerReviewStars ?? 0);
  return '${'★' * stars}  $author';
}

String _reviewBody(ShareStore store, Booking review, String person) {
  final itemName = store.findItem(review.itemId)?.name ?? review.itemId;
  final aboutBorrower = review.borrower == person || review.borrowerAccount == person;
  final text = aboutBorrower ? (review.ownerReviewComment ?? '') : (review.comment ?? '');
  return '$itemName\n$text';
}
