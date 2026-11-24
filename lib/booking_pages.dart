import 'package:flutter/material.dart';

import 'main.dart';
import 'models.dart';
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
              color: Color(0xFF0E6B52),
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
            text: depositLabel(context, booking.deposit),
          ),
          if (booking.issue != null)
            InfoLine(
              icon: Icons.report_outlined,
              text: tr(context, '問題回報：${booking.issue}', 'Issue: ${booking.issue}'),
            ),
          if (booking.stage == BookingStage.reserved &&
              booking.deposit != DepositStatus.pending) ...[
            const SizedBox(height: 8),
            _CodeBox(code: booking.pickupCode),
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
          if (booking.stage == BookingStage.reviewed) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, '你的評價  ${'★' * (booking.stars ?? 0)}', 'Your review  ${'★' * (booking.stars ?? 0)}'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(booking.comment ?? ''),
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
          Text(tr(context, '取件碼', 'Pickup code'), style: const TextStyle(color: Color(0xFF5E6A64))),
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
          Text(
            tr(context, '交給物主核對，然後在下面確認已取件。', 'Show this to the owner, then confirm pickup below.'),
            textAlign: TextAlign.center,
          ),
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
            child: Text(tr(context, '支付按金', 'Pay deposit')),
          ),
        ),
      );
    }
    final (zh, en, action) = switch (stage) {
      BookingStage.reserved => (
        '確認已取件',
        'Confirm pickup',
        () => store.markPickedUp(bookingId),
      ),
      BookingStage.pickedUp => (
        '確認歸還',
        'Confirm return',
        () => _returnSheet(context),
      ),
      BookingStage.returned => (
        '撰寫評價',
        'Write a review',
        () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReviewPage(bookingId: bookingId)),
          );
        },
      ),
      BookingStage.reviewed => (null, null, null),
    };
    if (zh == null || en == null || action == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton(onPressed: action, child: Text(tr(context, zh, en))),
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
              '這是付給物主的租金，平台不另收費。確認後會標記為已付。',
              'This rent goes to the owner. The platform adds no fee.',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            money(quote.total),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              store.payDeposit(bookingId);
              Navigator.of(context).pop();
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
    if (_comment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, '請寫一句使用感受。', 'Write a short note.'))));
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
      appBar: AppBar(title: Text(tr(context, '評價', 'Review'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            item.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(tr(context, '交接完成後留低評價，下一個借用的人會看到。', 'The next borrower will see this review on the item.')),
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
              hintText: tr(context, '例如：取件準時，電鑽電量充足。', 'For example: Pickup was on time.'),
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
