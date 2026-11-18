import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'booking_pages.dart';
import 'camera_capture.dart';
import 'chat_page.dart';
import 'main.dart';
import 'models.dart';
import 'widgets.dart';

class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final item = store.itemById(itemId);
    return Scaffold(
      appBar: AppBar(title: const Text('物品詳情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Hero(
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
              _Meta(text: item.category.label),
              _Meta(text: item.condition),
              _Meta(text: item.handover.label),
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
            text: '${item.address} · ${formatDistance(item.distanceMeters)}',
          ),
          InfoLine(
            icon: Icons.local_shipping_outlined,
            text: '交接方式：${item.handover.label}',
          ),
          InfoLine(
            icon: Icons.person_outline,
            text: '物主 ${item.owner} · 已完成 ${item.handovers} 次交接',
          ),
          InfoLine(
            icon: Icons.star_outline,
            text: item.reviewCount == 0
                ? '尚未有評價'
                : '${item.rating} 分 · ${item.reviewCount} 則評價',
          ),
          InfoLine(
            icon: Icons.payments_outlined,
            text: item.isFree ? '這件物品免費借用，平台不收費。' : '付費租借會另加租金一成，作為交接紀錄的服務費。',
          ),
          const SizedBox(height: 8),
          const Text('借用流程', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('找物品  →  預約  →  取件  →  歸還  →  評價'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
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
                        ),
                      ),
                    );
                  },
                  child: const Text('聯絡物主'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BookPage(itemId: item.id)),
                    );
                  },
                  child: const Text('預約這件物品'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  void _confirm() {
    final store = ShareKitScope.of(context);
    final booking = store.createBooking(
      itemId: widget.itemId,
      start: _start,
      end: _end,
      note: _note.text,
    );
    if (booking == null) {
      setState(() => _error = '這段日期已有人預約，請改選其他日子。');
      return;
    }
    store.openTab(1);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => BookingDetailPage(bookingId: booking.id),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = ShareKitScope.of(context).itemById(widget.itemId);
    final quote = quoteFor(item, _start, _end);
    return Scaffold(
      appBar: AppBar(title: const Text('預約')),
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
          const Text('借用日期', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: '開始',
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
                  label: '歸還',
                  value: formatDate(_end),
                  onTap: () => _pick(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('交接備註', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '例如：星期六下午 3 時，會所大堂'),
          ),
          const SizedBox(height: 18),
          const Text('費用', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _FeeRow(label: '日數', value: '${quote.days} 日'),
          _FeeRow(label: '租金', value: quote.free ? '免費' : money(quote.rent)),
          _FeeRow(
            label: '服務費',
            value: quote.free ? 'HK\$0' : money(quote.serviceFee),
          ),
          const Divider(),
          _FeeRow(
            label: '合計',
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
          child: FilledButton(onPressed: _confirm, child: const Text('確認預約')),
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
  String _condition = '良好';
  HandoverMethod _handover = HandoverMethod.faceToFace;
  Uint8List? _photo;
  String? _error;

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
      setState(() => _error = '請填寫名稱、地址和簡介。');
      return;
    }
    final photo = _photo;
    if (photo == null) {
      setState(() => _error = '請用相機拍攝物品現況。不能從相簿上載。');
      return;
    }
    double? dailyPrice;
    if (_price.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_price.text.trim());
      if (parsed == null || parsed < 0) {
        setState(() => _error = '租金請填數字，或留空代表免費。');
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
      handover: _handover,
    );
    ShareKitScope.of(context).openTab(0);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已上架到本社區，附近的人可以搜尋到。')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('上架物品')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text('把家裡不常用的東西借給同一個社區。留空租金即為免費借用。上架必須用相機拍攝當時的物品狀況，不能從相簿上載。'),
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
                  builder: (_) => const CameraCapturePage(title: '拍攝物品現況'),
                ),
              );
              if (!mounted || bytes == null) return;
              setState(() {
                _photo = bytes;
                _error = null;
              });
            },
            child: Text(_photo == null ? '用相機拍攝' : '重新拍攝'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '物品名稱'),
          ),
          const SizedBox(height: 12),
          const Text('分類', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final category in ItemCategory.values)
                ChoiceChip(
                  label: Text(category.label),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('狀況', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final condition in const ['全新', '良好', '有使用痕跡'])
                ChoiceChip(
                  label: Text(condition),
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
            decoration: const InputDecoration(labelText: '每日租金（港元，可留空）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: '你的地址',
              hintText: '例如：九龍塘XX座X樓',
            ),
          ),
          const SizedBox(height: 12),
          const Text('交接方式', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final method in HandoverMethod.values)
                ChoiceChip(
                  label: Text(method.label),
                  selected: _handover == method,
                  onSelected: (_) => setState(() => _handover = method),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _summary,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '簡介',
              hintText: '相片位置、配件、使用限制',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF9A4632))),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _publish, child: const Text('發佈到本社區')),
        ],
      ),
    );
  }
}
