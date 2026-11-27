import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'camera_capture.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'main.dart';
import 'models.dart';
import 'store.dart';
import 'text.dart';
import 'widgets.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final user = AccountScope.of(context).user;
    final bookings = store.bookings
        .where((booking) => store.seesBooking(booking, user.label, user.name))
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            tr(context, '我的預約', 'My bookings'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(tr(context, '取件、歸還和評價都留在同一張預約裡。', 'Pickup, return, and review stay on the same booking.')),
          const SizedBox(height: 16),
          if (bookings.isEmpty)
            Text(tr(context, '你還沒有預約。到探索頁挑一件附近的物品。', 'No bookings yet. Pick an item in Explore.'))
          else
            for (final booking in bookings) ...[
              _BookingCard(bookingId: booking.id),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final booking = store.bookingById(bookingId);
    final item = store.findItem(booking.itemId);
    if (item == null) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookingDetailPage(bookingId: booking.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ItemMark(item: item, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDate(booking.start)} – ${formatDate(booking.end)}',
                      style: const TextStyle(
                        color: Color(0xFF5E6A64),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                stageLabel(context, booking.stage),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF003070),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingDetailPage extends StatelessWidget {
  const BookingDetailPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final booking = store.bookingById(bookingId);
    final item = store.findItem(booking.itemId);
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(booking.id)),
        body: Center(
          child: Text(tr(context, '這件物品已下架。', 'This item was removed.')),
        ),
      );
    }
    final quote = quoteFor(item, booking.start, booking.end);
    final user = AccountScope.of(context).user;
    final isOwner = item.owner == user.label || item.owner == user.name;
    return Scaffold(
      appBar: AppBar(title: Text(booking.id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            item.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            stageLabel(context, booking.stage),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF003070),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(context, '物主 ${item.owner}', 'Owner ${item.owner}'),
            style: const TextStyle(color: Color(0xFF5E6A64)),
          ),
          const SizedBox(height: 18),
          StageTrack(stage: booking.stage),
          const SizedBox(height: 8),
          InfoLine(
            icon: Icons.calendar_today_outlined,
            text:
                '${formatDate(booking.start)} 至 ${formatDate(booking.end)} · ${booking.days} 日',
          ),
          if (booking.note.trim().isNotEmpty && booking.note != '在屋苑會所大堂交接')
            InfoLine(icon: Icons.handshake_outlined, text: booking.note),
          InfoLine(
            icon: Icons.payments_outlined,
            text: quote.free
                ? tr(context, '費用 HK\$0（免費借用，平台不收費）', 'HK\$0. Free to borrow. No platform fee.')
                : tr(
                    context,
                    '租金 ${money(quote.rent)}，平台不另收費',
                    'Rent ${money(quote.rent)}. No platform fee.',
                  ),
          ),
          InfoLine(
            icon: Icons.account_balance_wallet_outlined,
            text: booking.depositAmount <= 0
                ? depositLabel(context, booking.deposit)
                : tr(
                    context,
                    '按金 ${money(booking.depositAmount)} · ${depositLabel(context, booking.deposit)} · 由平台暫存，歸還後退回',
                    'Deposit ${money(booking.depositAmount)} · ${depositLabel(context, booking.deposit)} · held by the platform until return',
                  ),
          ),
          if (booking.issue != null)
            InfoLine(
              icon: Icons.report_outlined,
              text: tr(context, '問題回報：${booking.issue}', 'Issue: ${booking.issue}'),
            ),
          if (booking.stage == BookingStage.reserved && store.codeReady(booking)) ...[
            const SizedBox(height: 8),
            if (isOwner)
              _OwnerCodeCheck(
                code: booking.pickupCode,
                onMatched: () => _ActionBar.handedOver(context, store, booking.id),
              )
            else
              _CodeBox(code: booking.pickupCode),
          ],
          if (!isOwner &&
              booking.stage == BookingStage.pickedUp &&
              booking.returnCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CodeBox(
              code: booking.returnCode,
              titleZh: '歸還碼',
              titleEn: 'Return code',
              hintZh: '歸還時把這組碼或 QR code 給物主核對。',
              hintEn: 'Show this code or QR code when you return the item.',
            ),
          ],
          if (isOwner && booking.stage == BookingStage.pickedUp) ...[
            const SizedBox(height: 8),
            _OwnerReturnCheck(
              code: booking.returnCode,
              onMatched: (photo) => _ActionBar.returned(context, store, booking.id, photo),
            ),
          ],
          if (booking.returnCondition != null)
            InfoLine(
              icon: Icons.assignment_turned_in_outlined,
              text: tr(
                context,
                '歸還狀況：${booking.returnCondition}',
                'Return condition: ${conditionLabel(context, booking.returnCondition ?? '')}',
              ),
            ),
          if ((booking.comment ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, '借用者對物品的評價  ${'★' * (booking.stars ?? 0)}', 'Borrower’s item review  ${'★' * (booking.stars ?? 0)}'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(booking.comment ?? ''),
          ],
          if ((booking.ownerReviewComment ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, '物主對借用者的評價  ${'★' * (booking.ownerReviewStars ?? 0)}', 'Owner’s borrower review  ${'★' * (booking.ownerReviewStars ?? 0)}'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(booking.ownerReviewComment ?? ''),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _reportIssue(context, booking.id),
            child: Text(tr(context, '回報問題', 'Report a problem')),
          ),
          if (booking.deposit == DepositStatus.paid &&
              (booking.stage == BookingStage.returned ||
                  booking.stage == BookingStage.reviewed)) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                store.refundDeposit(booking.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr(context, '付款服務已確認退款。', 'The refund is marked.'))),
                );
              },
              child: Text(tr(context, '確認退款', 'Confirm refund')),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _ActionBar(
        bookingId: booking.id,
        stage: booking.stage,
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.code,
    this.titleZh = '取件碼',
    this.titleEn = 'Pickup code',
    this.hintZh = '把這組碼或 QR code 給物主核對。',
    this.hintEn = 'Show this code or QR code to the owner.',
  });

  final String code;
  final String titleZh;
  final String titleEn;
  final String hintZh;
  final String hintEn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(tr(context, titleZh, titleEn), style: const TextStyle(color: Color(0xFF5E6A64))),
          const SizedBox(height: 12),
          QrImageView(
            data: code,
            size: 180,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(context, hintZh, hintEn),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OwnerCodeCheck extends StatefulWidget {
  const _OwnerCodeCheck({required this.code, required this.onMatched});

  final String code;
  final VoidCallback onMatched;

  @override
  State<_OwnerCodeCheck> createState() => _OwnerCodeCheckState();
}

class _OwnerCodeCheckState extends State<_OwnerCodeCheck> {
  final _entered = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _entered.dispose();
    super.dispose();
  }

  void _check(String raw) {
    if (raw.trim() == widget.code) {
      widget.onMatched();
      return;
    }
    setState(() => _error = tr(context, '取件碼不對。', 'That pickup code is wrong.'));
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PickupScanPage()),
    );
    if (!mounted || scanned == null) return;
    _entered.text = scanned.trim();
    _check(scanned);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, '核對取件碼', 'Check the pickup code'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(tr(
            context,
            '請向借用者索取取件碼。可以手動輸入，或掃描對方的 QR code。',
            'Ask the borrower for the pickup code. Type it, or scan their QR code.',
          )),
          const SizedBox(height: 12),
          TextField(
            controller: _entered,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr(context, '取件碼', 'Pickup code'),
            ),
            onSubmitted: _check,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFF9A4632))),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _check(_entered.text),
            child: Text(tr(context, '核對並確認借出', 'Check and confirm handover')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(tr(context, '掃描 QR code', 'Scan QR code')),
          ),
        ],
      ),
    );
  }
}

class _OwnerReturnCheck extends StatefulWidget {
  const _OwnerReturnCheck({required this.code, required this.onMatched});

  final String code;
  final ValueChanged<Uint8List> onMatched;

  @override
  State<_OwnerReturnCheck> createState() => _OwnerReturnCheckState();
}

class _OwnerReturnCheckState extends State<_OwnerReturnCheck> {
  final _entered = TextEditingController();
  Uint8List? _photo;
  String? _error;

  @override
  void dispose() {
    _entered.dispose();
    super.dispose();
  }

  void _check(String raw) {
    final photo = _photo;
    if (photo == null) {
      setState(() => _error = tr(context, '請先拍攝歸還時的物品現況。', 'Take a photo of the item being returned.'));
      return;
    }
    if (widget.code.isEmpty) {
      setState(() => _error = tr(context, '還沒有歸還碼。', 'There is no return code yet.'));
      return;
    }
    if (raw.trim() != widget.code) {
      setState(() => _error = tr(context, '歸還碼不對。', 'That return code is wrong.'));
      return;
    }
    widget.onMatched(photo);
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PickupScanPage()),
    );
    if (!mounted || scanned == null) return;
    _entered.text = scanned.trim();
    _check(scanned);
  }

  Future<void> _shoot() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => CameraCapturePage(title: tr(context, '拍攝歸還現況', 'Photograph the return')),
      ),
    );
    if (!mounted || bytes == null) return;
    setState(() {
      _photo = bytes;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, '核對歸還', 'Check the return'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(tr(
            context,
            '請輸入或掃描借用者的歸還碼，並拍攝物品現況。沒有照片不能確認歸還。',
            'Enter or scan the borrower’s return code, and photograph the item. A photo is required.',
          )),
          const SizedBox(height: 12),
          if (_photo != null)
            GestureDetector(
              onTap: () => showFullPhoto(context, _photo!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_photo!, height: 140, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _shoot,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_photo == null ? tr(context, '拍攝歸還現況', 'Photograph the return') : tr(context, '重新拍攝', 'Retake')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _entered,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr(context, '歸還碼', 'Return code')),
            onSubmitted: _check,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFF9A4632))),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _check(_entered.text),
            child: Text(tr(context, '核對並確認歸還', 'Check and confirm return')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(tr(context, '掃描 QR code', 'Scan QR code')),
          ),
        ],
      ),
    );
  }
}

class PickupScanPage extends StatefulWidget {
  const PickupScanPage({super.key});

  @override
  State<PickupScanPage> createState() => _PickupScanPageState();
}

class _PickupScanPageState extends State<PickupScanPage> {
  var _done = false;

  void _found(String? raw) {
    final code = raw?.trim() ?? '';
    if (_done || code.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, '掃描取件碼', 'Scan pickup code'))),
      body: MobileScanner(
        onDetect: (capture) => _found(capture.barcodes.firstOrNull?.rawValue),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.bookingId, required this.stage});

  final String bookingId;
  final BookingStage stage;

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final booking = store.bookingById(bookingId);
    final user = AccountScope.of(context).user;
    final item = store.findItem(booking.itemId);
    final isOwner = item != null && (item.owner == user.label || item.owner == user.name);
    if (!isOwner && store.needsOnlinePayment(booking)) {
      return _bar(
        context,
        '完成付款',
        'Pay now',
        () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DepositPage(bookingId: bookingId)),
          );
        },
      );
    }
    final returned = booking.stage == BookingStage.returned || booking.stage == BookingStage.reviewed;
    final canReviewItem = returned && (booking.comment ?? '').trim().isEmpty &&
        store.isBorrower(booking, user.label, user.name);
    final canReviewBorrower = returned && booking.borrower.isNotEmpty &&
        (booking.ownerReviewComment ?? '').trim().isEmpty;
    if (!isOwner) {
      if (!canReviewItem) return const SizedBox.shrink();
      return _bar(context, '評價物品', 'Review item', () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReviewPage(bookingId: bookingId)),
        );
      });
    }
    final (zh, en, action) = switch (booking.stage) {
      BookingStage.returned || BookingStage.reviewed when canReviewBorrower => (
        '評價借用者',
        'Review borrower',
        () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReviewPage(bookingId: bookingId)),
          );
        },
      ),
      _ => (null, null, null),
    };
    if (zh == null || en == null || action == null) return const SizedBox.shrink();
    return _bar(context, zh, en, action);
  }

  Widget _bar(BuildContext context, String zh, String en, Future<void> Function() action) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton(
          onPressed: () {
            action();
          },
          child: Text(tr(context, zh, en)),
        ),
      ),
    );
  }

  static Future<void> handedOver(BuildContext context, ShareStore store, String bookingId) async {
    store.markPickedUp(bookingId);
    final booking = store.bookingById(bookingId);
    final owner = store.findItem(booking.itemId)?.owner ?? '';
    await AccountScope.of(context).auth.sendMessage(
      itemId: booking.itemId,
      sender: owner,
      body: both('物主已核對取件碼並確認交件。', 'The owner checked the pickup code and confirmed the handover.'),
      kind: 'rented',
      bookingId: booking.id,
    );
  }

  static Future<void> returned(
    BuildContext context,
    ShareStore store,
    String bookingId,
    Uint8List photo,
  ) async {
    store.markReturned(bookingId, '完好', photo: photo);
    final booking = store.bookingById(bookingId);
    final owner = store.findItem(booking.itemId)?.owner ?? '';
    await AccountScope.of(context).auth.sendMessage(
      itemId: booking.itemId,
      sender: owner,
      body: both(
        '已確認歸還。可以留下評價，也可以不寫。',
        'Return confirmed. A review is optional.',
      ),
      kind: 'returned',
      bookingId: booking.id,
    );
  }

  Future<void> _returnSheet(BuildContext context) async {
    final store = ShareKitScope.of(context);
    var condition = '完好';
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, '歸還時的狀況', 'Condition on return'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const ['完好', '有輕微使用痕跡', '需要物主再檢查'])
                        ChoiceChip(
                          label: Text(conditionLabel(context, option)),
                          selected: condition == option,
                          onSelected: (_) => setModalState(() => condition = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, condition),
                    child: Text(tr(context, '完成歸還', 'Finish return')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected == null) return;
    store.markReturned(bookingId, selected);
  }
}

Future<void> _reportIssue(BuildContext context, String bookingId) async {
  final detail = TextEditingController();
  var kind = '損壞';
  final text = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, '回報問題', 'Report a problem'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in const ['損壞', '逾期歸還', '其他'])
                      ChoiceChip(
                        label: Text(switch (option) {
                          '損壞' => tr(context, '損壞', 'Damage'),
                          '逾期歸還' => tr(context, '逾期歸還', 'Late return'),
                          _ => tr(context, '其他', 'Other'),
                        }),
                        selected: kind == option,
                        onSelected: (_) => setModalState(() => kind = option),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detail,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: tr(context, '發生了什麼事', 'What happened')),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    final note = detail.text.trim();
                    Navigator.pop(
                      context,
                      note.isEmpty ? kind : '$kind：$note',
                    );
                  },
                  child: Text(tr(context, '送出回報', 'Send report')),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  detail.dispose();
  if (text == null || !context.mounted) return;
  ShareKitScope.of(context).reportIssue(bookingId, text);
}

class DepositPage extends StatelessWidget {
  const DepositPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final booking = store.bookingById(bookingId);
    final item = store.findItem(booking.itemId);
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, '付款', 'Payment'))),
        body: Center(child: Text(tr(context, '這件物品已下架。', 'This item was removed.'))),
      );
    }
    final quote = quoteFor(item, booking.start, booking.end);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, '付款', 'Payment'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            item.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              booking.depositAmount > 0
                  ? '按金由平台暫存，歸還後退回。租金若選線上付款，會一併支付；若選當面付款，租金稍後交給物主。'
                  : '這是付給物主的租金，平台不另收費。確認後會標記為已付。',
              booking.depositAmount > 0
                  ? 'The platform holds the deposit and returns it after the item comes back. Online rent is paid here. In-person rent is paid to the owner later.'
                  : 'This rent goes to the owner. The platform adds no fee.',
            ),
          ),
          const SizedBox(height: 16),
          if (!quote.free && booking.payMethod == PayMethod.online)
            Text(tr(context, '租金 ${money(quote.rent)}', 'Rent ${money(quote.rent)}')),
          if (booking.depositAmount > 0)
            Text(tr(
              context,
              '按金 ${money(booking.depositAmount)}（平台暫存）',
              'Deposit ${money(booking.depositAmount)} (held by the platform)',
            )),
          const SizedBox(height: 8),
          Text(
            money(
              (booking.payMethod == PayMethod.online && !quote.free ? quote.rent : 0) +
                  booking.depositAmount,
            ),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              store.payDeposit(bookingId);
              final latest = store.bookingById(bookingId);
              await AccountScope.of(context).auth.sendMessage(
                itemId: latest.itemId,
                sender: latest.borrower,
                body: [
                  if (latest.payMethod == PayMethod.online && !quote.free)
                    both('租金已付。', 'The rent is paid.'),
                  if (latest.depositAmount > 0)
                    both(
                      '按金 ${money(latest.depositAmount)} 已付，由平台暫存。',
                      'Deposit ${money(latest.depositAmount)} is paid and held by the platform.',
                    ),
                  both('請到預約頁向物主出示取件碼。', 'Open the booking page and show the pickup code to the owner.'),
                ].join('\n'),
                kind: 'code',
                bookingId: latest.id,
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(tr(context, '確認付款', 'Confirm payment')),
          ),
        ],
      ),
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _stars = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final comment = _comment.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, '請先填寫評價內容。', 'Please write a review.')),
      ));
      return;
    }
    final user = AccountScope.of(context).user;
    final saved = ShareKitScope.of(context).saveReview(
      widget.bookingId, _stars, comment,
      reviewerLabel: user.label, reviewerLogin: user.name,
    );
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, '無法送出評價，請檢查預約狀態。', 'Could not submit this review. Check the booking status.')),
      ));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final booking = ShareKitScope.of(context).bookingById(widget.bookingId);
    final item = ShareKitScope.of(context).itemById(booking.itemId);
    final user = AccountScope.of(context).user;
    final isOwner = item.owner == user.label || item.owner == user.name;
    return Scaffold(
      appBar: AppBar(title: Text(isOwner ? tr(context, '評價借用者', 'Review borrower') : tr(context, '評價物品', 'Review item'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            isOwner ? booking.borrower : item.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(isOwner
              ? tr(context, '這則評價會顯示在借用者的個人資料。', 'This review appears on the borrower’s profile.')
              : tr(context, '這則評價會顯示在物品頁。', 'This review appears on the item page.')),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  onPressed: () => setState(() => _stars = star),
                  icon: Icon(
                    star <= _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFC9891F),
                    size: 36,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _comment,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: isOwner
                  ? tr(context, '例如：準時歸還，愛惜物品。', 'For example: Returned on time and took care of the item.')
                  : tr(context, '例如：取件準時，電鑽電量充足。', 'For example: Pickup was on time.'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: Text(tr(context, '送出評價', 'Send review')),
          ),
        ],
      ),
    );
  }
}
