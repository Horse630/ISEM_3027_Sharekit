import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'booking_pages.dart';
import 'camera_capture.dart';
import 'chat_center.dart';
import 'chat_page.dart';
import 'main.dart';
import 'models.dart';
import 'store.dart';
import 'text.dart';
import 'widgets.dart';

class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final item = store.itemById(itemId);
    final user = AccountScope.of(context).user;
    final mine = item.owner == user.label || item.owner == user.name;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, '物品詳情', 'Item'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          GestureDetector(
            onTap: item.photoBytes == null
                ? null
                : () => showFullPhoto(context, item.photoBytes!),
            child: Hero(
              tag: item.id,
              child: item.photoBytes == null
                  ? Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: item.category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        item.category.icon,
                        size: 72,
                        color: item.category.color,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.memory(
                        item.photoBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            item.name,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PriceChip(item: item),
              _Meta(text: categoryLabel(context, item.category)),
              _Meta(text: conditionLabel(context, item.condition)),
              _Meta(text: districtLabel(context, item.district)),
              _Meta(text: handoverLabel(context, item.handover)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.summary,
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 16),
          InfoLine(
            icon: Icons.place_outlined,
            text:
                '${districtLabel(context, item.district)} · ${item.address} · ${distanceText(context, item.distanceMeters)}',
          ),
          InfoLine(
            icon: Icons.local_shipping_outlined,
            text: tr(
              context,
              '交接方式：${item.handover.label}',
              'Handover: ${item.handover.en}',
            ),
          ),
          InfoLine(
            icon: Icons.person_outline,
            text: tr(
              context,
              '物主 ${item.owner} · 已完成 ${item.handovers} 次交接',
              'Owner ${item.owner} · ${item.handovers} handovers',
            ),
          ),
          InfoLine(
            icon: Icons.star_outline,
            text: item.reviewCount == 0
                ? tr(context, '尚未有評價', 'No reviews yet')
                : tr(
                    context,
                    '${item.rating} 分 · ${item.reviewCount} 則評價',
                    '${item.rating} · ${item.reviewCount} reviews',
                  ),
          ),
          InfoLine(
            icon: Icons.payments_outlined,
            text: item.isFree
                ? tr(context, '這件物品免費借用，平台不收費。', 'Free to borrow. No platform fee.')
                : tr(
                    context,
                    '租金由物主訂，平台不另收費。',
                    'The owner sets the rent. The platform adds no fee.',
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, '評價', 'Reviews'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ..._reviewTiles(context, store, item.id),
          const SizedBox(height: 8),
          Text(
            tr(context, '借用流程', 'How borrowing works'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              '找物品  →  預約  →  取件  →  歸還  →  評價',
              'Find  →  Book  →  Pick up  →  Return  →  Review',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              if (!mine) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final account = AccountScope.of(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            auth: account.auth,
                            itemId: item.id,
                            itemName: item.name,
                            ownerName: item.owner,
                            senderName: account.user.label,
                            center: ChatScope.maybeOf(context),
                            store: store,
                          ),
                        ),
                      );
                    },
                    child: Text(tr(context, '聯絡物主', 'Message')),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: _ownerAction(context, store, item)),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _reviewTiles(BuildContext context, ShareStore store, String itemId) {
  final reviews = store.bookings
      .where(
        (booking) =>
            booking.itemId == itemId && (booking.comment ?? '').trim().isNotEmpty,
      )
      .toList();
  if (reviews.isEmpty) {
    return [
      Text(
        tr(context, '還沒有文字評價。', 'No written reviews yet.'),
        style: const TextStyle(color: Color(0xFF5E6A64)),
      ),
    ];
  }
  return [
    for (final review in reviews)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'★' * (review.stars ?? 0)}  ${review.borrower.isEmpty ? tr(context, '借用者', 'Borrower') : review.borrower}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(review.comment ?? ''),
              ],
            ),
          ),
        ),
      ),
  ];
}

Widget _ownerAction(BuildContext context, ShareStore store, ShareItem item) {
  final user = AccountScope.of(context).user;
  final mine = item.owner == user.label || item.owner == user.name;
  if (!mine) {
    return FilledButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookPage(itemId: item.id)),
        );
      },
      child: Text(tr(context, '預約這件物品', 'Book this item')),
    );
  }
  return FilledButton(
    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9A4632)),
    onPressed: () async {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, '下架這件物品？', 'Remove this item?')),
          content: Text(
            tr(
              context,
              '下架後，其他人不會再在探索頁看到它。',
              'Other people will no longer see it in Explore.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, '取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, '下架', 'Remove')),
            ),
          ],
        ),
      );
      if (remove != true || !context.mounted) return;
      store.removeItem(item.id);
      Navigator.of(context).pop();
    },
    child: Text(tr(context, '下架物品', 'Remove item')),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E1D6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class BookPage extends StatefulWidget {
  const BookPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  late DateTime _start;
  late DateTime _end;
  final _note = TextEditingController();
  String? _error;
  var _datesReady = false;
  PayMethod _pay = PayMethod.online;

  @override
  void initState() {
    super.initState();
    final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
    _start = tomorrow;
    _end = tomorrow;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final initial = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: dateOnly(DateTime.now()),
      lastDate: dateOnly(DateTime.now()).add(const Duration(days: 90)),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _error = null;
      if (start) {
        _start = dateOnly(picked);
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = dateOnly(picked);
        if (_end.isBefore(_start)) _start = _end;
      }
    });
  }

  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_datesReady) return;
    _datesReady = true;
    final open = ShareKitScope.of(context).nextOpenDay(widget.itemId);
    _start = open;
    _end = open;
  }

  Future<void> _confirm() async {
    final store = ShareKitScope.of(context);
    final account = AccountScope.of(context);
    final user = account.user;
    final item = store.findItem(widget.itemId);
    if (item == null) {
      setState(() => _error = tr(context, '這件物品已下架。', 'This item was removed.'));
      return;
    }
    if (item.owner == user.label || item.owner == user.name) {
      setState(() => _error = tr(context, '不能預約自己上架的物品。', "You can't book your own item."));
      return;
    }
    final booking = store.createBooking(
      itemId: widget.itemId,
      start: _start,
      end: _end,
      note: _note.text,
      borrower: user.label,
      payMethod: _pay,
    );
    if (booking == null) {
      setState(() => _error = tr(
        context,
        '這段日期已有人預約，請改選其他日子。',
        'Those dates are taken. Pick another day.',
      ));
      return;
    }
    final note = _note.text.trim();
    final lines = [
      tr(context, '租借申請', 'Rental request'),
      '${tr(context, '物品', 'Item')}：${item.name}',
      '${tr(context, '租借人', 'Renter')}：${user.label}',
      '${tr(context, '日期', 'Dates')}：${formatDate(booking.start)} – ${formatDate(booking.end)}',
      '${tr(context, '付款', 'Payment')}：${tr(context, _pay.label, _pay.en)}',
      '${tr(context, '租金', 'Rent')}：${item.isFree ? tr(context, '免費', 'Free') : money(quoteFor(item, booking.start, booking.end).rent)}',
      if (note.isNotEmpty) '${tr(context, '備註', 'Note')}：$note',
    ];
    await account.auth.sendMessage(
      itemId: item.id,
      sender: user.label,
      body: lines.join('\n'),
      kind: 'request',
      bookingId: booking.id,
    );
    if (!mounted) return;
    store.openTab(1);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          auth: account.auth,
          itemId: item.id,
          itemName: item.name,
          ownerName: item.owner,
          senderName: user.label,
          center: ChatScope.maybeOf(context),
          store: store,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = ShareKitScope.of(context).itemById(widget.itemId);
    final quote = quoteFor(item, _start, _end);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, '預約', 'Book'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            item.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            item.priceLabel,
            style: const TextStyle(color: Color(0xFF5E6A64)),
          ),
          const SizedBox(height: 18),
          Text(tr(context, '借用日期', 'Dates'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: tr(context, '開始', 'Start'),
                  value: formatDate(_start),
                  onTap: () => _pick(start: true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 18),
              ),
              Expanded(
                child: _DateButton(
                  label: tr(context, '歸還', 'Return'),
                  value: formatDate(_end),
                  onTap: () => _pick(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tr(context, '交接備註', 'Handover note'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: tr(context, '例如：星期六下午 3 時，會所大堂', 'For example: Saturday 3pm, clubhouse lobby'),
            ),
          ),
          const SizedBox(height: 18),
          Text(tr(context, '付款方式', 'How to pay'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final method in PayMethod.values)
                ChoiceChip(
                  label: Text(tr(context, method.label, method.en)),
                  selected: _pay == method,
                  onSelected: (_) => setState(() => _pay = method),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tr(context, '費用', 'Cost'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _FeeRow(label: tr(context, '日數', 'Days'), value: '${quote.days}'),
          _FeeRow(
            label: tr(context, '租金', 'Rent'),
            value: quote.free ? tr(context, '免費', 'Free') : money(quote.rent),
          ),
          _FeeRow(
            label: tr(context, '平台費', 'Platform fee'),
            value: 'HK\$0',
          ),
          const Divider(),
          _FeeRow(
            label: tr(context, '合計', 'Total'),
            value: quote.free ? 'HK\$0' : money(quote.total),
            strong: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF9A4632))),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(onPressed: _confirm, child: Text(tr(context, '確認預約', 'Confirm booking'))),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF5E6A64)),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class ListItemPage extends StatefulWidget {
  const ListItemPage({super.key, required this.ownerName});

  final String ownerName;

  @override
  State<ListItemPage> createState() => _ListItemPageState();
}

class _ListItemPageState extends State<ListItemPage> {
  final _name = TextEditingController();
  final _summary = TextEditingController();
  final _price = TextEditingController();
  final _address = TextEditingController();
  ItemCategory _category = ItemCategory.tool;
  HkDistrict _district = HkDistrict.kowloonCity;
  String _condition = '良好';
  HandoverMethod _handover = HandoverMethod.faceToFace;
  var _prefilled = false;
  Uint8List? _photo;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final user = AccountScope.of(context).user;
    if (_address.text.isEmpty && user.address.isNotEmpty) {
      _address.text = user.address;
    }
    _district = user.district;
  }

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _price.dispose();
    _address.dispose();
    super.dispose();
  }

  void _publish() {
    final name = _name.text.trim();
    final summary = _summary.text.trim();
    final address = _address.text.trim();
    if (name.isEmpty || summary.isEmpty || address.isEmpty) {
      setState(() => _error = tr(context, '請填寫名稱、地址和簡介。', 'Enter a name, address, and description.'));
      return;
    }
    final photo = _photo;
    if (photo == null) {
      setState(() => _error = tr(context, '請用相機拍攝物品現況。不能從相簿上載。', 'Take a photo of the item with the camera.'));
      return;
    }
    double? dailyPrice;
    if (_price.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_price.text.trim());
      if (parsed == null || parsed < 0) {
        setState(() => _error = tr(context, '租金請填數字，或留空代表免費。', 'Enter a number for the rent, or leave it blank for free.'));
        return;
      }
      dailyPrice = parsed == 0 ? null : parsed;
    }
    ShareKitScope.of(context).addItem(
      name: name,
      owner: widget.ownerName,
      category: _category,
      condition: _condition,
      summary: summary,
      dailyPrice: dailyPrice,
      photoBytes: photo,
      address: address,
      district: _district,
      handover: _handover,
    );
    ShareKitScope.of(context).openTab(0);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(context, '已上架到本社區，附近的人可以搜尋到。', 'Listed. People nearby can search for it.'))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, '上架物品', 'List an item'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(tr(
            context,
            '把家裡不常用的東西借給同一個社區。留空租金即為免費借用。上架必須用相機拍攝當時的物品狀況，不能從相簿上載。',
            'Lend something you rarely use. Leave the price blank to lend it for free. Take a photo with the camera.',
          )),
          const SizedBox(height: 16),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _photo!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final bytes = await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute(
                  builder: (_) => CameraCapturePage(title: tr(context, '拍攝物品現況', 'Photograph the item')),
                ),
              );
              if (!mounted || bytes == null) return;
              setState(() {
                _photo = bytes;
                _error = null;
              });
            },
            child: Text(_photo == null ? tr(context, '用相機拍攝', 'Take a photo') : tr(context, '重新拍攝', 'Retake')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: tr(context, '物品名稱', 'Item name')),
          ),
          const SizedBox(height: 12),
          Text(tr(context, '分類', 'Category'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final category in ItemCategory.values)
                ChoiceChip(
                  label: Text(categoryLabel(context, category)),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(tr(context, '狀況', 'Condition'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final condition in const ['全新', '良好', '有使用痕跡'])
                ChoiceChip(
                  label: Text(conditionLabel(context, condition)),
                  selected: _condition == condition,
                  onSelected: (_) => setState(() => _condition = condition),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(labelText: tr(context, '每日租金（港元，可留空）', 'Daily rent in HKD, optional')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showHkDistrictSheet(
                context,
                includeAll: false,
                selected: _district,
              );
              if (!mounted || picked?.district == null) return;
              setState(() => _district = picked!.district!);
            },
            icon: const Icon(Icons.map_outlined),
            label: Text(tr(context, '地區 · ${_district.label}', 'District · ${_district.en}')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: InputDecoration(
              labelText: tr(context, '你的地址', 'Your address'),
              hintText: tr(context, '例如：九龍塘XX座X樓', 'For example: Tower 1, Kowloon Tong'),
            ),
          ),
          const SizedBox(height: 12),
          Text(tr(context, '交接方式', 'Handover'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final method in HandoverMethod.values)
                ChoiceChip(
                  label: Text(handoverLabel(context, method)),
                  selected: _handover == method,
                  onSelected: (_) => setState(() => _handover = method),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _summary,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: tr(context, '簡介', 'Description'),
              hintText: tr(context, '相片位置、配件、使用限制', 'Accessories and limits'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF9A4632))),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _publish, child: Text(tr(context, '發佈到本社區', 'Publish'))),
        ],
      ),
    );
  }
}
