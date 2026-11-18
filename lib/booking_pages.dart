import 'package:flutter/material.dart';

import 'main.dart';
import 'models.dart';
import 'widgets.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final bookings = store.bookings;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            '我的預約',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('取件、歸還和評價都留在同一張預約裡。'),
          const SizedBox(height: 16),
          if (bookings.isEmpty)
            const Text('你還沒有預約。到探索頁挑一件附近的物品。')
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
    final item = store.itemById(booking.itemId);
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
                booking.stage.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E6B52),
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
    final item = store.itemById(booking.itemId);
    final quote = quoteFor(item, booking.start, booking.end);
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
            booking.stage.label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0E6B52),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '物主 ${item.owner}',
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
          InfoLine(icon: Icons.handshake_outlined, text: booking.note),
          InfoLine(
            icon: Icons.payments_outlined,
            text: quote.free
                ? '費用 HK\$0（免費借用）'
                : '費用 ${money(quote.total)}（租金 ${money(quote.rent)} + 服務費 ${money(quote.serviceFee)}）',
          ),
          InfoLine(icon: Icons.account_balance_wallet_outlined, text: booking.deposit.label),
          if (booking.issue != null)
            InfoLine(icon: Icons.report_outlined, text: '問題回報：${booking.issue}'),
          if (booking.stage == BookingStage.reserved &&
              booking.deposit != DepositStatus.pending) ...[
            const SizedBox(height: 8),
            _CodeBox(code: booking.pickupCode),
          ],
          if (booking.returnCondition != null)
            InfoLine(
              icon: Icons.assignment_turned_in_outlined,
              text: '歸還狀況：${booking.returnCondition}',
            ),
          if (booking.stage == BookingStage.reviewed) ...[
            const SizedBox(height: 8),
            Text(
              '你的評價  ${'★' * (booking.stars ?? 0)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(booking.comment ?? ''),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _reportIssue(context, booking.id),
            child: const Text('回報問題'),
          ),
          if (booking.deposit == DepositStatus.paid &&
              (booking.stage == BookingStage.returned ||
                  booking.stage == BookingStage.reviewed)) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                store.refundDeposit(booking.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('付款服務已確認退款。')),
                );
              },
              child: const Text('確認退款'),
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
  const _CodeBox({required this.code});

  final String code;

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
          const Text('取件碼', style: TextStyle(color: Color(0xFF5E6A64))),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 4),
          const Text('交給物主核對，然後在下面確認已取件。', textAlign: TextAlign.center),
        ],
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
    if (booking.stage == BookingStage.reserved &&
        booking.deposit == DepositStatus.pending) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DepositPage(bookingId: bookingId),
                ),
              );
            },
            child: const Text('支付按金'),
          ),
        ),
      );
    }
    final (label, action) = switch (stage) {
      BookingStage.reserved => ('確認已取件', () => store.markPickedUp(bookingId)),
      BookingStage.pickedUp => ('確認歸還', () => _returnSheet(context)),
      BookingStage.returned => (
        '撰寫評價',
        () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReviewPage(bookingId: bookingId)),
          );
        },
      ),
      BookingStage.reviewed => (null, null),
    };
    if (label == null || action == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton(onPressed: action, child: Text(label)),
      ),
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
                  const Text(
                    '歸還時的狀況',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const ['完好', '有輕微使用痕跡', '需要物主再檢查'])
                        ChoiceChip(
                          label: Text(option),
                          selected: condition == option,
                          onSelected: (_) => setModalState(() => condition = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, condition),
                    child: const Text('完成歸還'),
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
                const Text(
                  '回報問題',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in const ['損壞', '逾期歸還', '其他'])
                      ChoiceChip(
                        label: Text(option),
                        selected: kind == option,
                        onSelected: (_) => setModalState(() => kind = option),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detail,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '發生了什麼事'),
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
                  child: const Text('送出回報'),
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
    final item = store.itemById(booking.itemId);
    final quote = quoteFor(item, booking.start, booking.end);
    return Scaffold(
      appBar: AppBar(title: const Text('按金付款')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            item.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('付款會交給付款服務。確認後，這筆按金會標記為已付。'),
          const SizedBox(height: 16),
          Text(
            '按金 ${money(quote.total)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              store.payDeposit(bookingId);
              Navigator.of(context).pop();
            },
            child: const Text('確認付款'),
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
    if (_comment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請寫一句使用感受。')));
      return;
    }
    ShareKitScope.of(context)
        .saveReview(widget.bookingId, _stars, _comment.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final booking = ShareKitScope.of(context).bookingById(widget.bookingId);
    final item = ShareKitScope.of(context).itemById(booking.itemId);
    return Scaffold(
      appBar: AppBar(title: const Text('評價')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            item.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('交接完成後留低評價，下一個借用的人會看到。'),
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
            decoration: const InputDecoration(hintText: '例如：取件準時，電鑽電量充足。'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('送出評價')),
        ],
      ),
    );
  }
}
